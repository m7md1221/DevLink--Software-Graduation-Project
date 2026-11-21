import 'refresh_lock_base.dart';

RefreshLock createRefreshLock() => SingleProcessRefreshLock();

/// Outside the browser there is one app instance, so the single-flight refresh in
/// `AuthHttp` is enough and the action runs directly.
class SingleProcessRefreshLock implements RefreshLock {
  @override
  bool get isSupported => true;

  @override
  Future<T> run<T>(Future<T> Function() action, {required Duration wait}) => action();
}
