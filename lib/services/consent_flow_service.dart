import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../models/consent_models.dart';
import '../services/consent_service.dart';
import '../widgets/consent_dialog.dart';

/// 同意取得フロー管理サービス
/// 初回ログイン時やポリシー更新時の同意取得を管理
class ConsentFlowService {
  static const String _logName = 'ConsentFlowService';

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

  /// 初回ログイン時の同意取得フロー
  static Future<bool> handleFirstLoginConsent(BuildContext context) async {
    _logInfo('初回ログイン時の同意取得フローを開始');

    try {
      // 必須同意を取得
      final requiredConsentGranted = await _requestRequiredConsent(context);
      if (!requiredConsentGranted) {
        _logInfo('必須同意が拒否されました');
        return false;
      }

      // オプション同意を取得（非同期で実行）
      if (context.mounted) {
        _requestOptionalConsent(context);
      }

      _logInfo('初回ログイン時の同意取得フローが完了');
      return true;
    } catch (e, st) {
      _logError('初回ログイン時の同意取得フローでエラー', e, st);
      return false;
    }
  }

  /// 必須同意を要求
  static Future<bool> _requestRequiredConsent(BuildContext context) async {
    _logInfo('必須同意を要求');

    final requiredRequests = ConsentService.getRequiredConsentRequests();

    bool consentGranted = false;

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ConsentDialog(
          consentRequests: requiredRequests,
          isRequired: true,
          onComplete: () {
            consentGranted = true;
            _logInfo('必須同意が取得されました');
          },
          onCancel: () {
            consentGranted = false;
            _logInfo('必須同意が拒否されました');
          },
        ),
      );
    }

    return consentGranted;
  }

  /// オプション同意を要求（非同期）
  static Future<void> _requestOptionalConsent(BuildContext context) async {
    _logInfo('オプション同意を要求');

    // 少し遅延してから表示（UX向上のため）
    await Future.delayed(const Duration(seconds: 1));

    if (!context.mounted) return;

    final optionalRequests = ConsentService.getOptionalConsentRequests();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ConsentDialog(
        consentRequests: optionalRequests,
        isRequired: false,
        onComplete: () {
          _logInfo('オプション同意が取得されました');
        },
        onCancel: () {
          _logInfo('オプション同意が拒否されました');
        },
      ),
    );
  }

  /// ポリシー更新時の同意取得フロー
  static Future<bool> handlePolicyUpdateConsent(
    BuildContext context,
    String newPolicyVersion,
  ) async {
    _logInfo('ポリシー更新時の同意取得フローを開始: $newPolicyVersion');

    try {
      // 更新された同意要求を取得
      final updatedRequests = _getUpdatedConsentRequests(newPolicyVersion);

      if (updatedRequests.isEmpty) {
        _logInfo('更新された同意要求がありません');
        return true;
      }

      // 更新された同意を要求
      final consentGranted = await _requestUpdatedConsent(
        context,
        updatedRequests,
      );

      if (consentGranted) {
        _logInfo('ポリシー更新時の同意取得が完了');
        return true;
      } else {
        _logInfo('ポリシー更新時の同意が拒否されました');
        return false;
      }
    } catch (e, st) {
      _logError('ポリシー更新時の同意取得フローでエラー', e, st);
      return false;
    }
  }

  /// 更新された同意要求を取得
  static List<ConsentRequest> _getUpdatedConsentRequests(
    String newPolicyVersion,
  ) {
    // 実際の実装では、新しいポリシーバージョンに基づいて
    // 更新された同意要求を特定する
    final allRequests = ConsentService.getConsentRequests();

    // 例: 新しいポリシーバージョンで追加された同意要求を返す
    return allRequests
        .where((request) => request.version == newPolicyVersion)
        .toList();
  }

  /// 更新された同意を要求
  static Future<bool> _requestUpdatedConsent(
    BuildContext context,
    List<ConsentRequest> updatedRequests,
  ) async {
    bool consentGranted = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConsentDialog(
        consentRequests: updatedRequests,
        isRequired: true,
        onComplete: () {
          consentGranted = true;
          _logInfo('更新された同意が取得されました');
        },
        onCancel: () {
          consentGranted = false;
          _logInfo('更新された同意が拒否されました');
        },
      ),
    );

    return consentGranted;
  }

  /// 同意の再取得フロー
  static Future<void> handleConsentReRequest(BuildContext context) async {
    _logInfo('同意の再取得フローを開始');

    try {
      // 現在の同意状況を確認
      final hasRequiredConsents = await ConsentService.hasRequiredConsents();

      if (!hasRequiredConsents) {
        // 必須同意が不足している場合は再取得
        if (context.mounted) {
          await _requestRequiredConsent(context);
        }
      }

      // オプション同意の再取得
      if (context.mounted) {
        await _requestOptionalConsent(context);
      }

      _logInfo('同意の再取得フローが完了');
    } catch (e, st) {
      _logError('同意の再取得フローでエラー', e, st);
    }
  }

  /// 特定の機能の同意を要求
  static Future<bool> requestFeatureConsent(
    BuildContext context,
    ConsentType featureType,
  ) async {
    _logInfo('機能の同意を要求: ${featureType.displayName}');

    try {
      // 既に同意が取得されているかチェック
      final hasConsent = await ConsentService.hasConsent(featureType);
      if (hasConsent) {
        _logInfo('既に同意が取得されています: ${featureType.displayName}');
        return true;
      }

      // 該当する同意要求を取得
      final request = ConsentService.consentRequests[featureType];
      if (request == null) {
        _logError('同意要求が見つかりません: ${featureType.displayName}');
        return false;
      }

      // 同意を要求
      bool consentGranted = false;

      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: !request.isRequired,
          builder: (context) => ConsentDialog(
            consentRequests: [request],
            isRequired: request.isRequired,
            onComplete: () {
              consentGranted = true;
              _logInfo('機能の同意が取得されました: ${featureType.displayName}');
            },
            onCancel: () {
              consentGranted = false;
              _logInfo('機能の同意が拒否されました: ${featureType.displayName}');
            },
          ),
        );
      }

      return consentGranted;
    } catch (e, st) {
      _logError('機能の同意要求でエラー', e, st);
      return false;
    }
  }

  /// 同意状況の確認
  static Future<ConsentStatus> checkConsentStatus(ConsentType type) async {
    try {
      final hasConsent = await ConsentService.hasConsent(type);
      return hasConsent ? ConsentStatus.granted : ConsentStatus.denied;
    } catch (e, st) {
      _logError('同意状況の確認でエラー', e, st);
      return ConsentStatus.notRequested;
    }
  }

  /// 同意が必要な機能の使用前チェック
  static Future<bool> checkFeatureAccess(ConsentType type) async {
    try {
      final hasConsent = await ConsentService.hasConsent(type);
      if (!hasConsent) {
        _logInfo('同意が必要な機能へのアクセスが拒否されました: ${type.displayName}');
      }
      return hasConsent;
    } catch (e, st) {
      _logError('機能アクセスチェックでエラー', e, st);
      return false;
    }
  }

  /// 同意取得の統計情報を取得
  static Future<Map<String, dynamic>> getConsentFlowStatistics() async {
    try {
      final statistics = await ConsentService.getConsentStatistics();
      final history = await ConsentService.getConsentHistory();

      return {
        ...statistics,
        'totalConsentRecords': history.length,
        'lastConsentDate': history.isNotEmpty ? history.first.timestamp : null,
        'consentFlowVersion': '1.0',
      };
    } catch (e, st) {
      _logError('同意フロー統計の取得でエラー', e, st);
      return {};
    }
  }
}
