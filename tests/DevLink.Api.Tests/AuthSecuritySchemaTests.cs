using System.Security.Cryptography;
using DataBase;
using DevLink.Api.Tests.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace DevLink.Api.Tests
{
    // T-MIG-01…06: guarantees of migration AddAuthSecurity (M2.3), checked on a disposable database
    // built through the real EF migrations.
    public class AuthSecuritySchemaTests : IClassFixture<DevLinkApiFactory>
    {
        private readonly DevLinkApiFactory _factory;

        public AuthSecuritySchemaTests(DevLinkApiFactory factory)
        {
            _factory = factory;
        }

        private static User NewUser(string tag) => new()
        {
            Email = ApiTestHelpers.UniqueEmail(tag),
            PasswordHash = "not-a-real-hash",
            UserType = "Customer"
        };

        private static AuthSession NewSession(int userId) => new()
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CreatedAt = DateTime.UtcNow,
            LastRefreshedAt = DateTime.UtcNow,
            AbsoluteExpiresAt = DateTime.UtcNow.AddDays(30)
        };

        private static RefreshToken NewToken(Guid sessionId, string status) => new()
        {
            SessionId = sessionId,
            TokenHash = RandomNumberGenerator.GetBytes(32),
            Status = status,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(7)
        };

        private static bool IsUniqueViolation(DbUpdateException e) =>
            e.InnerException is SqlException { Number: 2601 or 2627 };

        [Fact]
        public async Task T_MIG_01_new_users_get_a_distinct_random_security_stamp_and_active_status()
        {
            var users = Enumerable.Range(0, 5).Select(i => NewUser($"stamp{i}")).ToList();
            await _factory.WithDbAsync(async db =>
            {
                db.Users.AddRange(users);
                await db.SaveChangesAsync();
            });

            await _factory.WithDbAsync(async db =>
            {
                var emails = users.Select(u => u.Email).ToList();
                var stored = await db.Users.Where(u => emails.Contains(u.Email)).ToListAsync();

                Assert.Equal(5, stored.Select(u => u.SecurityStamp).Distinct().Count());
                Assert.All(stored, u =>
                {
                    Assert.Matches("^[0-9a-f]{32}$", u.SecurityStamp);
                    Assert.Equal(UserStatus.Active, u.Status);
                    Assert.Equal(0, u.FailedLoginCount);
                    Assert.Null(u.GoogleSubject);
                });
            });
        }

        [Fact]
        public async Task T_MIG_02_google_subject_is_unique_when_set_and_optional_otherwise()
        {
            var subject = "google-sub-" + Guid.NewGuid().ToString("N");
            var first = NewUser("g1");
            first.GoogleSubject = subject;
            await _factory.WithDbAsync(async db =>
            {
                db.Users.AddRange(first, NewUser("g-null-a"), NewUser("g-null-b"));
                await db.SaveChangesAsync();
            });

            var duplicate = NewUser("g2");
            duplicate.GoogleSubject = subject;
            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(duplicate);
                var error = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
                Assert.True(IsUniqueViolation(error));
            });
        }

        [Fact]
        public async Task T_MIG_03_refresh_token_hash_is_unique()
        {
            var user = NewUser("rt-hash");
            var session = NewSession(0);
            var hash = RandomNumberGenerator.GetBytes(32);

            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(user);
                await db.SaveChangesAsync();
                session.UserId = user.Id;
                db.AuthSessions.Add(session);
                var rotated = NewToken(session.Id, RefreshTokenStatus.Rotated);
                rotated.TokenHash = hash;
                db.RefreshTokens.Add(rotated);
                await db.SaveChangesAsync();
            });

            await _factory.WithDbAsync(async db =>
            {
                var copy = NewToken(session.Id, RefreshTokenStatus.Active);
                copy.TokenHash = (byte[])hash.Clone();
                db.RefreshTokens.Add(copy);
                var error = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
                Assert.True(IsUniqueViolation(error));
            });
        }

        [Fact]
        public async Task T_MIG_04_a_session_keeps_rotated_tokens_but_never_two_active_tokens()
        {
            var user = NewUser("rt-active");
            var session = NewSession(0);

            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(user);
                await db.SaveChangesAsync();
                session.UserId = user.Id;
                db.AuthSessions.Add(session);
                db.RefreshTokens.AddRange(
                    NewToken(session.Id, RefreshTokenStatus.Rotated),
                    NewToken(session.Id, RefreshTokenStatus.Rotated),
                    NewToken(session.Id, RefreshTokenStatus.Active));
                await db.SaveChangesAsync();
            });

            await _factory.WithDbAsync(async db =>
            {
                db.RefreshTokens.Add(NewToken(session.Id, RefreshTokenStatus.Active));
                var error = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
                Assert.True(IsUniqueViolation(error));
                Assert.Equal(3, await db.RefreshTokens.CountAsync(t => t.SessionId == session.Id));
            });
        }

        [Fact]
        public async Task T_MIG_05_security_records_are_not_cascade_deleted_with_their_user_or_session()
        {
            var user = NewUser("no-cascade");
            var session = NewSession(0);

            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(user);
                await db.SaveChangesAsync();
                session.UserId = user.Id;
                db.AuthSessions.Add(session);
                db.RefreshTokens.Add(NewToken(session.Id, RefreshTokenStatus.Active));
                await db.SaveChangesAsync();
            });

            await _factory.WithDbAsync(async db =>
            {
                var deleted = await Assert.ThrowsAsync<SqlException>(() =>
                    db.Database.ExecuteSqlInterpolatedAsync($"DELETE FROM Users WHERE Id = {user.Id}"));
                Assert.Equal(547, deleted.Number);
                Assert.Contains("FK_AuthSessions_Users", deleted.Message);
            });

            await _factory.WithDbAsync(async db =>
            {
                var error = await Assert.ThrowsAnyAsync<Exception>(() =>
                    db.Database.ExecuteSqlInterpolatedAsync($"DELETE FROM AuthSessions WHERE Id = {session.Id}"));
                Assert.Contains("FK_RefreshTokens_AuthSessions", error.Message + error.InnerException?.Message);

                Assert.True(await db.Users.AnyAsync(u => u.Id == user.Id));
                Assert.Equal(1, await db.RefreshTokens.CountAsync(t => t.SessionId == session.Id));
            });
        }

        [Fact]
        public async Task T_MIG_06_status_values_are_constrained()
        {
            var user = NewUser("status");
            await _factory.WithDbAsync(async db =>
            {
                db.Users.Add(user);
                await db.SaveChangesAsync();
            });

            await _factory.WithDbAsync(async db =>
            {
                var error = await Assert.ThrowsAnyAsync<Exception>(() =>
                    db.Database.ExecuteSqlInterpolatedAsync($"UPDATE Users SET Status = 'Banned' WHERE Id = {user.Id}"));
                Assert.Contains("CK_Users_Status", error.Message);

                db.AuthSessions.Add(new AuthSession
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    ClientType = "desktop",
                    CreatedAt = DateTime.UtcNow,
                    LastRefreshedAt = DateTime.UtcNow,
                    AbsoluteExpiresAt = DateTime.UtcNow
                });
                var sessionError = await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
                Assert.Contains("CK_AuthSessions_ClientType", sessionError.InnerException?.Message);
            });
        }
    }
}
