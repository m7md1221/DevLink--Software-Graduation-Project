import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'refresh_lock_base.dart';

RefreshLock createRefreshLock() => WebRefreshLock();

/// `navigator.locks` (Web Locks API): one exclusive lock shared by every tab of
/// this origin.
class WebRefreshLock implements RefreshLock {
  static const String lockName = 'devlink-refresh';

  @override
  bool get isSupported => web.window.navigator.has('locks');

  @override
  Future<T> run<T>(Future<T> Function() action, {required Duration wait}) {
    if (!isSupported) {
      return Future<T>.error(const LockUnsupportedException());
    }

    final result = Completer<T>();
    var granted = false;

    JSPromise<JSAny?> onGranted(web.Lock? lock) {
      granted = true;

      Future<JSAny?> body() async {
        try {
          result.complete(await action());
        } catch (error, stack) {
          result.completeError(error, stack);
        }
        return null;
      }

      // The lock is released when this promise settles.
      return body().toJS;
    }

    // The signal only cancels a request that is still waiting; once granted, it has no effect.
    final options = web.LockOptions(
      mode: 'exclusive',
      signal: web.AbortSignal.timeout(wait.inMilliseconds),
    );

    web.window.navigator.locks
        .request(lockName, options, onGranted.toJS)
        .toDart
        .then<void>((_) {}, onError: (Object error) {
      if (!result.isCompleted) {
        result.completeError(granted ? error : const LockTimeoutException());
      }
    });

    return result.future;
  }
}
