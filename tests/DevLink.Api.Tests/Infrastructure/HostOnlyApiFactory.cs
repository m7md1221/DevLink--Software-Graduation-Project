using DataBase;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Services.Auth;

namespace DevLink.Api.Tests.Infrastructure
{
    // ============================================================
    // Hosts the API with a fully controlled configuration and NO
    // database: configuration sources are replaced (no appsettings.json,
    // no user-secrets, no environment variables), and the DbContext points
    // at a never-created test database name. Used for start-up and
    // token-validation tests.
    // ============================================================
    // Class-fixture form (xUnit needs a parameterless constructor): default settings, "Testing" environment.
    public class DefaultHostApiFactory : HostOnlyApiFactory
    {
    }

    public class HostOnlyApiFactory : WebApplicationFactory<Program>
    {
        private readonly string _environment;
        private readonly Dictionary<string, string?> _settings;
        private readonly Action<IServiceCollection>? _configureServices;
        private readonly bool _useRealSessionValidator;

        // There is no database here, so tokens minted by the tests are treated as belonging to an
        // active session of an active user. Session-state behaviour is tested against a real database.
        private sealed class AcceptingSessionValidator : ISessionValidator
        {
            public Task<SessionValidationResult> ValidateAsync(int userId, string securityStamp, Guid sessionId, CancellationToken cancellationToken) =>
                Task.FromResult(new SessionValidationResult(SessionCheck.Valid, "Active"));
        }

        public HostOnlyApiFactory(
            string environment = "Testing",
            IDictionary<string, string?>? overrides = null,
            Action<IServiceCollection>? configureServices = null,
            bool useRealSessionValidator = false)
        {
            _environment = environment;
            _configureServices = configureServices;
            _useRealSessionValidator = useRealSessionValidator;

            _settings = TestSecuritySettings.Defaults(SigningKey);
            foreach (var (key, value) in overrides ?? new Dictionary<string, string?>())
            {
                if (value == null)
                {
                    _settings.Remove(key);
                }
                else
                {
                    _settings[key] = value;
                }
            }
        }

        public string SigningKey { get; } = TestSecuritySettings.NewSigningKey();

        public CapturingLoggerProvider Logs { get; } = new();

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment(_environment);

            builder.ConfigureAppConfiguration((_, configuration) =>
            {
                configuration.Sources.Clear();
                configuration.AddInMemoryCollection(_settings);
            });

            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.RemoveAll<IDbContextOptionsConfiguration<AppDbContext>>();
                services.AddDbContext<AppDbContext>(options =>
                    options.UseSqlServer(TestDatabase.BuildConnectionString(TestDatabase.NewDatabaseName())));

                services.AddSingleton<ILoggerProvider>(Logs);
                services.AddControllers().AddApplicationPart(typeof(AuthProbeController).Assembly);

                if (!_useRealSessionValidator)
                {
                    services.RemoveAll<ISessionValidator>();
                    services.AddSingleton<ISessionValidator, AcceptingSessionValidator>();
                }

                _configureServices?.Invoke(services);
            });
        }

        // Starts the host and returns every message of the start-up failure (Assert fails if it starts).
        public string StartupFailure()
        {
            var exception = Assert.ThrowsAny<Exception>(() => CreateClient());
            return Describe(exception);
        }

        private static string Describe(Exception exception)
        {
            var parts = new List<string>();
            for (var e = exception; e != null; e = e.InnerException)
            {
                parts.Add(e.Message);
                if (e is OptionsValidationException validation)
                {
                    parts.AddRange(validation.Failures);
                }

                if (e is AggregateException aggregate)
                {
                    parts.AddRange(aggregate.InnerExceptions.Select(Describe));
                }
            }

            return string.Join(" | ", parts);
        }
    }
}
