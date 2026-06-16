import 'dart:convert';

/// JSON → UTF8 → Base64 (공백·줄바꿈 허용)
class IsleBackupCodec {
  IsleBackupCodec._();

  static const currentSchema = 1;
  static const minSupportedSchema = 1;

  static String encode(Map<String, dynamic> pack) {
    final withMeta = {
      ...pack,
      'backup_code_schema': currentSchema,
      if (!pack.containsKey('export_schema')) 'export_schema': pack['export_schema'] ?? 9,
    };
    return base64Encode(utf8.encode(jsonEncode(withMeta)));
  }

  static Map<String, dynamic> decode(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      throw const FormatException('백업 코드가 비어 있어요');
    }
    final bytes = base64Decode(normalized);
    final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final schema = (map['backup_code_schema'] as num?)?.toInt() ?? 1;
    if (schema > currentSchema) {
      throw FormatException('백업 코드 버전($schema)이 앱보다 새로워요. 앱을 업데이트해 주세요.');
    }
    if (schema < minSupportedSchema) {
      throw FormatException('지원하지 않는 백업 코드 버전이에요');
    }
    return map;
  }
}
