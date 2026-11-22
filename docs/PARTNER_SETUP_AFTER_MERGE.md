# Partner setup after the M2 merge (2026-11-21)

`main` now contains your programmer home page, saved posts and the framework field, merged with the M1/M2
security work. This page takes your local setup from your old `main` to the new one.

It assumes your database is **SQL Server Express on Windows** (instance `.\SQLEXPRESS`, folder `MSSQL16.SQLEXPRESS`),
named `DevLink`, created from your schema script (`docs/partner-schema/partner_schema_2026-11-21.sql`), and that it
has **no `__EFMigrationsHistory` table yet**. Commands are for **PowerShell** unless a step says **Git Bash**. Run them
from the repository root.

`sqlcmd` connects with your Windows login (`-E`). If it says the server certificate isn't trusted, add `-C` to that
command. You can also paste any of the SQL into a query window in SQL Server Management Studio (SSMS).

Allow about 30 minutes. Do the steps in order and stop at the first error; nothing below needs to be skipped.

---

## 1. Get the new code

```powershell
git switch main
git pull --ff-only
```

If `git pull` refuses because you have local changes, commit or stash them first. Don't force anything.

## 2. Back up your database

This copy is what you restore from if anything below goes wrong.

```powershell
$bak = "C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\Backup\DevLink_before_merge_2026-11-21.bak"
sqlcmd -S .\SQLEXPRESS -E -b -Q "BACKUP DATABASE [DevLink] TO DISK = N'$bak' WITH COPY_ONLY, CHECKSUM, INIT; RESTORE VERIFYONLY FROM DISK = N'$bak' WITH CHECKSUM;"
sqlcmd -S .\SQLEXPRESS -E -b -Q "DBCC CHECKDB(N'DevLink') WITH NO_INFOMSGS;"
```

You should see `The backup set on file 1 is valid.`, and CHECKDB should print nothing. The SQL Server service writes
into its own `Backup` folder, which is why the backup goes there first. Then keep a copy outside it and check that the
two files are identical:

```powershell
New-Item -ItemType Directory -Force "$HOME\DevLink-backups\devlink-db-2026-11-21" | Out-Null
Copy-Item $bak "$HOME\DevLink-backups\devlink-db-2026-11-21\"
Get-FileHash -Algorithm SHA256 $bak, "$HOME\DevLink-backups\devlink-db-2026-11-21\DevLink_before_merge_2026-11-21.bak" | Format-Table Hash, Path
```

Both lines must show the same hash. Keep the backup out of the repository: it contains real data.

**To restore it** (only if you need to undo everything; stop the API first):

```powershell
sqlcmd -S .\SQLEXPRESS -E -b -Q "ALTER DATABASE [DevLink] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [DevLink] FROM DISK = N'$bak' WITH REPLACE, CHECKSUM; ALTER DATABASE [DevLink] SET MULTI_USER;"
```

## 3. Create your three keys (user-secrets)

The API refuses to start without these. Each developer makes their own, and they are never shared, committed or
printed. Run this in **Git Bash**, from the repository root. Windows PowerShell 5.1 adds a byte-order mark when piping,
which `dotnet user-secrets` rejects.

```bash
k=$(openssl rand -base64 64 | tr -d '\r\n')
printf '{"Jwt:SigningKeys:0:Id":"local-1","Jwt:SigningKeys:0:Key":"%s","Jwt:SigningKeys:0:Status":"Active"}' "$k" \
  | dotnet user-secrets set --project backend > /dev/null; echo "exit: ${PIPESTATUS[1]}"; unset k

k=$(openssl rand -base64 64 | tr -d '\r\n')
printf '{"Security:CodeHmacKey":"%s"}' "$k" | dotnet user-secrets set --project backend > /dev/null; echo "exit: ${PIPESTATUS[1]}"; unset k

k=$(openssl rand -base64 64 | tr -d '\r\n')
printf '{"Security:MediaUrlKey":"%s"}' "$k" | dotnet user-secrets set --project backend > /dev/null; echo "exit: ${PIPESTATUS[1]}"; unset k
```

