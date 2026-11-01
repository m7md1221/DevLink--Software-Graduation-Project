import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    try {
      // 1) تأكد أن خدمة الموقع مفعّلة
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Location service is disabled');
        return null;
      }

      // 2) صلاحيات الموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permission denied');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Location permission denied forever');
        return null;
      }

      // 3) نجيب الموقع الحالي
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      print('❌ LocationService error: $e');
      return null;
    }
  }
}