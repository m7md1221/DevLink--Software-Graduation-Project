import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5133';
    }

    return 'http://10.0.2.2:5133';
  }
}