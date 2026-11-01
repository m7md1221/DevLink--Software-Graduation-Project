import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class LocationService {
  static Future<({double lat, double lon})?> getCurrentPosition() async {
    try {
      final completer = Completer<({double lat, double lon})?>();

      web.window.navigator.geolocation.getCurrentPosition(
        (web.GeolocationPosition pos) {
          completer.complete((
            lat: pos.coords.latitude,
            lon: pos.coords.longitude,
          ));
        }.toJS,
        (web.GeolocationPositionError err) {
          completer.complete(null);
        }.toJS,
      );

      return await completer.future;
    } catch (e) {
      return null;
    }
  }
}