Each command must print `exit: 0`. Don't run `dotnet user-secrets list` where someone can see your screen: it prints
the values.

Also check `backend/appsettings.json` (it is yours and is not in Git). Compare it with `appsettings.example.json` in
the repository root, and add any section you are missing, such as `Cors`. Your connection string can stay as it is,
for example `"DefaultConnection": "Server=.\\SQLEXPRESS;Database=DevLink;Trusted_Connection=True;TrustServerCertificate=True"`.

## 4. Prepare your database for EF migrations (alignment and baseline)

Your database was made from a script, so EF Core doesn't know about it yet. These two scripts are idempotent:
running them again changes nothing.

```powershell
sqlcmd -S .\SQLEXPRESS -E -I -b -d DevLink -i database\align_schema_for_ef_baseline.sql
sqlcmd -S .\SQLEXPRESS -E -I -b -d DevLink -i database\baseline_ef_history.sql
```

- The first one changes names only, no data. It gives three primary keys fixed names and replaces two redundant
  unique constraints with the unique indexes EF expects. It ends with `Alignment complete.`
- The second one creates `__EFMigrationsHistory` and records `20261028125753_InitialCreate` as already applied. It
  prints `Baseline recorded: ...`.

## 5. Apply the migrations

Install the EF tool once, if you don't have it (version 9.0.0, the one this project uses):

```powershell
dotnet tool install --global dotnet-ef --version 9.0.0
```

Then:

```powershell
cd backend
dotnet ef database update
cd ..
```

It must list these three and end with `Done.`:

```
Applying migration '20261103225031_AddAuthSecurity'.
Applying migration '20261111001401_AddUserHasPassword'.
Applying migration '20261121182847_AddSavedPostsAndFramework'.
```

You already have `SavedPosts` and both `Framework` columns. The last migration detects that and leaves them and their
rows alone. The one difference it fixes is the name of the unique rule on `SavedPosts (PostId, UserId)`: it creates the
unique index `IX_SavedPosts_PostId_UserId` first, then drops your `UQ_SavedPosts_Post_User` constraint. Uniqueness is
enforced the whole time. This path was tested on a copy of your schema with test rows (saved posts and Google users
included): every row was identical before and after.

Check:

```powershell
sqlcmd -S .\SQLEXPRESS -E -d DevLink -Q "SELECT MigrationId FROM dbo.__EFMigrationsHistory ORDER BY MigrationId;"
sqlcmd -S .\SQLEXPRESS -E -b -Q "DBCC CHECKDB(N'DevLink') WITH NO_INFOMSGS;"
```

You should see 4 migration rows, and CHECKDB should print nothing.

## 6. Google-only accounts (KI-68): review first, fix after

Your Google sign-up stored a plain random GUID as the "password" of Google accounts. After the migration those
accounts count as having a password, so "change password" answers "current password is incorrect". The script below
finds them and, after you review the list, marks them as having no password. They can still sign in with Google, and
"Forgot password" sets a real password.

**6a. Review (read-only).**

```powershell
sqlcmd -S .\SQLEXPRESS -E -I -d DevLink -i database\ki68_mark_google_only_accounts.sql
```

The first result lists the candidate accounts (id, email, role, status). It shows no password values. Check that every
row is really a Google account. The second result is only for databases that ran our branch earlier. Yours didn't, so
it should be empty.

**6b. Fix (only after the review).** Use SSMS, so you can check the count before committing:

1. Open `database\ki68_mark_google_only_accounts.sql` in SSMS, connected to `.\SQLEXPRESS`, database `DevLink`.
2. In the "Step 2" block, remove the leading `-- ` from the lines `BEGIN TRANSACTION;` through
   `SELECT @@ROWCOUNT AS AccountsMarked;`. Leave the `COMMIT` line commented.
