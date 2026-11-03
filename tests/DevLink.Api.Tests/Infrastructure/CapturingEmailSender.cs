using System.Collections.Concurrent;
using System.Text.RegularExpressions;
using Services;

namespace DevLink.Api.Tests.Infrastructure
{
    public record CapturedEmail(string To, string Subject, string Body);

    // Records emails instead of sending them; tests read verification codes from here.
    public class CapturingEmailSender : IEmailSender
    {
        private readonly ConcurrentQueue<CapturedEmail> _sent = new();

        public IReadOnlyCollection<CapturedEmail> Sent => _sent.ToArray();

        public bool SendEmail(string toEmail, string subject, string body, string senderName = "DevLink")
        {
            _sent.Enqueue(new CapturedEmail(toEmail, subject, body));
            return true;
        }

        public Task<bool> SendEmailAsync(string toEmail, string subject, string body, string senderName = "DevLink")
        {
            return Task.FromResult(SendEmail(toEmail, subject, body, senderName));
        }

        public string LatestCodeFor(string email)
        {
            var message = _sent.LastOrDefault(m =>
                string.Equals(m.To, email, StringComparison.OrdinalIgnoreCase))
                ?? throw new InvalidOperationException($"No email captured for {email}.");

            return Regex.Match(message.Body, @"\b\d{6}\b").Value;
        }
    }
}
