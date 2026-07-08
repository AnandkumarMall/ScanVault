import 'dart:convert';

Map<String, dynamic>? tryDecodeObject(String text) {
  try { return jsonDecode(text) as Map<String, dynamic>?; } catch (_) { return null; }
}

List<dynamic> tryDecodeList(String text) {
  try { return jsonDecode(text) as List<dynamic>; } catch (_) { return const []; }
}

String encodePretty(Object? value) => const JsonEncoder.withIndent('  ').convert(value);
String jsonString(Map<String, dynamic> json, String key, {String or = ''}) => json[key] as String? ?? or;
int jsonInt(Map<String, dynamic> json, String key, {int or = 0}) => int.tryParse(json[key]?.toString() ?? '') ?? or;
double jsonDouble(Map<String, dynamic> json, String key, {double or = 0}) => double.tryParse(json[key]?.toString() ?? '') ?? or;
