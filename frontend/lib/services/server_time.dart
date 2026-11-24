/// The API stores UTC and often sends times without a zone suffix; read them as UTC
/// and convert to the viewer's local time.
DateTime? parseServerTime(String? value) {
  if (value == null || value.isEmpty) return null;
  final hasZone = value.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(value);
  return DateTime.tryParse(hasZone ? value : '${value}Z')?.toLocal();
}
