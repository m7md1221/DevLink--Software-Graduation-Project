using DataBase;
using Microsoft.EntityFrameworkCore;
using Services;
using Services.Auth;
using Services.Files;
using Services.Security;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Unhandled errors -> RFC 7807 ProblemDetails (with traceId, no stack trace).
builder.Services.AddProblemDetails();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    // "Authorize" button in the (Development-only) Swagger UI for the access token from /api/Auth/login.
    var bearer = new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Reference = new Microsoft.OpenApi.Models.OpenApiReference
        {
            Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
            Id = "Bearer"
        }
    };
    options.AddSecurityDefinition("Bearer", bearer);
    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement { [bearer] = Array.Empty<string>() });
});

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")
    ));

// ============================================================
// Services (DI)
// ============================================================
builder.Services.Configure<SmtpOptions>(
    builder.Configuration.GetSection(SmtpOptions.SectionName));
builder.Services.AddScoped<IEmailSender, EmailService>();
builder.Services.AddSingleton<VerificationService>();
builder.Services.AddSingleton<PasswordService>();
builder.Services.AddScoped<AdminService>();
builder.Services.AddDevLinkGoogle();

// ===== NEW: Social Feature =====
builder.Services.AddScoped<PostService>();

// ============================================================
// Security foundation (M2.2): CORS allowlist, log-level guard,
// deployment topology guard, migration switch, JWT validation.
// Invalid settings stop the host at start-up with a clear message.
// No endpoint requires a token yet — that is M2.7.
// ============================================================
builder.Services.AddDevLinkSecurityFoundation(builder.Configuration);
builder.Services.AddDevLinkJwtAuthentication(builder.Configuration);
builder.Services.AddDevLinkLogin();
builder.Services.AddDevLinkFiles();
builder.Services.AddDevLinkRateLimiting(builder.Configuration);

var app = builder.Build();

// Local admin provisioning: `dotnet run -- seed-admin` (see README).
if (args.Contains(AdminSeeder.Command))
{
    Environment.ExitCode = await AdminSeeder.RunFromEnvironmentAsync(app.Services);
    return;
}

app.UseDevLinkSecurityHeaders();

// Development keeps the detailed developer exception page; every other
// environment returns a sanitized ProblemDetails response.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler();
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors(CorsSetup.PolicyName);

app.UseHttpsRedirection();

app.UseRateLimiter();

app.UseAuthentication();
app.UseDevLinkSuspendedAccountGate();
app.UseAuthorization();

app.MapControllers();

app.Run();

// Exposes the entry point to the integration test project (WebApplicationFactory<Program>).
public partial class Program { }