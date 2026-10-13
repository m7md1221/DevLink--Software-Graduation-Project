# DevLink 🚀

A freelance platform connecting **Customers** with **Programmers**.

## Project Structure

- `backend/` — ASP.NET Core Web API (C#)
- `frontend/` — Flutter (Web + Mobile)
- `database/` — SQL Server schema

## Tech Stack

- Backend: ASP.NET Core 8, EF Core, SQL Server
- Frontend: Flutter
- Email: MailKit (Gmail SMTP)
- Auth: Google Sign-In

## Setup

### 1. Database
- Create DB named `DevLink` in SSMS
- Run `database/DevLink_Full.sql`

### 2. Backend
```bash
cd backend
cp appsettings.example.json appsettings.json
# fill your credentials
dotnet restore
dotnet run