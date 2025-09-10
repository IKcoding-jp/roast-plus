import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../models/consent_models.dart';

/// 同意管理サービス
/// 個人情報保護法およびGDPRに準拠した同意取得・管理機能を提供
class ConsentService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const String _logName = 'ConsentService';

  static void _logInfo(String message) =>
      developer.log(message, name: _logName);
  static void _logError(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) => developer.log(
    message,
    name: _logName,
    error: error,
    stackTrace: stackTrace,
  );

  static String? get _uid => _auth.currentUser?.uid;

  /// 現在のポリシーバージョン
  static const String currentPolicyVersion = '1.0';

  /// 必須同意の種類
  static const List<ConsentType> requiredConsents = [
    ConsentType.basicDataCollection,
    ConsentType.authentication,
    ConsentType.businessData,
    ConsentType.googleServices,
  ];

  /// オプション同意の種類
  static const List<ConsentType> optionalConsents = [
    ConsentType.groupFeatures,
    ConsentType.gamification,
    ConsentType.usageAnalytics,
    ConsentType.errorLogging,
    ConsentType.performanceMonitoring,
    ConsentType.marketing,
    ConsentType.notifications,
    ConsentType.admob,
    ConsentType.analytics,
  ];

  /// 同意要求の定義
  static final Map<ConsentType, ConsentRequest> consentRequests = {
    ConsentType.basicDataCollection: ConsentRequest(
      id: 'basic_data_collection',
      type: ConsentType.basicDataCollection,
      title: '基本データ収集',
      description: 'アプリの基本機能に必要な最小限のデータを収集します',
      detailedDescription:
          'ユーザーID、デバイス情報、アプリの使用状況などの基本データを収集します。これらのデータは、アプリの正常な動作とセキュリティ確保のために必要です。',
      isRequired: true,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.authentication: ConsentRequest(
      id: 'authentication',
      type: ConsentType.authentication,
      title: '認証情報',
      description: 'Googleアカウントによる認証を行います',
      detailedDescription:
          'Googleアカウントのメールアドレス、表示名、プロフィール画像を使用して認証を行います。これらの情報は、アカウント管理とセキュリティ確保のために使用されます。',
      isRequired: true,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.businessData: ConsentRequest(
      id: 'business_data',
      type: ConsentType.businessData,
      title: '業務データ',
      description: '焙煎記録、作業進捗などの業務データを保存します',
      detailedDescription:
          '焙煎記録、出勤記録、作業進捗、メモなどの業務に関連するデータを保存します。これらのデータは、業務の効率化と記録管理のために使用されます。',
      isRequired: true,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.groupFeatures: ConsentRequest(
      id: 'group_features',
      type: ConsentType.groupFeatures,
      title: 'グループ機能',
      description: 'チームでの協力作業機能を提供します',
      detailedDescription:
          'グループ作成、メンバー招待、共有データ管理などのチーム協力機能を提供します。グループ内のメンバーとデータを共有する場合があります。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.gamification: ConsentRequest(
      id: 'gamification',
      type: ConsentType.gamification,
      title: 'ゲーミフィケーション',
      description: 'バッジ、実績などのゲーム要素を提供します',
      detailedDescription:
          '作業の進捗に応じてバッジや実績を付与し、モチベーション向上を図ります。実績データは統計情報として使用される場合があります。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.usageAnalytics: ConsentRequest(
      id: 'usage_analytics',
      type: ConsentType.usageAnalytics,
      title: '利用統計',
      description: 'アプリの使用状況を分析してサービス改善に活用します',
      detailedDescription:
          '機能の使用頻度、利用時間、エラー発生状況などの統計情報を収集し、サービス改善に活用します。個人を特定できない形で処理されます。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.errorLogging: ConsentRequest(
      id: 'error_logging',
      type: ConsentType.errorLogging,
      title: 'エラーログ',
      description: 'アプリの不具合を特定・修正するためのログを収集します',
      detailedDescription:
          'アプリのクラッシュやエラー発生時のログ情報を収集し、不具合の特定と修正に使用します。個人を特定できる情報は含まれません。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.performanceMonitoring: ConsentRequest(
      id: 'performance_monitoring',
      type: ConsentType.performanceMonitoring,
      title: 'パフォーマンス監視',
      description: 'アプリの動作性能を監視して最適化します',
      detailedDescription: 'アプリの応答時間、メモリ使用量、ネットワーク通信などの性能指標を監視し、最適化に使用します。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.marketing: ConsentRequest(
      id: 'marketing',
      type: ConsentType.marketing,
      title: 'マーケティング',
      description: '新機能やサービスの案内を送信します',
      detailedDescription: '新機能のリリース、サービス改善の案内、関連情報の提供などのマーケティング情報を送信します。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.notifications: ConsentRequest(
      id: 'notifications',
      type: ConsentType.notifications,
      title: '通知',
      description: '重要な更新やリマインダーを通知します',
      detailedDescription: 'アプリの重要な更新、スケジュールのリマインダー、セキュリティアラートなどの通知を送信します。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.googleServices: ConsentRequest(
      id: 'google_services',
      type: ConsentType.googleServices,
      title: 'Googleサービス',
      description: 'Google Firebase、認証などのサービスを利用します',
      detailedDescription:
          'Google Firebase（データベース、認証、ストレージ）、Google Sign-InなどのGoogleサービスを利用します。',
      isRequired: true,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.admob: ConsentRequest(
      id: 'admob',
      type: ConsentType.admob,
      title: '広告配信',
      description: 'Google AdMobによる広告を表示します',
      detailedDescription:
          'Google AdMobを使用して広告を表示します。広告の表示には、デバイス情報や利用状況が使用される場合があります。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
    ConsentType.analytics: ConsentRequest(
      id: 'analytics',
      type: ConsentType.analytics,
      title: '分析ツール',
      description: 'Google Analyticsなどの分析ツールを使用します',
      detailedDescription:
          'Google Analyticsなどの分析ツールを使用して、アプリの利用状況を分析します。個人を特定できない形で処理されます。',
      isRequired: false,
      version: currentPolicyVersion,
      createdAt: DateTime.now(),
    ),
  };

  /// ユーザーの同意設定を取得
  static Future<ConsentSettings?> getUserConsentSettings() async {
    if (_uid == null) {
      _logError('ユーザーがログインしていません');
      return null;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('consent_settings')
          .doc('current')
          .get();

      if (!doc.exists) {
        _logInfo('同意設定が見つかりません');
        return null;
      }

      return ConsentSettings.fromMap(doc.data()!);
    } catch (e, st) {
      _logError('同意設定の取得に失敗', e, st);
      return null;
    }
  }

  /// 同意設定を保存
  static Future<void> saveConsentSettings(ConsentSettings settings) async {
    if (_uid == null) {
      _logError('ユーザーがログインしていません');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('consent_settings')
          .doc('current')
          .set(settings.toMap());

      _logInfo('同意設定を保存しました');
    } catch (e, st) {
      _logError('同意設定の保存に失敗', e, st);
      rethrow;
    }
  }

  /// 個別の同意を記録
  static Future<void> recordConsent(
    ConsentType type,
    ConsentStatus status, {
    String? version,
    Map<String, dynamic>? metadata,
  }) async {
    if (_uid == null) {
      _logError('ユーザーがログインしていません');
      return;
    }

    try {
      final record = ConsentRecord(
        id: '${_uid}_${type.id}_${DateTime.now().millisecondsSinceEpoch}',
        userId: _uid!,
        type: type,
        status: status,
        timestamp: DateTime.now(),
        version: version ?? currentPolicyVersion,
        metadata: metadata,
      );

      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('consent_records')
          .doc(record.id)
          .set(record.toMap());

      // 現在の同意設定も更新
      final currentSettings = await getUserConsentSettings();
      final updatedSettings =
          currentSettings?.updateConsent(type, status) ??
          ConsentSettings(
            userId: _uid!,
            consents: {type: status},
            lastUpdated: DateTime.now(),
            policyVersion: currentPolicyVersion,
          );

      await saveConsentSettings(updatedSettings);

      _logInfo('同意を記録しました: ${type.displayName} = ${status.displayName}');
    } catch (e, st) {
      _logError('同意の記録に失敗', e, st);
      rethrow;
    }
  }

  /// 必須同意がすべて取得されているかチェック
  static Future<bool> hasRequiredConsents() async {
    final settings = await getUserConsentSettings();
    if (settings == null) return false;

    return settings.hasRequiredConsents(requiredConsents);
  }

  /// 特定の同意が取得されているかチェック
  static Future<bool> hasConsent(ConsentType type) async {
    final settings = await getUserConsentSettings();
    if (settings == null) return false;

    return settings.hasConsent(type);
  }

  /// 同意を撤回
  static Future<void> withdrawConsent(ConsentType type) async {
    await recordConsent(type, ConsentStatus.withdrawn);
    _logInfo('同意を撤回しました: ${type.displayName}');
  }

  /// すべての同意を撤回
  static Future<void> withdrawAllConsents() async {
    if (_uid == null) {
      _logError('ユーザーがログインしていません');
      return;
    }

    try {
      final settings = await getUserConsentSettings();
      if (settings == null) return;

      for (final type in settings.consents.keys) {
        await recordConsent(type, ConsentStatus.withdrawn);
      }

      _logInfo('すべての同意を撤回しました');
    } catch (e, st) {
      _logError('同意の一括撤回に失敗', e, st);
      rethrow;
    }
  }

  /// 同意履歴を取得
  static Future<List<ConsentRecord>> getConsentHistory() async {
    if (_uid == null) {
      _logError('ユーザーがログインしていません');
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('consent_records')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ConsentRecord.fromMap(doc.data()))
          .toList();
    } catch (e, st) {
      _logError('同意履歴の取得に失敗', e, st);
      return [];
    }
  }

  /// 同意要求を取得
  static List<ConsentRequest> getConsentRequests() {
    return consentRequests.values.toList();
  }

  /// 必須同意要求を取得
  static List<ConsentRequest> getRequiredConsentRequests() {
    return requiredConsents.map((type) => consentRequests[type]!).toList();
  }

  /// オプション同意要求を取得
  static List<ConsentRequest> getOptionalConsentRequests() {
    return optionalConsents.map((type) => consentRequests[type]!).toList();
  }

  /// 同意の統計情報を取得
  static Future<Map<String, dynamic>> getConsentStatistics() async {
    if (_uid == null) {
      _logError('ユーザーがログインしていません');
      return {};
    }

    try {
      final settings = await getUserConsentSettings();
      if (settings == null) {
        return {
          'totalConsents': 0,
          'grantedConsents': 0,
          'deniedConsents': 0,
          'withdrawnConsents': 0,
          'requiredConsentsGranted': false,
        };
      }

      final totalConsents = settings.consents.length;
      final grantedConsents = settings.consents.values
          .where((status) => status == ConsentStatus.granted)
          .length;
      final deniedConsents = settings.consents.values
          .where((status) => status == ConsentStatus.denied)
          .length;
      final withdrawnConsents = settings.consents.values
          .where((status) => status == ConsentStatus.withdrawn)
          .length;
      final requiredConsentsGranted = settings.hasRequiredConsents(
        requiredConsents,
      );

      return {
        'totalConsents': totalConsents,
        'grantedConsents': grantedConsents,
        'deniedConsents': deniedConsents,
        'withdrawnConsents': withdrawnConsents,
        'requiredConsentsGranted': requiredConsentsGranted,
        'lastUpdated': settings.lastUpdated,
        'policyVersion': settings.policyVersion,
      };
    } catch (e, st) {
      _logError('同意統計の取得に失敗', e, st);
      return {};
    }
  }
}
