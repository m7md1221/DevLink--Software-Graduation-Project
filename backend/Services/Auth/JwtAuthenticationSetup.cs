using System.Diagnostics;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Logging;
using Microsoft.IdentityModel.Tokens;

namespace Services.Auth
{
    // ============================================================
    // JWT Bearer authentication (M2.2). Tokens are read ONLY from the
    // Authorization header: no cookie or query-string handler exists.
    // No endpoint is protected yet — [Authorize] arrives in M2.7.
    // ============================================================
    public static class JwtAuthenticationSetup
    {
        public static IServiceCollection AddDevLinkJwtAuthentication(this IServiceCollection services, IConfiguration configuration)
        {
            // Token values, keys and claim values must never reach the logs (§3.2).
            IdentityModelEventSource.ShowPII = false;
            IdentityModelEventSource.LogCompleteSecurityArtifact = false;

            services.AddOptions<JwtOptions>()
                .Bind(configuration.GetSection(JwtOptions.SectionName))
                .ValidateOnStart();
            services.AddSingleton<IValidateOptions<JwtOptions>, JwtOptionsValidator>();

            services.AddSingleton<JwtKeyRing>();
            services.AddSingleton<TokenService>();

            // Per-request session check (M2.4a, C2).
            services.AddMemoryCache();
            services.AddSingleton<SessionStateCache>();
            services.AddSingleton<ISessionValidator, SessionValidator>();

            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
            services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
                .Configure<JwtKeyRing, IOptions<JwtOptions>>(Configure);

            // Role policies and ICurrentUser: AuthorizationSetup (M2.7).
            services.AddDevLinkAuthorization();

            return services;
        }

        private static void Configure(JwtBearerOptions bearer, JwtKeyRing keys, IOptions<JwtOptions> jwtOptions)
        {
            var jwt = jwtOptions.Value;

            bearer.MapInboundClaims = false;
            bearer.IncludeErrorDetails = false;
            bearer.SaveToken = false;

            bearer.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = jwt.Issuer,
                ValidateAudience = true,
                ValidAudience = jwt.Audience,
                ValidateLifetime = true,
                RequireExpirationTime = true,
                ValidateIssuerSigningKey = true,
                RequireSignedTokens = true,
                IssuerSigningKeys = keys.ValidationKeys,
                ValidAlgorithms = new[] { SecurityAlgorithms.HmacSha256 },
                ValidTypes = new[] { JwtOptions.AccessTokenType },
                ClockSkew = JwtOptions.ClockSkew,
                NameClaimType = JwtRegisteredClaimNames.Sub,
                RoleClaimType = AuthClaims.Role
            };

            bearer.Events = new JwtBearerEvents
            {
                OnTokenValidated = async context =>
                {
                    // Reject tokens that live longer than an access token may (or carry no iat).
                    var maxLifetime = TimeSpan.FromMinutes(JwtOptions.MaxAccessTokenMinutes) + JwtOptions.ClockSkew;
                    if (context.SecurityToken is not JsonWebToken token || token.ValidTo - token.IssuedAt > maxLifetime)
                    {
                        context.Fail("Access token lifetime exceeds the allowed maximum.");
                        return;
                    }

                    // Per-request session check (C2): user, security stamp, active session, status.
                    if (!int.TryParse(token.Subject, out var userId) ||
                        !token.TryGetPayloadValue<string>(AuthClaims.SecurityStamp, out var stamp) ||
                        !token.TryGetPayloadValue<string>(AuthClaims.SessionId, out var sid) ||
                        !Guid.TryParse(sid, out var sessionId))
                    {
                        context.Fail(new SessionRevokedException());
                        return;
                    }

                    var validator = context.HttpContext.RequestServices.GetRequiredService<ISessionValidator>();
                    var result = await validator.ValidateAsync(userId, stamp, sessionId, context.HttpContext.RequestAborted);
                    switch (result.Check)
                    {
                        case SessionCheck.Valid:
                            context.HttpContext.Items[AuthHttpItems.UserStatus] = result.UserStatus;
                            break;
                        case SessionCheck.Unavailable:
                            context.Fail(new SessionCheckUnavailableException());
                            break;
                        default:
                            context.Fail(new SessionRevokedException());
                            break;
                    }
                },
                OnAuthenticationFailed = context =>
                {
                    // Only the failure type is logged — never the token or its claims.
                    SecurityLog(context.HttpContext).LogInformation(
                        "Auth.TokenRejected {FailureType}", context.Exception.GetType().Name);
                    return Task.CompletedTask;
                },
                OnChallenge = async context =>
                {
                    context.HandleResponse();

                    if (context.AuthenticateFailure is SessionCheckUnavailableException)
                    {
                        await AuthProblem.WriteAsync(
                            context.HttpContext,
                            StatusCodes.Status503ServiceUnavailable,
                            AuthErrorCodes.ServiceUnavailable,
                            "DevLink is temporarily unavailable. Please try again.");
                        return;
                    }

                    var tokenSent = context.Request.Headers.Authorization.Count > 0;
                    var (code, message) = context.AuthenticateFailure switch
                    {
                        SecurityTokenExpiredException => (AuthErrorCodes.TokenExpired, "Your session has expired."),
                        SessionRevokedException => (AuthErrorCodes.SessionRevoked, "You have been signed out. Please sign in again."),
                        _ => (AuthErrorCodes.Unauthenticated, "Authentication is required.")
                    };

                    context.Response.Headers.WWWAuthenticate = tokenSent ? "Bearer error=\"invalid_token\"" : "Bearer";
                    await AuthProblem.WriteAsync(context.HttpContext, StatusCodes.Status401Unauthorized, code, message);
                },
                OnForbidden = context => AuthProblem.WriteAsync(
                    context.HttpContext,
                    StatusCodes.Status403Forbidden,
                    AuthErrorCodes.Forbidden,
                    "You don't have permission to do this.")
            };
        }

