# DevLink 🚀

A freelance platform connecting **Customers** with **Programmers**.

## Project Structure

- `backend/` — ASP.NET Core Web API (C#)
- `frontend/` — Flutter (Web + Mobile)
- `database/` — SQL Server schema scripts
- `tests/DevLink.Api.Tests/` — backend integration and unit tests (xUnit)
- `docs/` — planning, task checklist, decision log, known issues

## Tech Stack

- Backend: ASP.NET Core **9**, EF Core 9, SQL Server 2022
- Frontend: Flutter (**3.47.x** — the SDK-pinned packages in `frontend/pubspec.lock` come from 3.47; older SDKs downgrade them)
- Email: MailKit (SMTP settings from configuration, never from code)
- Auth: email/password (hashed with ASP.NET Core Identity's PBKDF2 hasher) + Google Sign-In

> ⚠️ **Security status:** the API has **no authentication/authorization yet** (planned milestone M2, see `docs/task-checklist.md`).
> Run it on `localhost` only. Never expose port 5133 to a network until M2 is done.

## Setup

### 1. Prerequisites

| Tool | Version |
|---|---|
| .NET SDK | 9.0.x (`dotnet --list-sdks`) |
| Flutter | 3.47.x (`flutter --version`) |
| Docker Desktop | any recent version (or a local SQL Server 2022) |

### 2. Database (SQL Server 2022 in Docker — recommended)

1. Create a password file **outside the repository**, e.g. `%USERPROFILE%\.devlink\sql.env`, containing one line:
   `MSSQL_SA_PASSWORD=<8+ chars with upper, lower, digit, symbol>`
2. Start the container (data is kept in the `devlink_sqldata` volume, reachable only from this PC):
   ```powershell
   docker run -d --name devlink-sql --env-file $env:USERPROFILE\.devlink\sql.env `
     -e "ACCEPT_EULA=Y" -e "MSSQL_PID=Express" -p 127.0.0.1:1433:1433 `
     -v devlink_sqldata:/var/opt/mssql --restart unless-stopped `
     mcr.microsoft.com/mssql/server:2022-latest
   ```
3. Load the current schema from `database/scrip_23_10.sql`. That script was exported from a Windows SQL Server
   Express instance: remove the `ON PRIMARY (...) LOG ON (...)` file clauses of `CREATE DATABASE` before running it
   on Linux/Docker. (`database/DevLink_Full.sql` is **outdated** — do not use it.)

Stop / start later with `docker stop devlink-sql` / `docker start devlink-sql`.

### 3. Backend configuration

1. Copy the template from the **repository root** to the backend folder (the copy is gitignored):
   ```powershell
   Copy-Item appsettings.example.json backend\appsettings.json
   ```
2. In `backend/appsettings.json` set `ConnectionStrings:DefaultConnection`, for Docker:
   `Server=127.0.0.1,1433;Database=DevLink;User ID=sa;Password=<your password>;TrustServerCertificate=True`
   Use **`127.0.0.1`**, not `localhost`: on Windows `localhost` resolves to IPv6 first and the container only listens on IPv4.
3. Set `Google:ClientId` (the web client ID used by `frontend/web/index.html`).
4. **SMTP (optional)** — keep credentials in user-secrets, never in files that are committed:
   ```powershell
   cd backend
   dotnet user-secrets set "Smtp:SenderEmail" "<sender address>"
   dotnet user-secrets set "Smtp:Password" "<app password>"
   ```
   Without SMTP settings, the API in **Development** does not send email: it writes the message (including
   verification codes) to the API console instead. Outside Development, sending fails safely.

### 4. Run the backend

```powershell
cd backend
dotnet run --launch-profile http
```
- API: http://localhost:5133 — Swagger UI: http://localhost:5133/swagger (Development only)
- Stop: `Ctrl+C` in that terminal.

### 5. First admin account (local provisioning)

Admin accounts cannot be created, promoted, changed or deleted through the API. Create one locally:
```powershell
cd backend
$env:DEVLINK_ADMIN_EMAIL = "admin@example.com"
$env:DEVLINK_ADMIN_PASSWORD = "<strong password>"
dotnet run --launch-profile http -- seed-admin
Remove-Item Env:DEVLINK_ADMIN_PASSWORD
```
The command prints the target database name, is idempotent (an existing admin is left unchanged) and refuses to
convert an existing non-admin account.

### 6. Run the frontend

```powershell
cd frontend
flutter pub get --enforce-lockfile   # Flutter 3.47.x; fails instead of rewriting pubspec.lock
flutter run -d chrome    # or: flutter run -d edge / -d web-server --web-port 8080
```
The web app calls the API at `http://localhost:5133` (Android emulator: `10.0.2.2:5133`, see `lib/api_config.dart`).

### 7. Running the tests

Tests that touch a database use a **separate, disposable SQL Server** — never the `DevLink` database. Each test
class creates a database named `DevLinkTest_<guid>` and drops it afterwards.

1. Create `%USERPROFILE%\.devlink\sql-test.env` with `MSSQL_SA_PASSWORD=<another strong password>`.
2. Start the test server (no volume — nothing is kept):
   ```powershell
   docker run -d --name devlink-sql-test --env-file $env:USERPROFILE\.devlink\sql-test.env `
     -e "ACCEPT_EULA=Y" -e "MSSQL_PID=Express" -e "MSSQL_MEMORY_LIMIT_MB=1536" `
     -p 127.0.0.1:14333:1433 mcr.microsoft.com/mssql/server:2022-latest
   ```
3. Run:
   ```powershell
   dotnet test tests/DevLink.Api.Tests
   ```
   Override the server/password with `DEVLINK_TEST_SQL_SERVER` / `DEVLINK_TEST_SQL_PASSWORD` if needed. The test
   code refuses database names without the `DevLinkTest_` prefix and refuses port 1433.

Frontend: `cd frontend && flutter analyze && flutter test`.
