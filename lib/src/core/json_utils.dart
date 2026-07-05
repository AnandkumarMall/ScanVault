import 'dart:convert';

/// Small helpers for defensive JSON parsing. The Vault is user-editable on disk
/// (PLAN.md §3 "rebuildable index"), so every read must tolerate garbage.

/// Decodes [text] into a `Map<String, dynamic>`, or returns null if it is not
/// a JSON object. Never throws.
Map<String, dynamic>? tryDecodeObject(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Decodes [text] into a `List`, or returns an empty list on any failure.
List<dynamic> tryDecodeList(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is List ? decoded : const [];
  } catch (_) {
    return const [];
  }
}

/// Pretty-prints [value] as JSON (2-space indent) for human-readable files.
String encodePretty(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// Reads a String field with a fallback.
String jsonString(Map<String, dynamic> json, String key, {String or = ''}) {
  final v = json[key];
  return v is String ? v : or;
}

/// Reads an int field with a fallback (accepts numeric strings too).
int jsonInt(Map<String, dynamic> json, String key, {int or = 0}) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? or;
  return or;
}

/// Reads a double field with a fallback.
double jsonDouble(Map<String, dynamic> json, String key, {double or = 0}) {
  final v = json[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? or;
  return or;
}