        private static ILogger SecurityLog(HttpContext context) =>
            context.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("DevLink.Security");
    }

    public static class AuthErrorCodes
    {
        public const string Unauthenticated = "UNAUTHENTICATED";
        public const string TokenExpired = "TOKEN_EXPIRED";
        public const string SessionRevoked = "SESSION_REVOKED";
        public const string SessionExpired = "SESSION_EXPIRED";
        public const string CsrfFailed = "CSRF_FAILED";
        public const string Forbidden = "FORBIDDEN";
        public const string AccountSuspended = "ACCOUNT_SUSPENDED";
        public const string InvalidCredentials = "INVALID_CREDENTIALS";
        public const string AccountLocked = "ACCOUNT_LOCKED";
        public const string ServiceUnavailable = "SERVICE_UNAVAILABLE";
        public const string RateLimited = "RATE_LIMITED";
        public const string CodeInvalid = "CODE_INVALID";
        public const string CodeAttemptsExceeded = "CODE_ATTEMPTS_EXCEEDED";
        public const string VerificationRequired = "VERIFICATION_REQUIRED";
        public const string PasswordPolicy = "PASSWORD_POLICY";
        public const string LinkExpired = "LINK_EXPIRED";
        public const string AccountLinkRequired = "ACCOUNT_LINK_REQUIRED";
        public const string GoogleTokenInvalid = "GOOGLE_TOKEN_INVALID";
        public const string GoogleEmailMismatch = "GOOGLE_EMAIL_MISMATCH";
        public const string GoogleAlreadyLinked = "GOOGLE_ALREADY_LINKED";
    }

    // ProblemDetails-shaped 401/403 bodies. Keeps "message" because the Flutter app reads data['message'] (§3.5).
    public static class AuthProblem
    {
        // The same body as an action result, for refusals decided inside an action (ownership, limits).
        public static ObjectResult Result(HttpContext context, int status, string errorCode, string message)
        {
            var result = new ObjectResult(new
            {
                type = "about:blank",
                title = ReasonPhrases.GetReasonPhrase(status),
                status,
                errorCode,
                message,
                traceId = Activity.Current?.Id ?? context.TraceIdentifier
            })
            {
                StatusCode = status
            };
            result.ContentTypes.Add("application/problem+json");
            return result;
        }

        public static ObjectResult Forbidden(HttpContext context, string message) =>
            Result(context, StatusCodes.Status403Forbidden, AuthErrorCodes.Forbidden, message);

        public static Task WriteAsync(HttpContext context, int status, string errorCode, string message)
        {
            context.Response.StatusCode = status;
            context.Response.ContentType = "application/problem+json";

            return context.Response.WriteAsJsonAsync(new
            {
                type = "about:blank",
                title = ReasonPhrases.GetReasonPhrase(status),
                status,
                errorCode,
                message,
                traceId = Activity.Current?.Id ?? context.TraceIdentifier
            }, options: null, contentType: "application/problem+json");
        }
    }
}
