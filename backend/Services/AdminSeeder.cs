using DataBase;
using Microsoft.EntityFrameworkCore;

namespace Services
{
    public record AdminSeedResult(bool Success, string Message);

    // ============================================================
    // Local admin provisioning:
    //   set DEVLINK_ADMIN_EMAIL / DEVLINK_ADMIN_PASSWORD, then
    //   dotnet run -- seed-admin
    // Idempotent: an existing admin with that email is left unchanged.
    // ============================================================
    public static class AdminSeeder
    {
        public const string Command = "seed-admin";

        public static async Task<int> RunFromEnvironmentAsync(IServiceProvider services)
        {
            var email = Environment.GetEnvironmentVariable("DEVLINK_ADMIN_EMAIL");
            var password = Environment.GetEnvironmentVariable("DEVLINK_ADMIN_PASSWORD");

            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
            {
                Console.Error.WriteLine(
                    "seed-admin: set DEVLINK_ADMIN_EMAIL and DEVLINK_ADMIN_PASSWORD environment variables first.");
                return 1;
            }

            using var scope = services.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var passwordService = scope.ServiceProvider.GetRequiredService<PasswordService>();

            Console.WriteLine(
                $"seed-admin: target database '{context.Database.GetDbConnection().Database}'");

            var result = await SeedAsync(context, passwordService, email, password);

            if (result.Success)
            {
                Console.WriteLine($"seed-admin: {result.Message}");
                return 0;
            }

            Console.Error.WriteLine($"seed-admin: {result.Message}");
            return 1;
        }

        public static async Task<AdminSeedResult> SeedAsync(
            AppDbContext context,
            PasswordService passwordService,
            string email,
            string password)
        {
            email = email.Trim().ToLower();

            var passwordError = passwordService.ValidatePolicy(password);

            if (passwordError != null)
            {
                return new AdminSeedResult(false, passwordError);
            }

            var existing = await context.Users
                .FirstOrDefaultAsync(u => u.Email == email);

            if (existing != null)
            {
                return existing.UserType == "Admin"
                    ? new AdminSeedResult(true, "Admin already exists; nothing changed.")
                    : new AdminSeedResult(false, "A non-admin account already uses this email; refusing to change it.");
            }

            var admin = new User
            {
                Email = email,
                UserType = "Admin"
            };

            admin.PasswordHash = passwordService.Hash(admin, password);

            context.Users.Add(admin);
            await context.SaveChangesAsync();

            return new AdminSeedResult(true, "Admin account created.");
        }
    }
}
