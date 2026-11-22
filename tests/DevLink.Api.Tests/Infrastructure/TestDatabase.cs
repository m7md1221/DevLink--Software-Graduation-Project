using Microsoft.Data.SqlClient;

namespace DevLink.Api.Tests.Infrastructure
{
    // ============================================================
    // Builds connection strings for the DISPOSABLE test SQL Server
    // (container devlink-sql-test on 127.0.0.1:14333 by default).
    // Guards make it impossible to point tests at the dev database.
    // ============================================================
    public static class TestDatabase
    {
        public const string NamePrefix = "DevLinkTest_";

        private const string DefaultServer = "127.0.0.1,14333";

        public static string NewDatabaseName() =>
            NamePrefix + Guid.NewGuid().ToString("N");

        public static string BuildConnectionString(string databaseName)
        {
            EnsureSafeName(databaseName);

            var server = Environment.GetEnvironmentVariable("DEVLINK_TEST_SQL_SERVER")
                ?? DefaultServer;

            if (server.EndsWith(",1433") || server == "localhost" || server == "127.0.0.1")
            {
                throw new InvalidOperationException(
                    "Refusing to run tests against port 1433 (the development SQL Server). " +
                    "Use the disposable test server (devlink-sql-test, port 14333).");
            }

            var builder = new SqlConnectionStringBuilder
            {
                DataSource = server,
                InitialCatalog = databaseName,
                UserID = "sa",
                Password = ReadPassword(),
                TrustServerCertificate = true
            };

            return builder.ConnectionString;
        }

        public static void EnsureSafeName(string databaseName)
        {
            if (!databaseName.StartsWith(NamePrefix, StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    $"Refusing to use database '{databaseName}': test databases must start with '{NamePrefix}'.");
            }
        }

        private static string ReadPassword()
        {
            var fromEnvironment = Environment.GetEnvironmentVariable("DEVLINK_TEST_SQL_PASSWORD");

            if (!string.IsNullOrWhiteSpace(fromEnvironment))
            {
                return fromEnvironment;
            }

            var envFile = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                ".devlink",
                "sql-test.env");

            if (File.Exists(envFile))
            {
                foreach (var line in File.ReadAllLines(envFile))
                {
                    if (line.StartsWith("MSSQL_SA_PASSWORD=", StringComparison.Ordinal))
                    {
                        return line.Substring("MSSQL_SA_PASSWORD=".Length).Trim();
                    }
                }
            }

            throw new InvalidOperationException(
                "Test SQL password not found. Set DEVLINK_TEST_SQL_PASSWORD or create " +
                "%USERPROFILE%\\.devlink\\sql-test.env (see README, 'Running the tests').");
        }
    }
}
