using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // T-CD-01…12, T-SE-02 — sign-up and reset codes and proof tokens (M2.5a; §6.2, Q6, Q7, C6).
    public class OneTimeCodeTests : IClassFixture<SessionApiFactory>
    {
        private readonly SessionApiFactory _factory;
        private readonly HttpClient _client;

        public OneTimeCodeTests(SessionApiFactory factory)
        {
            _factory = factory;
            _client = factory.CreateClient();
        }

        private Task<HttpResponseMessage> Post(string path, object body) => _client.PostAsJsonAsync(path, body);

        private async Task<string> SendCodeAsync(string email, string purpose = "signup")
        {
            var before = _factory.Emails.CodeCount(email);
            var response = await Post(purpose == "signup" ? "/api/Auth/send-code" : "/api/Auth/send-reset-code", new { email });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            return _factory.Emails.LatestCodeFor(email, before);
        }

        private Task<HttpResponseMessage> Verify(string email, string code, string purpose = "signup") =>
            Post(purpose == "signup" ? "/api/Auth/verify-code" : "/api/Auth/verify-reset-code", new { email, code });

        private static string Wrong(string code) => code == "000000" ? "111111" : "000000";

        private async Task AdvanceAsync(TimeSpan by, Func<Task> body)
        {
            _factory.Time.Advance(by);
            try { await body(); }
            finally { _factory.Time.Advance(-by); }
        }

        [Fact]
        public async Task T_CD_01_responses_do_not_reveal_whether_an_email_has_an_account()
        {
            var registered = ApiTestHelpers.UniqueEmail("known");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, registered, "Secret123", "Customer");
            var unknown = ApiTestHelpers.UniqueEmail("unknown");

            await AdvanceAsync(TimeSpan.FromMinutes(2), async () =>
            {
                var signupKnown = await Post("/api/Auth/send-code", new { email = registered });
                var signupNew = await Post("/api/Auth/send-code", new { email = unknown });
                Assert.Equal(HttpStatusCode.OK, signupKnown.StatusCode);
                Assert.Equal(await signupNew.Content.ReadAsStringAsync(), await signupKnown.Content.ReadAsStringAsync());

                // The registered inbox gets a notice, not a code.
                var notice = _factory.Emails.WaitFor(registered, m => m.Subject == "DevLink sign-up attempt");
                Assert.DoesNotMatch(@"\b\d{6}\b", notice.Body);

                var resetKnown = await Post("/api/Auth/send-reset-code", new { email = registered });
                var resetUnknown = await Post("/api/Auth/send-reset-code", new { email = unknown });
                Assert.Equal(HttpStatusCode.OK, resetUnknown.StatusCode);
                Assert.Equal(await resetUnknown.Content.ReadAsStringAsync(), await resetKnown.Content.ReadAsStringAsync());
                _factory.Emails.WaitFor(registered, m => m.Subject == "DevLink Password Reset");
                await Task.Delay(300);
                Assert.DoesNotContain(_factory.Emails.To(unknown), m => m.Subject == "DevLink Password Reset"); // nothing sent
            });
        }

        [Fact]
        public async Task T_CD_02_codes_and_emails_are_stored_only_as_keyed_hashes()
        {
            var email = ApiTestHelpers.UniqueEmail("stored");
            var code = await SendCodeAsync(email);

            await _factory.WithDbAsync(async db =>
            {
                var rows = await db.OneTimeCodes.AsNoTracking().OrderByDescending(c => c.Id).Take(50).ToListAsync();
                var dump = string.Join("|", rows.Select(r => Convert.ToHexString(r.EmailKey) + Convert.ToHexString(r.CodeHash)));
                Assert.DoesNotContain(Convert.ToHexString(Encoding.UTF8.GetBytes(email)), dump);
                Assert.DoesNotContain(Convert.ToHexString(Encoding.ASCII.GetBytes(code)), dump);
                Assert.All(rows, r => { Assert.Equal(32, r.EmailKey.Length); Assert.Equal(32, r.CodeHash.Length); });
            });
        }

        [Fact]
        public async Task T_CD_03_codes_expire_after_10_minutes()
        {
            var email = ApiTestHelpers.UniqueEmail("expiry");
            var code = await SendCodeAsync(email);

            await AdvanceAsync(TimeSpan.FromMinutes(11), async () =>
            {
                var response = await Verify(email, code);
                Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
                Assert.Equal("CODE_INVALID", await SessionApiFactory.ErrorCode(response));
            });
        }

        [Fact]
        public async Task T_CD_04_a_code_and_its_proof_token_work_once()
        {
            var email = ApiTestHelpers.UniqueEmail("once");
            var code = await SendCodeAsync(email);

            var first = await Verify(email, code);
            Assert.Equal(HttpStatusCode.OK, first.StatusCode);
            var token = (await first.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("signupToken").GetString();
            Assert.Equal("CODE_INVALID", await SessionApiFactory.ErrorCode(await Verify(email, code)));

            Assert.Equal(HttpStatusCode.OK, (await Post("/api/Auth/signup", new { email, password = "Secret123", userType = "Customer", signupToken = token })).StatusCode);
            var again = await Post("/api/Auth/signup", new { email, password = "Secret123", userType = "Customer", signupToken = token });
            Assert.Equal("VERIFICATION_REQUIRED", await SessionApiFactory.ErrorCode(again));
        }

        [Fact]
        public async Task T_CD_05_five_wrong_attempts_destroy_the_code()
        {
            var email = ApiTestHelpers.UniqueEmail("attempts");
            var code = await SendCodeAsync(email);

            for (var i = 1; i <= 4; i++)
            {
                Assert.Equal("CODE_INVALID", await SessionApiFactory.ErrorCode(await Verify(email, Wrong(code))));
            }

            Assert.Equal("CODE_ATTEMPTS_EXCEEDED", await SessionApiFactory.ErrorCode(await Verify(email, Wrong(code))));
            Assert.Equal("CODE_INVALID", await SessionApiFactory.ErrorCode(await Verify(email, code))); // even the right code
        }

        [Fact]
        public async Task T_CD_06_a_new_code_invalidates_the_previous_code_and_its_proof_token()
        {
            var email = ApiTestHelpers.UniqueEmail("replace");
            var first = await SendCodeAsync(email);
            var proof = (await (await Verify(email, first)).Content.ReadFromJsonAsync<JsonElement>()).GetProperty("signupToken").GetString();

            await AdvanceAsync(TimeSpan.FromSeconds(61), async () =>
            {
                var second = await SendCodeAsync(email);
                Assert.NotNull(second);
                var signup = await Post("/api/Auth/signup", new { email, password = "Secret123", userType = "Customer", signupToken = proof });
                Assert.Equal("VERIFICATION_REQUIRED", await SessionApiFactory.ErrorCode(signup));
            });

            var email2 = ApiTestHelpers.UniqueEmail("replace2");
            var old = await SendCodeAsync(email2);
            await AdvanceAsync(TimeSpan.FromSeconds(61), async () =>
            {
                await SendCodeAsync(email2);
                Assert.Equal("CODE_INVALID", await SessionApiFactory.ErrorCode(await Verify(email2, old)));
            });
        }

        [Fact]
        public async Task T_CD_07_signup_and_reset_require_a_valid_matching_proof_token()
        {
            var email = ApiTestHelpers.UniqueEmail("proof");
            var other = ApiTestHelpers.UniqueEmail("proof-other");
            var token = await ApiTestHelpers.VerifyEmailAsync(_client, _factory.Emails, email);

            async Task Rejected(object body, string path = "/api/Auth/signup") =>
                Assert.Equal("VERIFICATION_REQUIRED", await SessionApiFactory.ErrorCode(await Post(path, body)));

            await Rejected(new { email, password = "Secret123", userType = "Customer" });                           // no token (not Development)
            await Rejected(new { email, password = "Secret123", userType = "Customer", signupToken = "forged-token" }); // unknown token
            await Rejected(new { email = other, password = "Secret123", userType = "Customer", signupToken = token });  // other email
            await Rejected(new { email, newPassword = "Secret123", resetToken = token }, "/api/Auth/reset-password");   // wrong purpose
            await AdvanceAsync(TimeSpan.FromMinutes(16), () =>
                Rejected(new { email, password = "Secret123", userType = "Customer", signupToken = token }));           // expired

            // Untouched by the failures above, the token still works once before it expires.
            Assert.Equal(HttpStatusCode.OK, (await Post("/api/Auth/signup", new { email, password = "Secret123", userType = "Customer", signupToken = token })).StatusCode);
        }

        [Fact]
        public async Task T_CD_08_code_requests_are_limited_per_email()
        {
            var email = ApiTestHelpers.UniqueEmail("cooldown");
            await SendCodeAsync(email);

            var tooSoon = await Post("/api/Auth/send-code", new { email });
            Assert.Equal(HttpStatusCode.TooManyRequests, tooSoon.StatusCode);
            Assert.InRange(int.Parse(tooSoon.Headers.GetValues("Retry-After").Single()), 1, 60);

            // 5 per hour: requests 2–5 one minute apart are accepted, the 6th is refused.
            var offset = TimeSpan.Zero;
            try
            {
                for (var i = 2; i <= 5; i++)
                {
                    offset += TimeSpan.FromSeconds(61);
                    _factory.Time.Advance(TimeSpan.FromSeconds(61));
                    Assert.Equal(HttpStatusCode.OK, (await Post("/api/Auth/send-code", new { email })).StatusCode);
                }

                offset += TimeSpan.FromSeconds(61);
                _factory.Time.Advance(TimeSpan.FromSeconds(61));
                Assert.Equal("RATE_LIMITED", await SessionApiFactory.ErrorCode(await Post("/api/Auth/send-code", new { email })));
            }
            finally
            {
                _factory.Time.Advance(-offset);
            }
        }

        [Fact]
        public async Task T_CD_09_the_per_email_failure_budget_survives_new_codes()
        {
            var email = ApiTestHelpers.UniqueEmail("budget");
            var offset = TimeSpan.Zero;
            try
            {
                // Code 1: 5 failures. Code 2: 5 failures → 10 in the hour.
                for (var round = 0; round < 2; round++)
                {
                    var code = await SendCodeAsync(email);
                    for (var i = 0; i < 5; i++) await Verify(email, Wrong(code));
                    offset += TimeSpan.FromSeconds(61);
                    _factory.Time.Advance(TimeSpan.FromSeconds(61));
                }

                // A brand-new code does not reset the budget: even the right code is refused.
                var third = await SendCodeAsync(email);
                var refused = await Verify(email, third);
                Assert.Equal(HttpStatusCode.TooManyRequests, refused.StatusCode);
                Assert.Equal("RATE_LIMITED", await SessionApiFactory.ErrorCode(refused));

                // The reset purpose shares the budget.
                Assert.Equal(HttpStatusCode.TooManyRequests, (await Verify(email, "123456", "reset")).StatusCode);

                // After the rolling hour, verification works again.
                offset += TimeSpan.FromMinutes(71);
                _factory.Time.Advance(TimeSpan.FromMinutes(71));
                var fresh = await SendCodeAsync(email);
                Assert.Equal(HttpStatusCode.OK, (await Verify(email, fresh)).StatusCode);
            }
            finally
            {
                _factory.Time.Advance(-offset);
            }
        }

        [Fact]
        public async Task T_CD_11_unknown_emails_behave_like_real_ones_on_wrong_codes()
        {
            var registered = ApiTestHelpers.UniqueEmail("reset-known");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, registered, "Secret123", "Customer");
            var unknown = ApiTestHelpers.UniqueEmail("reset-unknown");

            await Post("/api/Auth/send-reset-code", new { email = registered });
            await Post("/api/Auth/send-reset-code", new { email = unknown });

            var known = new List<string?>();
            var ghost = new List<string?>();
            for (var i = 0; i < 5; i++)
            {
                known.Add(await SessionApiFactory.ErrorCode(await Verify(registered, "000000", "reset")));
                ghost.Add(await SessionApiFactory.ErrorCode(await Verify(unknown, "000000", "reset")));
            }

            Assert.Equal(known, ghost);
            Assert.Equal("CODE_ATTEMPTS_EXCEEDED", ghost[^1]);
        }

        [Fact]
        public async Task T_CD_12_parallel_wrong_guesses_cannot_exceed_five_attempts()
        {
            var email = ApiTestHelpers.UniqueEmail("parallel");
            var code = await SendCodeAsync(email);

            await Task.WhenAll(Enumerable.Range(0, 12).Select(_ => Verify(email, Wrong(code))));

            await _factory.WithDbAsync(async db =>
            {
                var rows = await db.OneTimeCodes.AsNoTracking().Where(c => c.Purpose == "Signup").OrderByDescending(c => c.Id).Take(30).ToListAsync();
                Assert.DoesNotContain(rows, r => r.FailedAttempts > 5);
            });
            Assert.Equal("CODE_INVALID", await SessionApiFactory.ErrorCode(await Verify(email, code)));
        }

        [Fact]
        public async Task T_SE_02_events_carry_a_keyed_email_hash_never_the_email()
        {
            var email = ApiTestHelpers.UniqueEmail("emailkey");
            await ApiTestHelpers.RegisterAsync(_client, _factory.Emails, email, "Secret123", "Customer");
            await SessionApiFactory.LoginAsync(_client, email, "Wrong-pass1", "Customer");

            await _factory.WithDbAsync(async db =>
            {
                var events = await db.SecurityEvents.AsNoTracking().Where(e => e.EmailKey != null).OrderByDescending(e => e.Id).Take(200).ToListAsync();
                var keys = events.Where(e => e.EventType is "Auth.CodeRequested" or "Auth.AccountCreated" or "Auth.LoginFailed").Select(e => e.EmailKey).Distinct().ToList();
                Assert.Contains(keys, k => k != null && System.Text.RegularExpressions.Regex.IsMatch(k, "^[0-9a-f]{12}$"));
                Assert.All(events, e => Assert.DoesNotContain(email, $"{e.EmailKey}{e.Details}{e.TargetId}"));
            });
        }
    }
}
