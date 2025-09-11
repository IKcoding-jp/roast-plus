import 'dart:convert';

/// 共通ユーティリティ群
class CommonUtils {
  /// 安全に String を Base64 デコードし、デコードできない場合は元の値を返す
  ///
  /// NOTE: Base64 は暗号化ではなくエンコードであるため、秘密情報の保護には
  /// 適していません。シークレットは CI/CD の Secrets 管理を使用してください。
  static String decodeBase64IfPossible(String value) {
    if (value.isEmpty) return value;
    try {
      final decoded = utf8.decode(base64.decode(value));
      if (decoded.trim().isEmpty) return value;
      return decoded;
    } catch (_) {
      return value;
    }
  }

  /// JWT のペイロードをデコードして Map を返す（簡易実装）
  /// 失敗した場合は空 Map を返す
  static Map<String, dynamic> decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      return Map<String, dynamic>.from(jsonDecode(decoded));
    } catch (_) {
      return {};
    }
  }
}
