using System.Diagnostics;
using Microsoft.AspNetCore.Authentication.JwtBearer;
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

            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
            services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
                .Configure<JwtKeyRing, IOptions<JwtOptions>>(Configure);

            services.AddAuthorization();

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
                OnTokenValidated = context =>
                {
                    // Reject tokens that live longer than an access token may (or carry no iat).
                    var maxLifetime = TimeSpan.FromMinutes(JwtOptions.MaxAccessTokenMinutes) + JwtOptions.ClockSkew;
                    if (context.SecurityToken is not JsonWebToken token || token.ValidTo - token.IssuedAt > maxLifetime)
                    {
                        context.Fail("Access token lifetime exceeds the allowed maximum.");
                    }

                    return Task.CompletedTask;
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

                    var tokenSent = context.Request.Headers.Authorization.Count > 0;
                    var expired = context.AuthenticateFailure is SecurityTokenExpiredException;

                    context.Response.Headers.WWWAuthenticate = tokenSent ? "Bearer error=\"invalid_token\"" : "Bearer";
                    await AuthProblem.WriteAsync(
                        context.HttpContext,
                        StatusCodes.Status401Unauthorized,
                        expired ? AuthErrorCodes.TokenExpired : AuthErrorCodes.Unauthenticated,
                        expired ? "Your session has expired." : "Authentication is required.");
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
        public const string Forbidden = "FORBIDDEN";
    }

    // ProblemDetails-shaped 401/403 bodies. Keeps "message" because the Flutter app reads data['message'] (§3.5).
    public static class AuthProblem
    {
        public static Task WriteAsync(HttpContext context, int status, string errorCode, string message)
        {
            context.Response.StatusCode = status;
            context.Response.ContentType = "application/problem+json";

            return context.Response.WriteAsJsonAsync(new
            {
                type = "about:blank",
                title = status == StatusCodes.Status401Unauthorized ? "Unauthorized" : "Forbidden",
                status,
                errorCode,
                message,
                traceId = Activity.Current?.Id ?? context.TraceIdentifier
            }, options: null, contentType: "application/problem+json");
        }
    }
}
