using System.Threading.Channels;

namespace Services
{
    public sealed record QueuedEmail(string To, string Subject, string Body);

    // ============================================================
    // Background email queue (M2_AUTH_DESIGN §6.2 "Timing"). Requests only
    // enqueue, so the response time of send-code / send-reset-code does not
    // depend on whether an email is actually sent (no enumeration by timing).
    // In Development without SMTP, IEmailSender writes to the console.
    // ============================================================
    public class EmailQueue
    {
        private readonly Channel<QueuedEmail> _channel = Channel.CreateBounded<QueuedEmail>(
            new BoundedChannelOptions(1_000) { FullMode = BoundedChannelFullMode.DropWrite, SingleReader = true });

        public bool Enqueue(string to, string subject, string body) =>
            _channel.Writer.TryWrite(new QueuedEmail(to, subject, body));

        public ChannelReader<QueuedEmail> Reader => _channel.Reader;
    }

    public class EmailQueueService : BackgroundService
    {
        private readonly EmailQueue _queue;
        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger _logger;

        public EmailQueueService(EmailQueue queue, IServiceScopeFactory scopes, ILoggerFactory loggers)
        {
            _queue = queue;
            _scopes = scopes;
            _logger = loggers.CreateLogger("DevLink.Email");
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try
            {
                await foreach (var email in _queue.Reader.ReadAllAsync(stoppingToken))
                {
                    try
                    {
                        using var scope = _scopes.CreateScope();
                        var sender = scope.ServiceProvider.GetRequiredService<IEmailSender>();
                        if (!await sender.SendEmailAsync(email.To, email.Subject, email.Body))
                        {
                            _logger.LogError("Email.SendFailed");
                        }
                    }
                    catch (Exception ex)
                    {
                        // Never the address or body: they can hold codes and personal data.
                        _logger.LogError("Email.SendFailed {FailureType}", ex.GetType().Name);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // Host shutting down.
            }
        }
    }
}
