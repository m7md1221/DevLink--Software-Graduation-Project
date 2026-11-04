using System.Collections.Concurrent;
using System.Text.RegularExpressions;
using Services;

namespace DevLink.Api.Tests.Infrastructure
{
    public record CapturedEmail(string To, string Subject, string Body);

    // Records emails instead of sending them; tests read verification codes from here.
    // Since M2.5a emails go through a background queue, readers wait briefly for them.
    public class CapturingEmailSender : IEmailSender
    {
        private static readonly TimeSpan Wait = TimeSpan.FromSeconds(10);
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

        public IReadOnlyList<CapturedEmail> To(string email) =>
            _sent.Where(m => string.Equals(m.To, email, StringComparison.OrdinalIgnoreCase)).ToList();

        private static string? CodeIn(CapturedEmail message)
        {
            var match = Regex.Match(message.Body, @"\b\d{6}\b");
            return match.Success ? match.Value : null;
        }

        public int CodeCount(string email) => To(email).Count(m => CodeIn(m) != null);

        // The latest code sent to the address; waits for the queue (and, with `after`, for a NEW code).
        public string LatestCodeFor(string email, int after = 0)
        {
            var deadline = DateTime.UtcNow + Wait;
            while (DateTime.UtcNow < deadline)
            {
                var codes = To(email).Select(CodeIn).Where(c => c != null).ToList();
                if (codes.Count > after)
                {
                    return codes[^1]!;
                }

                Thread.Sleep(25);
            }

            throw new InvalidOperationException($"No new code email captured for {email}.");
        }

        // Waits for any email matching the predicate.
        public CapturedEmail WaitFor(string email, Func<CapturedEmail, bool> predicate)
        {
            var deadline = DateTime.UtcNow + Wait;
            while (DateTime.UtcNow < deadline)
            {
                var hit = To(email).LastOrDefault(predicate);
                if (hit != null)
                {
                    return hit;
                }

                Thread.Sleep(25);
            }

            throw new InvalidOperationException($"No matching email captured for {email}.");
        }
    }
}
