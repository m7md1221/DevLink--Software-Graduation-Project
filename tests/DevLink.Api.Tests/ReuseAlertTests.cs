using System.Net;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // T-AL-01…03 (Q12, §6.5): refresh-token reuse alert email.
    public class ReuseAlertTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public ReuseAlertTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = CookieClient.Create(factory);
        }

        private sealed record WebSession(int UserId, string Email, Guid SessionId, string FirstCookie, string CurrentCookie);

        // Signs in on the web and rotates once, so replaying the first cookie is a reuse.
        private async Task<WebSession> RotatedSessionAsync(string? email = null)
        {
            if (email == null)
            {
                email = ApiTestHelpers.UniqueEmail("reuse");
                await ApiTestHelpers.RegisterAsync(_factory.CreateClient(), _factory.Emails, email, "Secret123", "Customer");
            }

            var login = await _client.SendAsync(CookieClient.Post("/api/Auth/login", new { email, password = "Secret123", userType = "Customer" }));
            var userId = (await CookieClient.Json(login)).GetProperty("userId").GetInt32();
            var first = CookieClient.CookieValue(login)!;
            var current = CookieClient.CookieValue(await Refresh(first))!;
            Guid sessionId = default;
            await _factory.WithDbAsync(async db =>
                sessionId = await db.AuthSessions.Where(s => s.UserId == userId).OrderByDescending(s => s.CreatedAt).Select(s => s.Id).FirstAsync());
            return new WebSession(userId, email, sessionId, first, current);
        }

        private Task<HttpResponseMessage> Refresh(string cookie) =>
            _client.SendAsync(CookieClient.Post("/api/Auth/session/refresh", cookie: cookie));

        private List<CapturedEmail> Alerts(string email) =>
            _factory.Emails.To(email).Where(m => m.Subject == RefreshSessionService.ReuseAlertSubject).ToList();

        private async Task<List<SecurityEvent>> AlertEvents(int userId)
        {
            var events = new List<SecurityEvent>();
            await _factory.WithDbAsync(async db => events = await db.SecurityEvents.AsNoTracking()
                .Where(e => e.UserId == userId && e.EventType == "Auth.ReuseAlertQueued").OrderBy(e => e.Id).ToListAsync());
            return events;
        }

        private async Task AddAlertEventAsync(int userId, Guid sessionId, TimeSpan ago)
        {
            await _factory.WithDbAsync(async db =>
            {
                db.SecurityEvents.Add(new SecurityEvent
                {
                    OccurredAt = _factory.Time.GetUtcNow().UtcDateTime - ago,
                    EventType = "Auth.ReuseAlertQueued",
                    Outcome = SecurityEventOutcome.Success,
                    UserId = userId,
                    SessionId = sessionId
                });
                await db.SaveChangesAsync();
            });
        }

        [Fact]
        public async Task T_AL_01_a_reuse_queues_one_generic_alert_to_the_account_owner()
        {
            var session = await RotatedSessionAsync();

            var replay = await Refresh(session.FirstCookie);
            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(replay));
            // Further attempts on the revoked family are not new reuse detections: still one alert.
            await Refresh(session.CurrentCookie);
            await Refresh(session.FirstCookie);

            var alert = _factory.Emails.WaitFor(session.Email, m => m.Subject == RefreshSessionService.ReuseAlertSubject);
            Assert.Equal(RefreshSessionService.ReuseAlertBody, alert.Body);
            await Task.Delay(300);
            Assert.Single(Alerts(session.Email));

            var evt = Assert.Single(await AlertEvents(session.UserId));
            Assert.Equal(SecurityEventOutcome.Success, evt.Outcome);
            Assert.Equal(session.SessionId, evt.SessionId);
        }

        [Fact]
        public async Task T_AL_02_at_most_one_alert_per_session_per_hour_and_three_per_user_per_day()
        {
            // Per session family: an alert for this family within the hour suppresses the email.
            var session = await RotatedSessionAsync();
            await AddAlertEventAsync(session.UserId, session.SessionId, TimeSpan.FromMinutes(30));

            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(await Refresh(session.FirstCookie)));

            await Task.Delay(500);
            Assert.Empty(Alerts(session.Email));
            var blocked = (await AlertEvents(session.UserId)).Last();
            Assert.Equal(SecurityEventOutcome.Blocked, blocked.Outcome);
            Assert.Contains("AlertLimit", blocked.Details);

            // Per user: three alerts within 24 h (other sessions) suppress the fourth.
            var second = await RotatedSessionAsync(session.Email);
            for (var i = 0; i < 2; i++) await AddAlertEventAsync(session.UserId, Guid.NewGuid(), TimeSpan.FromHours(20));

            await Refresh(second.FirstCookie);

            await Task.Delay(500);
            Assert.Empty(Alerts(session.Email));
            Assert.Equal(SecurityEventOutcome.Blocked, (await AlertEvents(session.UserId)).Last().Outcome);

            // Older than the windows: no longer counted, so the next reuse is emailed again.
            _factory.Time.Advance(TimeSpan.FromHours(25));
            var third = await RotatedSessionAsync(session.Email);
            await Refresh(third.FirstCookie);
            _factory.Emails.WaitFor(session.Email, m => m.Subject == RefreshSessionService.ReuseAlertSubject);
        }

        [Fact]
        public async Task T_AL_03_the_alert_holds_no_token_ip_or_session_id_and_never_changes_the_revocation()
        {
            var session = await RotatedSessionAsync();

            var replay = await Refresh(session.FirstCookie);

            Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);
            Assert.Equal("SESSION_REVOKED", await CookieClient.ErrorCode(replay));
            var alert = _factory.Emails.WaitFor(session.Email, m => m.Subject == RefreshSessionService.ReuseAlertSubject);
            foreach (var forbidden in new[] { session.FirstCookie, session.CurrentCookie, session.SessionId.ToString(), SessionApiFactory.ClientIp, "203.0.113" })
            {
                Assert.DoesNotContain(forbidden, alert.Body);
                Assert.DoesNotContain(forbidden, alert.Subject);
            }

            await _factory.WithDbAsync(async db =>
                Assert.Equal("ReuseDetected", (await db.AuthSessions.AsNoTracking().SingleAsync(s => s.Id == session.SessionId)).RevokeReason));
        }
    }
}
