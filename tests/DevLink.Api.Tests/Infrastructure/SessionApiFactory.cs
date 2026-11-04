using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;

namespace DevLink.Api.Tests.Infrastructure
{
    // Real time plus an adjustable offset, so lockout and cache expiry can be tested without waiting.
    public class MutableTimeProvider : TimeProvider
    {
        private TimeSpan _offset;

        public override DateTimeOffset GetUtcNow() => DateTimeOffset.UtcNow + _offset;

        public void Advance(TimeSpan by) => _offset += by;
    }

    // ============================================================
    // DevLinkApiFactory (disposable database) plus: a movable clock,
    // captured logs, and a fixed client IP (TestServer has none) so the
    // IP-prefix rule of SecurityEvents can be checked.
    // ============================================================
    public class SessionApiFactory : DevLinkApiFactory
    {
        public const string ClientIp = "203.0.113.77";
        public const string ClientIpPrefix = "203.0.113.0/24";

        public MutableTimeProvider Time { get; } = new();

        public CapturingLoggerProvider Logs { get; } = new();

        // Hooks for specialised hosts (rate limits, development fallback).
        protected virtual string RemoteIp => ClientIp;

        protected virtual string? Environment => null;

        protected virtual IDictionary<string, string?> ExtraSettings => new Dictionary<string, string?>();

        private sealed class FixedRemoteIp : IStartupFilter
        {
            private readonly IPAddress _ip;

            public FixedRemoteIp(IPAddress ip)
            {
                _ip = ip;
            }

            public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
            {
                app.Use((context, nextMiddleware) =>
                {
                    context.Connection.RemoteIpAddress = _ip;
                    return nextMiddleware(context);
                });
                next(app);
            };
        }

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            if (Environment != null)
            {
                builder.UseEnvironment(Environment);
            }

            builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(ExtraSettings));
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<TimeProvider>();
                services.AddSingleton<TimeProvider>(Time);
                services.AddSingleton<ILoggerProvider>(Logs);
                services.AddTransient<IStartupFilter>(_ => new FixedRemoteIp(IPAddress.Parse(RemoteIp)));
            });
        }

        public static async Task<HttpResponseMessage> LoginAsync(HttpClient client, string email, string password, string userType, string? clientHeader = null)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "/api/Auth/login")
            {
                Content = JsonContent.Create(new { email, password, userType })
            };
            if (clientHeader != null)
            {
                request.Headers.Add("X-DevLink-Client", clientHeader);
            }

            return await client.SendAsync(request);
        }

        public static async Task<string> TokenFrom(HttpResponseMessage login)
        {
            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
            var body = await login.Content.ReadFromJsonAsync<JsonElement>();
            return body.GetProperty("accessToken").GetString()!;
        }

        public static Task<HttpResponseMessage> GetWithToken(HttpClient client, string route, string? token)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, route);
            if (token != null)
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            }

            return client.SendAsync(request);
        }

        public static async Task<string?> ErrorCode(HttpResponseMessage response)
        {
            var text = await response.Content.ReadAsStringAsync();
            if (string.IsNullOrWhiteSpace(text))
            {
                return null;
            }

            var body = JsonDocument.Parse(text).RootElement;
            return body.TryGetProperty("errorCode", out var code) ? code.GetString() : null;
        }
    }
}
