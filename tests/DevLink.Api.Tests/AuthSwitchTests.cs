using DevLink.Api.Tests.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // T-SW-01…05: safeguards of the temporary `Auth:EnforceAuthorization` switch (Q1, C1; §7.3).
    public class AuthSwitchTests
    {
        private const string Switch = "Auth:EnforceAuthorization";

        private class FixedAddresses : IBoundAddressSource
        {
            private readonly string[] _addresses;

            public FixedAddresses(params string[] addresses)
            {
                _addresses = addresses;
            }

            public IReadOnlyCollection<string> GetAddresses() => _addresses;
        }

        private static HostOnlyApiFactory Host(string environment, string? switchValue, params string[] boundAddresses) =>
            new(environment,
                new Dictionary<string, string?> { [Switch] = switchValue },
                services =>
                {
                    if (boundAddresses.Length > 0)
                    {
                        services.RemoveAll<IBoundAddressSource>();
                        services.AddSingleton<IBoundAddressSource>(new FixedAddresses(boundAddresses));
                    }
                });

        [Theory]
        [InlineData("Production")]
        [InlineData("Staging")]
        [InlineData("Testing")]
        public void T_SW_01_disabling_enforcement_outside_development_stops_startup(string environment)
        {
            using var factory = Host(environment, "false");

            Assert.Contains("allowed only in the Development environment", factory.StartupFailure());
        }

        [Fact]
        public async Task T_SW_02_development_with_switch_off_starts_warns_and_marks_every_response()
        {
            using var factory = Host("Development", "false");
            var client = factory.CreateClient();

            var response = await client.GetAsync("/__tests/auth/ping");

            Assert.True(response.IsSuccessStatusCode);
            Assert.Equal("NOT-ENFORCED", response.Headers.GetValues(AuthEnforcementOptions.ResponseHeader).Single());
            Assert.Contains(factory.Logs.Entries, e =>
                e.Category == "DevLink.Security" && e.Level == LogLevel.Warning && e.Message.Contains("NOT enforced"));
        }

        [Fact]
        public void T_SW_03_switch_off_with_a_non_loopback_binding_stops_the_application()
        {
            using var factory = Host("Development", "false", "http://localhost:5133", "http://0.0.0.0:5133");
            factory.CreateClient();

            var lifetime = factory.Services.GetRequiredService<IHostApplicationLifetime>();
            Assert.True(lifetime.ApplicationStopping.IsCancellationRequested);
            Assert.Contains(factory.Logs.Entries, e => e.Level == LogLevel.Critical && e.Message.Contains("0.0.0.0"));
        }

        [Fact]
        public void T_SW_03_switch_off_with_loopback_bindings_keeps_running()
        {
            using var factory = Host("Development", "false", "http://localhost:5133", "http://127.0.0.1:5134", "http://[::1]:5135");
            factory.CreateClient();

            var lifetime = factory.Services.GetRequiredService<IHostApplicationLifetime>();
            Assert.False(lifetime.ApplicationStopping.IsCancellationRequested);
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("true")]
        [InlineData("no")]
        [InlineData("0")]
        public async Task T_SW_04_anything_but_an_explicit_false_means_enforced(string? switchValue)
        {
            using var factory = Host("Production", switchValue, "http://0.0.0.0:8080");
            var client = factory.CreateClient();

            var response = await client.GetAsync("/__tests/auth/ping");

            Assert.True(response.IsSuccessStatusCode);
            Assert.False(response.Headers.Contains(AuthEnforcementOptions.ResponseHeader));
            Assert.True(factory.Services.GetRequiredService<Microsoft.Extensions.Options.IOptions<AuthEnforcementOptions>>().Value.Enforced);
            Assert.False(factory.Services.GetRequiredService<IHostApplicationLifetime>().ApplicationStopping.IsCancellationRequested);
            Assert.DoesNotContain(factory.Logs.Entries, e => e.Message.Contains("NOT enforced"));
        }

        [Theory]
        [InlineData("http://localhost:5133", true)]
        [InlineData("http://LOCALHOST:5133", true)]
        [InlineData("http://127.0.0.1:5133", true)]
        [InlineData("https://[::1]:7117", true)]
        [InlineData("http://0.0.0.0:5133", false)]
        [InlineData("http://[::]:5133", false)]
        [InlineData("http://*:5133", false)]
        [InlineData("http://+:80", false)]
        [InlineData("http://192.168.1.20:5133", false)]
        [InlineData("http://devlink.example:80", false)]
        public void T_SW_05_loopback_detection(string address, bool expected)
        {
            Assert.Equal(expected, AuthEnforcementMonitor.IsLoopbackAddress(address));
        }
    }
}
