using DataBase;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Services;

namespace DevLink.Api.Tests.Infrastructure
{
    // ============================================================
    // Hosts the real API in memory against a brand-new, uniquely
    // named database on the disposable test SQL Server. The database
    // is created for the test class and dropped afterwards.
    // ============================================================
    public class DevLinkApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
    {
        public string DatabaseName { get; } = TestDatabase.NewDatabaseName();

        public CapturingEmailSender Emails { get; } = new();

        public string SigningKey { get; } = TestSecuritySettings.NewSigningKey();

        public string ConnectionString => TestDatabase.BuildConnectionString(DatabaseName);

        // Lets individual tests swap the email sender (e.g. one that throws).
        public IEmailSender? EmailSenderOverride { get; set; }

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.UseSetting("Google:ClientId", "test-client-id.apps.googleusercontent.com");

            // M2.2: a random signing key and an https origin (non-Development rules) for every test host.
            builder.ConfigureAppConfiguration((_, configuration) =>
                configuration.AddInMemoryCollection(TestSecuritySettings.Defaults(SigningKey)));

            builder.ConfigureTestServices(services =>
            {
                services.AddControllers().AddApplicationPart(typeof(AuthProbeController).Assembly);

                // Replace the app's DbContext registration entirely (EF 9 composes
                // configuration actions, so both service types must be removed).
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.RemoveAll<IDbContextOptionsConfiguration<AppDbContext>>();
                services.AddDbContext<AppDbContext>(options =>
                    options.UseSqlServer(ConnectionString));

                services.RemoveAll<IEmailSender>();
                services.AddSingleton<IEmailSender>(_ => EmailSenderOverride ?? Emails);
            });
        }

        public async Task InitializeAsync()
        {
            using var scope = Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            TestDatabase.EnsureSafeName(db.Database.GetDbConnection().Database);

            // Build the schema through the real EF migrations, so every test run also validates them.
            await db.Database.MigrateAsync();
        }

        public new async Task DisposeAsync()
        {
            using (var scope = Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

                TestDatabase.EnsureSafeName(db.Database.GetDbConnection().Database);
                await db.Database.EnsureDeletedAsync();
            }

            await base.DisposeAsync();
        }

        public async Task WithDbAsync(Func<AppDbContext, Task> action)
        {
            using var scope = Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            await action(db);
        }
    }
}
