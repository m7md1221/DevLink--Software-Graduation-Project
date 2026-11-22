/// Cross-tab coordination for refreshing the session (M2_AUTH_DESIGN §3.5).
///
/// The refresh cookie rotates strictly: each refresh spends the cookie it sends.
/// Two tabs refreshing at the same moment would both send the same cookie and the
/// server would treat the second as reuse and end the session. Holding one
/// browser-wide lock while refreshing makes the tabs take turns.
abstract class RefreshLock {
  /// Whether the browser offers the lock (Web Locks). Without it the app can't
  /// refresh safely, so it doesn't refresh at all.
  bool get isSupported;

  /// Runs [action] while holding the lock.
  ///
  /// Throws [LockTimeoutException] if the lock isn't granted within [wait], and
  /// [LockUnsupportedException] if the browser has no lock.
  Future<T> run<T>(Future<T> Function() action, {required Duration wait});
}

class LockTimeoutException implements Exception {
  const LockTimeoutException();

  @override
  String toString() => 'LockTimeoutException';
}

class LockUnsupportedException implements Exception {
  const LockUnsupportedException();

  @override
  String toString() => 'LockUnsupportedException';
}
