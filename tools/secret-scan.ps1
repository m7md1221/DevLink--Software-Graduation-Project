<#
.SYNOPSIS
    Scans the Git index, or a commit, for secrets. Prints file names and counts only, never a value.

.DESCRIPTION
    Sensitive values are read when the script runs, so this file contains none of them:
      1. Key, secret, password, token and connection values from `dotnet user-secrets` (backend project).
      2. The same kinds of values from backend/appsettings.json, which is gitignored.
      3. Synthetic test passwords from tools/secret-scan.local.txt, which is gitignored: one value per
         line; blank lines and lines starting with # are ignored. Without this file the scan is incomplete
         and exits with code 2, unless -AllowMissingLocalFile is passed.
    It then checks for private keys, JSON web tokens, Gmail app passwords and real mail-provider addresses.

    Exit codes: 0 clean, 1 something found, 2 could not run a complete scan.

.EXAMPLE
    powershell -File tools/secret-scan.ps1                 # the staged content
    powershell -File tools/secret-scan.ps1 -Rev HEAD       # a commit
#>
[CmdletBinding()]
param(
    [string] $Rev,
    [switch] $AllowMissingLocalFile
)

# Native commands report through exit codes, which are checked below.
$ErrorActionPreference = 'Continue'
$repo = (& git rev-parse --show-toplevel).Trim()
Set-Location $repo

$localFile = Join-Path $repo 'tools/secret-scan.local.txt'
$sensitiveName = '(?i)key|secret|password|pwd|token|connection'
$minimumLength = 8

# The password blocklist is a public word list, so it is the one exempt file.
$exempt = @(':(exclude)backend/Resources/common-passwords-10k.txt')

$values = New-Object 'System.Collections.Generic.HashSet[string]'
$sources = [ordered]@{ 'user-secrets' = 0; 'appsettings.json' = 0; 'local file' = 0 }

function Add-Value([string] $value, [string] $source) {
    if ($null -ne $value) {
        $trimmed = $value.Trim()
        if ($trimmed.Length -ge $minimumLength -and $values.Add($trimmed)) {
            $sources[$source] = $sources[$source] + 1
        }
    }
}

# 1. user-secrets. Output is never echoed.
$secretLines = & dotnet user-secrets list --project backend 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Output 'Could not read user-secrets.'
    exit 2
}

foreach ($line in $secretLines) {
    $at = $line.IndexOf(' = ')
    if ($at -gt 0) {
        $name = $line.Substring(0, $at)
        if ($name -match $sensitiveName -and $name -notmatch ':(Id|Status)$') {
            Add-Value $line.Substring($at + 3) 'user-secrets'
        }
    }
}

# 2. The local settings file.
function Read-Settings($node, [string] $name) {
    if ($node -is [string]) {
        if ($name -match $sensitiveName) { Add-Value $node 'appsettings.json' }
    }
    elseif ($node -is [System.Array]) {
        foreach ($item in $node) { Read-Settings $item $name }
    }
    elseif ($node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $node.PSObject.Properties) { Read-Settings $property.Value $property.Name }
    }
}

$settings = Join-Path $repo 'backend/appsettings.json'
if (Test-Path $settings) {
    Read-Settings (Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json) ''
}

# 3. Synthetic test passwords.
$incomplete = $false
if (Test-Path $localFile) {
    foreach ($line in Get-Content $localFile -Encoding UTF8) {
        if ($line.Trim().Length -gt 0 -and -not $line.TrimStart().StartsWith('#')) {
            Add-Value $line 'local file'
        }
    }
}
else {
    $incomplete = $true
}

$target = if ($Rev) { $Rev } else { 'index' }
$treeArgs = @(if ($Rev) { $Rev } else { '--cached' })

# Patterns are given on standard input, so no value appears on a command line or on disk.
function Find-Literal([string[]] $patterns) {
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = 'git'
    $start.Arguments = (@('-c', 'core.quotepath=off', 'grep', '--text', '-l', '-F', '-f', '-') + $treeArgs + @('--', '.') + $exempt) -join ' '
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [System.Text.Encoding]::UTF8

    $process = [System.Diagnostics.Process]::Start($start)
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes(($patterns -join "`n") + "`n")
    $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $process.StandardInput.Close()
    $stderr = $process.StandardError.ReadToEndAsync()
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()

    # git grep: 0 = found, 1 = nothing found, anything else = failure.
    if ($process.ExitCode -gt 1) {
        Write-Output 'git grep failed, so the scan is not valid.'
        exit 2
    }

    return @($output -split "`n" | Where-Object { $_.Trim().Length -gt 0 })
}

$valueHits = @()
if ($values.Count -gt 0) {
    $valueHits = Find-Literal ([string[]]$values)
}

# Shapes of secrets that are not known in advance.
$shapes = [ordered]@{
    'private key'        = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    'JSON web token'     = 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.'
    'Gmail app password' = '(pass|pwd|app.?password).{0,40}\b[a-z]{4} [a-z]{4} [a-z]{4} [a-z]{4}\b'
    'mail address'       = '[A-Za-z0-9._%+-]+@(gmail|hotmail|outlook|yahoo)\.com'
}

$shapeHits = [ordered]@{}
foreach ($shape in $shapes.GetEnumerator()) {
    $found = @(& git -c core.quotepath=off grep --text -l -i -E -e $shape.Value @treeArgs -- . @exempt 2>$null)
    if ($LASTEXITCODE -gt 1) {
        Write-Output 'git grep failed, so the scan is not valid.'
        exit 2
    }

    if ($found.Count -gt 0) { $shapeHits[$shape.Key] = $found }
}

Write-Output "Target: $target"
Write-Output ("Values checked: {0} (user-secrets {1}, appsettings.json {2}, local file {3})" -f $values.Count, $sources['user-secrets'], $sources['appsettings.json'], $sources['local file'])
Write-Output "Files with a known value: $($valueHits.Count)"
foreach ($file in $valueHits) { Write-Output "  $file" }

foreach ($hit in $shapeHits.GetEnumerator()) {
    Write-Output "Pattern '$($hit.Key)': $($hit.Value.Count) file(s)"
    foreach ($file in $hit.Value) { Write-Output "  $file" }
}

if ($valueHits.Count -gt 0 -or $shapeHits.Count -gt 0) {
    Write-Output 'Result: FOUND. Do not push until each file above is checked.'
    exit 1
}

if ($incomplete -and -not $AllowMissingLocalFile) {
    Write-Output 'Result: INCOMPLETE. tools/secret-scan.local.txt is missing, so synthetic test passwords were not checked.'
    exit 2
}

Write-Output 'Result: clean.'
exit 0
