using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Services;
using Services.Auth;

namespace DevLink.Api.Tests
{
    // ============================================================
    // M2.11 audit: two checks the design lists that were only sampled before.
    //   T-SP-04  every route that isn't allowed while suspended answers 403 ACCOUNT_SUSPENDED
    //            to a suspended account (data-driven over all endpoints, design §8, Q5)
    //   T-AU-04  a full queue never blocks a request (the email channel; security events
    //            are written in the request's own transaction, not through a channel)
    // ============================================================
    public class SuspendedEverywhereTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;

        public SuspendedEverywhereTests(SessionApiFactory factory)
        {
            factory.Time.Reset();
            _factory = factory;
        }

        private static readonly string[] AllowedWhileSuspended =
        {
            // The whole AuthController: sign-in flows, session, me (class-level attribute).
            "Support POST api/Support",
            "Support GET api/Support/{id}",
            "Support GET api/Support/my/{userId}",
            "Support GET api/Support/my/{userId}/unread-count",
            "Support POST api/Support/{id}/mark-reply-read"
        };

        private IEnumerable<(RouteEndpoint Endpoint, string Method)> Routes() =>
            _factory.Services.GetRequiredService<EndpointDataSource>().Endpoints
                .OfType<RouteEndpoint>()
                .SelectMany(e => (e.Metadata.GetMetadata<HttpMethodMetadata>()?.HttpMethods ?? Array.Empty<string>()).Select(m => (e, m)));

        private static bool Allowed(RouteEndpoint endpoint) =>
            endpoint.Metadata.GetMetadata<AllowSuspendedAttribute>() != null;

        private static string PathOf(RouteEndpoint endpoint) =>
            "/" + System.Text.RegularExpressions.Regex.Replace(endpoint.RoutePattern.RawText!, @"\{[^}]+\}", "1");

        [Fact]
        public void T_SP_04a_the_allowed_while_suspended_routes_are_exactly_the_reviewed_list()
        {
            var allowed = Routes().Where(r => Allowed(r.Endpoint)).ToList();
            var outsideAuth = allowed
                .Where(r => !r.Endpoint.RoutePattern.RawText!.StartsWith("api/Auth", StringComparison.OrdinalIgnoreCase))
                .Select(r => $"Support {r.Method} {r.Endpoint.RoutePattern.RawText}")
                .OrderBy(n => n);

            Assert.Equal(AllowedWhileSuspended.OrderBy(n => n), outsideAuth);
            Assert.Contains(allowed, r => r.Endpoint.RoutePattern.RawText == "api/Auth/me");
        }

        [Fact]
        public async Task T_SP_04_every_other_route_refuses_a_suspended_account()
        {
            const string password = "Matrix-Pass-42";
            var account = await AdminRoutes.AccountAsync(_factory, _factory.CreateClient(), "Customer");
            await _factory.WithDbAsync(async db =>
            {
                (await db.Users.SingleAsync(u => u.Id == account.Id)).Status = UserStatus.Suspended;
                await db.SaveChangesAsync();
            });
            _factory.Services.GetRequiredService<SessionStateCache>().Invalidate(account.Id);
            var token = await SessionApiFactory.TokenFrom(await SessionApiFactory.LoginAsync(_factory.CreateClient(), account.Email, password, "Customer"));

            var client = _factory.CreateClient();
            var blocked = Routes().Where(r => !Allowed(r.Endpoint)).ToList();
            var wrong = new List<string>();
            foreach (var (endpoint, method) in blocked)
            {
                using var request = new HttpRequestMessage(new HttpMethod(method), PathOf(endpoint));
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                if (method != "GET" && method != "DELETE")
                {
                    request.Content = new StringContent("{}", Encoding.UTF8, "application/json");
                }

                var response = await client.SendAsync(request);
                if (response.StatusCode != HttpStatusCode.Forbidden || await SessionApiFactory.ErrorCode(response) != "ACCOUNT_SUSPENDED")
                {
                    wrong.Add($"{method} {endpoint.RoutePattern.RawText} -> {(int)response.StatusCode}");
                }
            }

            Assert.True(blocked.Count > 60, $"only {blocked.Count} routes found");
            Assert.Empty(wrong);

            // The account itself is unchanged by the sweep: still suspended, nothing written on its behalf.
            await _factory.WithDbAsync(async db =>
            {
                Assert.Equal(UserStatus.Suspended, (await db.Users.AsNoTracking().SingleAsync(u => u.Id == account.Id)).Status);
                Assert.False(await db.Posts.AnyAsync(p => p.UserId == account.Id));
            });
        }
    }

    public class EmailQueueAuditTests
    {
        [Fact]
        public void T_AU_04_a_full_queue_refuses_new_mail_at_once_instead_of_blocking_the_request()
        {
            var queue = new EmailQueue();
            for (var i = 0; i < 1_000; i++)
            {
                Assert.True(queue.Enqueue($"user{i}@example.test", "s", "b"));
            }

            var watch = Stopwatch.StartNew();
            var queued = queue.Enqueue("late@example.test", "s", "b");
            watch.Stop();

            // Never blocks, never grows past its bound, and (KI-67, fixed in M2.11b) reports the refusal.
            Assert.False(queued);
            Assert.True(watch.ElapsedMilliseconds < 100, $"took {watch.ElapsedMilliseconds} ms");
            Assert.Equal(1_000, queue.Reader.Count);
            Assert.True(queue.Reader.TryRead(out var first));
            Assert.Equal("user0@example.test", first!.To);
        }
    }
}
