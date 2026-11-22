using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace Services
{
    public interface IEmailSender
    {
        bool SendEmail(
            string toEmail,
            string subject,
            string body,
            string senderName = "DevLink");

        Task<bool> SendEmailAsync(
            string toEmail,
            string subject,
            string body,
            string senderName = "DevLink");
    }

    // ============================================================
    // SMTP settings come from configuration (user-secrets locally,
    // environment variables in deployment). Never hardcode them.
    // ============================================================
    public class SmtpOptions
    {
        public const string SectionName = "Smtp";

        public string Host { get; set; } = "smtp.gmail.com";

        public int Port { get; set; } = 587;

        public string SenderEmail { get; set; } = string.Empty;

        public string Password { get; set; } = string.Empty;

        public bool IsConfigured =>
            !string.IsNullOrWhiteSpace(Host) &&
            !string.IsNullOrWhiteSpace(SenderEmail) &&
            !string.IsNullOrWhiteSpace(Password);
    }

    public class EmailService : IEmailSender
    {
        private readonly SmtpOptions _options;
        private readonly IHostEnvironment _environment;
        private readonly ILogger<EmailService> _logger;

        public EmailService(
            IOptions<SmtpOptions> options,
            IHostEnvironment environment,
            ILogger<EmailService> logger)
        {
            _options = options.Value;
            _environment = environment;
            _logger = logger;
        }

        public bool SendEmail(
            string toEmail,
            string subject,
            string body,
            string senderName = "DevLink")
        {
            if (!_options.IsConfigured)
            {
                if (_environment.IsDevelopment())
                {
                    // Development sink: no SMTP credential configured, so log
                    // the email locally instead of sending it.
                    _logger.LogWarning(
                        "SMTP not configured - email NOT sent (Development sink).\nTo: {To}\nSubject: {Subject}\n{Body}",
                        toEmail,
                        subject,
                        body);

                    return true;
                }

                _logger.LogError(
                    "SMTP not configured - email with subject '{Subject}' was not sent.",
                    subject);

                return false;
            }

            try
            {
                var message = new MimeMessage();

                message.From.Add(
                    new MailboxAddress(senderName, _options.SenderEmail));

                message.To.Add(
                    new MailboxAddress("", toEmail));

                message.Subject = subject;

                message.Body = new TextPart("plain")
                {
                    Text = body
                };

                using (var client = new SmtpClient())
                {
                    client.Connect(
                        _options.Host,
                        _options.Port,
                        SecureSocketOptions.StartTls);

                    client.Authenticate(
                        _options.SenderEmail,
                        _options.Password);

                    client.Send(message);

                    client.Disconnect(true);
                }

                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    "Email sending failed: {Error}",
                    ex.Message);

                return false;
            }
        }

        public async Task<bool> SendEmailAsync(
            string toEmail,
            string subject,
            string body,
            string senderName = "DevLink")
        {
            return await Task.Run(() => SendEmail(toEmail, subject, body, senderName));
        }
    }
}
