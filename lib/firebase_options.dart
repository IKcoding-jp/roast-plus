import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'services/encrypted_firebase_config_service.dart';

class DefaultFirebaseOptions {
  static Future<FirebaseOptions> get currentPlatform async {
    // セキュリティ強化: 暗号化されたFirebase設定を使用
    return await EncryptedFirebaseConfigService.getFirebaseOptions();
  }
}
