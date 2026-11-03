using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;

namespace DevLink.Api.Tests.Infrastructure
{
    public record CapturedLog(string Category, LogLevel Level, string Message, string? Exception);

    // Records every log entry the host's filters let through, for "no secrets in logs" assertions.
    public class CapturingLoggerProvider : ILoggerProvider
    {
        private readonly ConcurrentQueue<CapturedLog> _entries = new();

        public IReadOnlyList<CapturedLog> Entries => _entries.ToList();

        public string AllText => string.Join("\n", Entries.Select(e => $"{e.Category} {e.Message} {e.Exception}"));

        public ILogger CreateLogger(string categoryName) => new CapturingLogger(categoryName, _entries);

        public void Dispose()
        {
        }

        private sealed class CapturingLogger : ILogger
        {
            private readonly string _category;
            private readonly ConcurrentQueue<CapturedLog> _entries;

            public CapturingLogger(string category, ConcurrentQueue<CapturedLog> entries)
            {
                _category = category;
                _entries = entries;
            }

            public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

            public bool IsEnabled(LogLevel logLevel) => true;

            public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception,
                Func<TState, Exception?, string> formatter)
            {
                _entries.Enqueue(new CapturedLog(_category, logLevel, formatter(state, exception), exception?.ToString()));
            }
        }
    }
}
