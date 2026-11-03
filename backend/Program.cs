using DataBase;
using Microsoft.EntityFrameworkCore;
using Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

// Unhandled errors -> RFC 7807 ProblemDetails (with traceId, no stack trace).
builder.Services.AddProblemDetails();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

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
builder.Services.AddScoped<GoogleAuthService>();

// ===== NEW: Social Feature =====
builder.Services.AddScoped<PostService>();

// ============================================================
// CORS
// ============================================================
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy
            .AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader();
    });
});

var app = builder.Build();

// Local admin provisioning: `dotnet run -- seed-admin` (see README).
if (args.Contains(AdminSeeder.Command))
{
    Environment.ExitCode = await AdminSeeder.RunFromEnvironmentAsync(app.Services);
    return;
}

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

app.UseCors("AllowAll");

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();

// Exposes the entry point to the integration test project (WebApplicationFactory<Program>).
public partial class Program { }