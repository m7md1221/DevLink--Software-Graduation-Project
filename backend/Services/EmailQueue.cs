using System.Threading.Channels;

namespace Services
{
    public sealed record QueuedEmail(string To, string Subject, string Body);

    // ============================================================
    // Background email queue (M2_AUTH_DESIGN §6.2 "Timing"). Requests only
    // enqueue, so the response time of send-code / send-reset-code does not
    // depend on whether an email is actually sent (no enumeration by timing).
    // In Development without SMTP, IEmailSender writes to the console.
    //
    // KI-67 (M2.11b): Wait mode, so TryWrite returns false at once when the
    // queue is full (it never waits; DropWrite returned true for dropped mail).
    // Enqueue reports the truth and logs the drop with the subject only (the
    // subjects are fixed texts; never the address or body).
    // ============================================================
    public class EmailQueue
    {
        public const int DefaultCapacity = 1_000;

        private readonly Channel<QueuedEmail> _channel;
        private readonly ILogger? _logger;

        public EmailQueue(int capacity = DefaultCapacity, ILogger? logger = null)
        {
            _channel = Channel.CreateBounded<QueuedEmail>(
                new BoundedChannelOptions(capacity) { FullMode = BoundedChannelFullMode.Wait, SingleReader = true });
            _logger = logger;
        }

        // False when the queue is full: the email was not queued and will not be sent.
        public bool Enqueue(string to, string subject, string body)
        {
            if (_channel.Writer.TryWrite(new QueuedEmail(to, subject, body)))
            {
                return true;
            }

            _logger?.LogWarning("Email.QueueFull subject {Subject}", subject);
            return false;
        }

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
