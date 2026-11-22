using System.Net;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.Options;

namespace Services.Auth
{
    // ============================================================
    // `Auth:EnforceAuthorization` — the temporary M2 migration switch
    // (Q1, binding condition C1; M2_AUTH_DESIGN §7.3).
    //
    // Enforced unless the value is explicitly "false". Disabling it is
    // allowed only in Development, only while every bound address is
    // loopback, and is announced loudly. The fallback paths themselves
    // arrive with M2.5/M2.7/M2.8; everything here is removed in M2.13.
    // ============================================================
    public class AuthEnforcementOptions
    {
        public const string ConfigKey = "Auth:EnforceAuthorization";
        public const string ResponseHeader = "X-DevLink-Auth";

        // True only when the setting is present and exactly "false" (case-insensitive, trimmed).
        public bool FallbackRequested { get; set; }

        public bool Enforced => !FallbackRequested;

        public static bool IsExplicitlyDisabled(string? value) =>
            string.Equals(value?.Trim(), "false", StringComparison.OrdinalIgnoreCase);
    }

    public class AuthEnforcementOptionsValidator : IValidateOptions<AuthEnforcementOptions>
    {
        private readonly IHostEnvironment _environment;

        public AuthEnforcementOptionsValidator(IHostEnvironment environment)
        {
            _environment = environment;
        }

        public ValidateOptionsResult Validate(string? name, AuthEnforcementOptions options)
        {
            if (options.FallbackRequested && !_environment.IsDevelopment())
            {
                return ValidateOptionsResult.Fail(
                    $"{AuthEnforcementOptions.ConfigKey}=false is allowed only in the Development environment " +
                    $"(current: '{_environment.EnvironmentName}'). Remove the setting.");
            }

            return ValidateOptionsResult.Success;
        }
    }

    // Where the server is listening. Replaceable in tests (TestServer has no real addresses).
    public interface IBoundAddressSource
    {
        IReadOnlyCollection<string> GetAddresses();
    }

    public class ServerBoundAddressSource : IBoundAddressSource
    {
        private readonly IServer _server;

        public ServerBoundAddressSource(IServer server)
        {
            _server = server;
        }

        public IReadOnlyCollection<string> GetAddresses() =>
            _server.Features.Get<IServerAddressesFeature>()?.Addresses.ToList() ?? new List<string>();
    }

    // Startup warning, loopback-binding check and a reminder every 10 minutes while enforcement is off.
    public class AuthEnforcementMonitor : BackgroundService
    {
        private static readonly TimeSpan ReminderInterval = TimeSpan.FromMinutes(10);

        private readonly AuthEnforcementOptions _options;
        private readonly IBoundAddressSource _addresses;
        private readonly IHostApplicationLifetime _lifetime;
        private readonly ILogger _logger;

        public AuthEnforcementMonitor(
            IOptions<AuthEnforcementOptions> options,
            IBoundAddressSource addresses,
            IHostApplicationLifetime lifetime,
            ILoggerFactory loggers)
        {
            _options = options.Value;
            _addresses = addresses;
            _lifetime = lifetime;
            _logger = loggers.CreateLogger("DevLink.Security");
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            if (_options.Enforced)
            {
                return;
            }

            LogNotEnforced();
            _lifetime.ApplicationStarted.Register(CheckLoopbackBinding);

            using var timer = new PeriodicTimer(ReminderInterval);
            try
            {
                while (await timer.WaitForNextTickAsync(stoppingToken))
                {
                    LogNotEnforced();
                }
            }
            catch (OperationCanceledException)
            {
                // Host shutting down.
            }
        }

        private void LogNotEnforced() =>
            _logger.LogWarning(
                "Authorization is NOT enforced ({Setting}=false, Development only). Never expose this API; the setting is removed in M2.13.",
                AuthEnforcementOptions.ConfigKey);

        private void CheckLoopbackBinding()
        {
            var nonLoopback = _addresses.GetAddresses().Where(a => !IsLoopbackAddress(a)).ToList();
            if (nonLoopback.Count == 0)
            {
                return;
            }

            _logger.LogCritical(
                "Stopping: {Setting}=false requires loopback-only binding, but the server listens on {Addresses}.",
                AuthEnforcementOptions.ConfigKey, string.Join(", ", nonLoopback));
            _lifetime.StopApplication();
        }

        // "http://localhost:5133", "http://127.0.0.1:5133", "http://[::1]:5133" → true; "*", "+", 0.0.0.0, LAN IPs → false.
        public static bool IsLoopbackAddress(string address)
        {
            string host;
            try
            {
                host = BindingAddress.Parse(address).Host;
            }
            catch (FormatException)
            {
                return false;
            }

            if (string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            return IPAddress.TryParse(host.Trim('[', ']'), out var ip) && IPAddress.IsLoopback(ip);
        }
    }

    public static class AuthEnforcementSetup
    {
        public static IServiceCollection AddDevLinkAuthEnforcement(this IServiceCollection services)
        {
            services.AddOptions<AuthEnforcementOptions>()
                .Configure<IConfiguration>((options, configuration) =>
                    options.FallbackRequested = AuthEnforcementOptions.IsExplicitlyDisabled(configuration[AuthEnforcementOptions.ConfigKey]))
                .ValidateOnStart();
            services.AddSingleton<IValidateOptions<AuthEnforcementOptions>, AuthEnforcementOptionsValidator>();

            services.AddSingleton<IBoundAddressSource, ServerBoundAddressSource>();
            services.AddHostedService<AuthEnforcementMonitor>();

            return services;
        }
    }
}
