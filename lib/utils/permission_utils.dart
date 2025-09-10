import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_models.dart';
import '../services/group_firestore_service.dart';
import 'dart:async';
import 'dart:developer' as developer;

class PermissionUtils {
  static const String _logName = 'PermissionUtils';
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

  /// ユーザーのロールを取得
  static Future<GroupRole?> getCurrentUserRole(String groupId) async {
    try {
      _logInfo('ユーザーロール取得開始 - グループID: $groupId');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logInfo('ユーザーが認証されていません');
        return null;
      }

      _logInfo('現在のユーザーID: ${user.uid}');

      final group = await GroupFirestoreService.getGroup(groupId);
      if (group == null) {
        _logInfo('グループが見つかりません - グループID: $groupId');
        return null;
      }

      _logInfo('グループメンバー数: ${group.members.length}');
      _logInfo(
        'グループメンバー: ${group.members.map((m) => '${m.uid}:${m.role.name}').toList()}',
      );

      final role = group.getMemberRole(user.uid);
      _logInfo('取得したロール: $role');

      return role;
    } catch (e, st) {
      _logError('ユーザーロール取得エラー', e, st);
      return null;
    }
  }

  /// 指定されたデータタイプの編集権限をチェック
  static Future<bool> canEditDataType({
    required String groupId,
    required String dataType,
  }) async {
    try {
      _logInfo('編集権限チェック開始 - グループID: $groupId, データタイプ: $dataType');

      final userRole = await getCurrentUserRole(groupId);
      _logInfo('ユーザーロール: $userRole');

      if (userRole == null) {
        _logInfo('ユーザーロールが取得できませんでした');
        return false;
      }

      final settings = await GroupFirestoreService.getGroupSettings(groupId);
      _logInfo('グループ設定: ${settings?.dataPermissions}');

      if (settings == null) {
        _logInfo('グループ設定が取得できませんでした');
        return false;
      }

      final canEdit = settings.canEditDataType(dataType, userRole);
      _logInfo('編集権限結果: $canEdit');

      return canEdit;
    } catch (e, st) {
      _logError('編集権限チェックエラー', e, st);
      return false;
    }
  }

  /// 指定されたデータタイプの削除権限をチェック
  static Future<bool> canDeleteDataType({
    required String groupId,
    required String dataType,
  }) async {
    // 削除権限は編集権限と同じ
    return canEditDataType(groupId: groupId, dataType: dataType);
  }

  /// 指定されたデータタイプの作成権限をチェック
  static Future<bool> canCreateDataType({
    required String groupId,
    required String dataType,
  }) async {
    // 作成権限は編集権限と同じ
    return canEditDataType(groupId: groupId, dataType: dataType);
  }

  /// 指定されたデータタイプの権限をリアルタイム監視
  static Stream<bool> watchDataTypePermission({
    required String groupId,
    required String dataType,
  }) {
    return GroupFirestoreService.watchGroupSettings(groupId).asyncMap((
      settings,
    ) async {
      if (settings == null) return false;

      final userRole = await getCurrentUserRole(groupId);
      if (userRole == null) return false;

      return settings.canEditDataType(dataType, userRole);
    });
  }

  /// 権限変更を監視するStreamSubscriptionを返す
  static StreamSubscription<bool> listenForPermissionChange({
    required String groupId,
    required String dataType,
    required Function(bool) onPermissionChange,
  }) {
    return watchDataTypePermission(
      groupId: groupId,
      dataType: dataType,
    ).listen(onPermissionChange);
  }

  /// 権限エラーメッセージを取得
  static String getPermissionErrorMessage(String dataType) {
    return 'この操作は許可されていません ($dataType)';
  }

  /// 権限レベルを日本語で取得
  static String getAccessLevelDisplayName(AccessLevel accessLevel) {
    switch (accessLevel) {
      case AccessLevel.adminOnly:
        return '管理者のみ';
      case AccessLevel.adminLeader:
        return '管理者・リーダー';
      case AccessLevel.allMembers:
        return '全メンバー';
    }
  }

  /// データタイプの日本語名を取得
  static String getDataTypeDisplayName(String dataType) {
    switch (dataType) {
      case 'roastRecordInput':
        return '焙煎記録入力';
      case 'roastRecords':
        return '焙煎記録一覧';
      case 'dripCounter':
        return 'ドリップパックカウンター';
      case 'assignment_board':
        return '担当表';
      case 'todaySchedule':
        return '本日のスケジュール';
      case 'roast_schedule':
        return 'ローストスケジュール';
      case 'taskStatus':
        return '作業状況記録';
      case 'cuppingNotes':
        return '試飲感想記録';
      case 'circleStamps':
        return '丸シール設定';
      default:
        return dataType;
    }
  }
}
