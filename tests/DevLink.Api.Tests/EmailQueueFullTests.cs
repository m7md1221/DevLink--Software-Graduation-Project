using System.Net;
using System.Net.Http.Json;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Services;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // A queue of one that nothing drains, filled before each test: every Enqueue in the app is refused.
    public class FullEmailQueueFactory : SessionApiFactory
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<EmailQueue>();
                services.AddSingleton(sp => new EmailQueue(1, sp.GetRequiredService<ILoggerFactory>().CreateLogger("DevLink.Email")));
                foreach (var sender in services.Where(d => d.ServiceType == typeof(IHostedService) && d.ImplementationType == typeof(EmailQueueService)).ToList())
                {
                    services.Remove(sender);
                }
            });
        }

        public EmailQueue Queue => Services.GetRequiredService<EmailQueue>();
    }

    // ============================================================
    // M2.11b, KI-67: a full email queue gives every caller the true outcome.
    // Sign-up and reset codes keep the generic response (no account
    // enumeration) and the drop is logged without personal data; the reuse
    // alert records Failure/QueueFull; a password change still completes.
    // ============================================================
    public class EmailQueueFullTests : IClassFixture<FullEmailQueueFactory>
    {
        private const string Password = "Matrix-Pass-42";

        private readonly FullEmailQueueFactory _factory;
        private readonly HttpClient _client;

        public EmailQueueFullTests(FullEmailQueueFactory factory)
        {
            factory.Time.Reset();
            _factory = factory;
            _client = CookieClient.Create(factory);
            if (factory.Queue.Reader.Count == 0)
            {
                Assert.True(factory.Queue.Enqueue("filler@example.test", "filler", "filler"));
            }
        }

        private List<CapturedLog> QueueFullLogs() =>
            _factory.Logs.Entries.Where(e => e.Message.StartsWith("Email.QueueFull", StringComparison.Ordinal)).ToList();

        [Theory]
        [InlineData("/api/Auth/send-code", false)]
        [InlineData("/api/Auth/send-code", true)]
        [InlineData("/api/Auth/send-reset-code", true)]
        public async Task T_AU_04b_code_requests_keep_the_generic_response_and_log_the_drop_without_the_address(string route, bool existingAccount)
        {
            var email = existingAccount
                ? (await AdminRoutes.AccountAsync(_factory, _client, "Customer")).Email
                : ApiTestHelpers.UniqueEmail("queue-full");
            var logsBefore = QueueFullLogs().Count;

            var response = await _client.PostAsJsonAsync(route, new { email });

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = await CookieClient.Json(response);
            Assert.Equal(10, body.GetProperty("expiresInMinutes").GetInt32());
            Assert.StartsWith("If ", body.GetProperty("message").GetString());

            var logs = QueueFullLogs();
            Assert.Equal(logsBefore + 1, logs.Count);
            Assert.Equal(LogLevel.Warning, logs[^1].Level);
            Assert.DoesNotContain("@", logs[^1].Message);
            Assert.DoesNotContain(email.Split('@')[0], _factory.Logs.AllText);
            Assert.Equal(1, _factory.Queue.Reader.Count);
        }

        [Fact]
        public async Task T_AU_04c_the_reuse_alert_records_failure_when_the_queue_is_full_and_the_revocation_still_happens()
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");
            var login = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email = account.Email, password = Password, userType = "Customer" }));
            var first = CookieClient.CookieValue(login)!;
            var current = CookieClient.CookieValue(await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: first)))!;

            var replay = await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: first));

            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(replay));
            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: current))));
            await _factory.WithDbAsync(async db =>
            {
                var alert = await db.SecurityEvents.AsNoTracking().SingleAsync(e => e.UserId == account.Id && e.EventType == "Auth.ReuseAlertQueued");
                Assert.Equal("Failure", alert.Outcome);
                Assert.Contains("QueueFull", alert.Details);
            });
        }

        [Fact]
        public async Task T_AU_04d_a_password_change_completes_when_its_notice_cant_be_queued()
        {
            var account = await AdminRoutes.AccountAsync(_factory, _client, "Customer");

            var change = await _client.SendAsync(CookieClient.Post("/api/Auth/change-password",
                new { currentPassword = Password, newPassword = "Brand-New-Pass-42" }, client: null, origin: null, bearer: account.Token));

            Assert.Equal(HttpStatusCode.OK, change.StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await SessionApiFactory.LoginAsync(_client, account.Email, "Brand-New-Pass-42", "Customer")).StatusCode);
            Assert.Contains(QueueFullLogs(), l => l.Message.Contains(PasswordChangeService.NoticeSubject));
            Assert.Contains(_factory.Logs.Entries, l => l.Message.Contains($"Auth.PasswordChanged user {account.Id}") && l.Message.Contains("notice queued False"));
        }
    }
}
