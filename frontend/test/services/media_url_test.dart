// M2.12-lite (F14–F15): images use the signed paths the API returns.
import 'package:devlink/api_config.dart';
import 'package:devlink/services/media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a signed path from the API gets the API address and keeps its signature', () {
    const path = '/api/Posts/user/5/avatar?exp=1234&sig=abc';
    expect(MediaUrl.resolve(path), '${ApiConfig.baseUrl}$path');
  });

  test('an absolute URL is used as it is', () {
    expect(MediaUrl.resolve('https://example.test/a.png'), 'https://example.test/a.png');
  });

  test('no URL gives an empty string, so the placeholder shows', () {
    expect(MediaUrl.resolve(null), '');
    expect(MediaUrl.resolve(''), '');
  });
}
