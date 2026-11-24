import 'package:devlink/services/server_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a time without a zone is read as UTC and shown in local time', () {
    final t = parseServerTime('2026-11-24T16:31:00')!;
    expect(t.isUtc, isFalse);
    expect(t.toUtc(), DateTime.utc(2026, 11, 24, 16, 31));
  });

  test('a time with a zone keeps its instant', () {
    expect(parseServerTime('2026-11-24T16:31:00Z')!.toUtc(), DateTime.utc(2026, 11, 24, 16, 31));
    expect(parseServerTime('2026-11-24T18:31:00+02:00')!.toUtc(), DateTime.utc(2026, 11, 24, 16, 31));
  });

  test('empty or invalid input gives null', () {
    expect(parseServerTime(null), isNull);
    expect(parseServerTime(''), isNull);
    expect(parseServerTime('not a date'), isNull);
  });
}
