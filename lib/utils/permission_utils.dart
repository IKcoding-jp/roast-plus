import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_models.dart';
import '../services/group_firestore_service.dart';
import 'dart:async';

class PermissionUtils {
  /// ユーザーのロールを取得
  static Future<GroupRole?> getCurrentUserRole(String groupId) async {
    try {
      print('PermissionUtils: ユーザーロール取得開始 - グループID: $groupId');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('PermissionUtils: ユーザーが認証されていません');
        return null;
      }

      print('PermissionUtils: 現在のユーザーID: ${user.uid}');

      final group = await GroupFirestoreService.getGroup(groupId);
      if (group == null) {
        print('PermissionUtils: グループが見つかりません - グループID: $groupId');
        return null;
      }

      print('PermissionUtils: グループメンバー数: ${group.members.length}');
      print(
        'PermissionUtils: グループメンバー: ${group.members.map((m) => '${m.uid}:${m.role.name}').toList()}',
      );

      final role = group.getMemberRole(user.uid);
      print('PermissionUtils: 取得したロール: $role');

      return role;
    } catch (e) {
      print('PermissionUtils: ユーザーロール取得エラー: $e');
      return null;
    }
  }

  /// 指定されたデータタイプの編集権限をチェック
  static Future<bool> canEditDataType({
    required String groupId,
    required String dataType,
  }) async {
    try {
      print(
        'PermissionUtils: 編集権限チェック開始 - グループID: $groupId, データタイプ: $dataType',
      );

      final userRole = await getCurrentUserRole(groupId);
      print('PermissionUtils: ユーザーロール: $userRole');

      if (userRole == null) {
        print('PermissionUtils: ユーザーロールが取得できませんでした');
        return false;
      }

      final settings = await GroupFirestoreService.getGroupSettings(groupId);
      print('PermissionUtils: グループ設定: ${settings?.dataPermissions}');

      if (settings == null) {
        print('PermissionUtils: グループ設定が取得できませんでした');
        return false;
      }

      final canEdit = settings.canEditDataType(dataType, userRole);
      print('PermissionUtils: 編集権限結果: $canEdit');

      return canEdit;
    } catch (e) {
      print('PermissionUtils: 編集権限チェックエラー: $e');
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