3. Execute the whole file. `AccountsMarked` must equal the number of rows you reviewed in 6a.
4. In the same window, run `COMMIT TRANSACTION;` if it matches, or `ROLLBACK TRANSACTION;` if it doesn't.
5. Close the file **without saving**, so the repository copy stays unchanged.

## 7. Run the API and the app

API (port 5133):

```powershell
cd backend
dotnet run --launch-profile http
```

App, in a second terminal, on **port 5200** (the only web origin the API accepts by default):

```powershell
cd frontend
flutter pub get --enforce-lockfile
flutter run -d chrome --web-port 5200 --web-hostname localhost
```

Open it as `http://localhost:5200`, not `127.0.0.1` or a LAN address, or the API refuses the calls. The app now signs
in with tokens itself, so **don't set `Auth__EnforceAuthorization=false`**. You don't need it any more.

Without SMTP settings, the API doesn't send email in Development. It prints sign-up and reset codes in the API
console instead.

If you have no admin account yet (admins can't be created through the app):

```powershell
cd backend
$env:DEVLINK_ADMIN_EMAIL = "admin@example.com"
$env:DEVLINK_ADMIN_PASSWORD = "<a strong password>"
dotnet run --launch-profile http -- seed-admin
Remove-Item Env:DEVLINK_ADMIN_PASSWORD
```

## 8. What behaves differently now

- **Sign-in is required for every screen.** The API decides who you are from the sign-in token, never from a `userId`
  the app sends. Asking for another user's private data (their saved posts, notifications, profile documents) is
  refused (403). Reloading the page keeps you signed in through a secure cookie.
- **Passwords:** at least 8 characters, and common passwords are refused. Passwords are stored hashed. An old
  plain-text password still works once and is hashed at that sign-in.
- **Sign-up and password reset** use a 6-digit code sent by email (printed in the API console in Development). Codes
  expire, and repeated wrong tries are limited.
- **Images** (post images, avatars) come from the API as signed links that expire. Build image URLs from the `url` /
  `avatarUrl` fields in the responses (`MediaUrl.resolve` in the app), not from ids.
- **Saved posts:**
  - You can save only posts you can see: approved posts, or your own.
  - Your saved list is private to you. A post that is later deleted, or someone else's post that stops being
    approved, drops out of it.
  - Admins can't use the saved-post routes.
  - Deleting a user also deletes their saved posts.
- **Framework rule (your logic, kept):** if a post names a framework, an application must choose the same one (case
  doesn't matter).
- **Notifications** name people by nickname, never by email.
- **Admins** are created only with `seed-admin`, not through the API or the app.
- **Suspended accounts** see a "suspended" screen instead of their home page.
- **Programmer home:** programmers land on your new home page after sign-in, after a reload and after finishing profile
  setup. The separate "Find projects" button was dropped, because your home page already has the feed.

---

## Please fix in your code

1. **The Saved tab goes stale.** `ProgrammerHomePage` keeps its tabs in an `IndexedStack`, so the Saved tab loads once.
   A post saved afterwards appears only after a reload, and an unsaved one stays on screen. Reload the list when the
   tab is opened, or after each save/unsave.
2. **The programmer's own email is shown as their display name.** Login, app start and profile setup pass the email as
   `authorName` to `ProgrammerHomePage`, which shows it as the user's name. Show the profile nickname instead.
3. **Analyzer warning in `customer_home_page.dart`:** it imports `post_card.dart` with `hide PostService`, but
   `post_card.dart` doesn't export `PostService` (`undefined_hidden_name`). Remove the `hide`.
4. **KI-69: CV and certificate links in the new dashboard.** `programmer_dashboard_page.dart` (and
   `admin_verification_details_page.dart`) open `ApiService.getProgrammerCvUrl` / `getProgrammerCertificateUrl`
   directly in a browser tab. A tab sends no token, so the API answers 401. Use the single-use link routes instead:
   `POST /api/ProgrammerProfile/{userId}/cv/link` and `/certificate/link` return a short-lived URL to open.
