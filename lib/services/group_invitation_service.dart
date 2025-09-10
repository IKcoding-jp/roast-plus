import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:developer' as developer;

/// グループ招待コード・QRコード管理サービス
class GroupInvitationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _userDisplayName =>
      _auth.currentUser?.displayName ?? '匿名ユーザー';
      
  static String? get _photoUrl {
    final photoURL = _auth.currentUser?.photoURL;
    developer.log(
      'GroupInvitationService: _photoUrl取得 - $photoURL',
      name: 'GroupInvitationService',
    );
    
    // プロフィール画像URLが有効かチェック
    if (photoURL != null && photoURL.isNotEmpty) {
      developer.log(
        'GroupInvitationService: 有効なプロフィール画像URLを取得 - $photoURL',
        name: 'GroupInvitationService',
      );
      return photoURL;
    } else {
      developer.log(
        'GroupInvitationService: プロフィール画像URLが無効または空 - $photoURL',
        name: 'GroupInvitationService',
      );
      return null;
    }
  }

  /// 招待コードを生成
  static String generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      8,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// グループの招待コードを作成・更新
  static Future<String> createGroupInvitationCode(
    String groupId, {
    Duration? expiresIn,
    int? maxUses,
  }) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final invitationCode = generateInvitationCode();
      final expiresAt = expiresIn != null
          ? DateTime.now().add(expiresIn)
          : DateTime.now().add(Duration(days: 30)); // デフォルト30日間有効

      await _firestore.collection('group_invitations').doc(invitationCode).set({
        'groupId': groupId,
        'invitationCode': invitationCode,
        'createdBy': _uid,
        'createdByName': _userDisplayName,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'maxUses': maxUses,
        'currentUses': 0,
        'isActive': true,
        'usedBy': [], // 使用したユーザーのリスト
      });

      // グループドキュメントにも招待コードを記録
      await _firestore.collection('groups').doc(groupId).update({
        'activeInvitationCode': invitationCode,
        'invitationCodeUpdatedAt': FieldValue.serverTimestamp(),
      });

      developer.log(
        '招待コード「$invitationCode」を作成しました（グループ: $groupId）',
        name: 'GroupInvitationService',
      );
      return invitationCode;
    } catch (e, s) {
      developer.log(
        '招待コード作成エラー',
        name: 'GroupInvitationService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      rethrow;
    }
  }

  /// 招待コードの詳細情報を取得
  static Future<Map<String, dynamic>?> getInvitationInfo(
    String invitationCode,
  ) async {
    try {
      final doc = await _firestore
          .collection('group_invitations')
          .doc(invitationCode)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;

      // 有効期限チェック
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final isExpired = DateTime.now().isAfter(expiresAt);

      // 使用回数チェック
      final maxUses = data['maxUses'] as int?;
      final currentUses = data['currentUses'] as int? ?? 0;
      final isMaxUsesReached = maxUses != null && currentUses >= maxUses;

      final isActive = data['isActive'] as bool? ?? false;

      return {
        ...data,
        'isExpired': isExpired,
        'isMaxUsesReached': isMaxUsesReached,
        'isValid': isActive && !isExpired && !isMaxUsesReached,
      };
    } catch (e, s) {
      developer.log(
        '招待コード情報取得エラー',
        name: 'GroupInvitationService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      return null;
    }
  }

  /// 招待コードを使用してグループに参加
  static Future<bool> joinGroupWithInvitationCode(String invitationCode) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      // 招待コード情報を取得
      final invitationInfo = await getInvitationInfo(invitationCode);

      if (invitationInfo == null) {
        throw Exception('招待コードが見つかりません');
      }

      if (!invitationInfo['isValid']) {
        if (invitationInfo['isExpired']) {
          throw Exception('招待コードの有効期限が切れています');
        }
        if (invitationInfo['isMaxUsesReached']) {
          throw Exception('招待コードの使用回数が上限に達しています');
        }
        if (!invitationInfo['isActive']) {
          throw Exception('招待コードが無効です');
        }
        throw Exception('招待コードが使用できません');
      }

      final groupId = invitationInfo['groupId'] as String;
      final usedBy = List<String>.from(invitationInfo['usedBy'] ?? []);

      // 既に使用済みかチェック
      if (usedBy.contains(_uid)) {
        throw Exception('この招待コードは既に使用済みです');
      }

      // 招待コードの使用履歴を先に更新
      await _firestore
          .collection('group_invitations')
          .doc(invitationCode)
          .update({
            'currentUses': FieldValue.increment(1),
            'usedBy': FieldValue.arrayUnion([_uid]),
            'lastUsedAt': FieldValue.serverTimestamp(),
            'lastUsedBy': _uid,
            'lastUsedByName': _userDisplayName,
          });

      // グループに参加
      await _addUserToGroup(groupId);

      developer.log(
        '招待コード「$invitationCode」を使用してグループに参加しました',
        name: 'GroupInvitationService',
      );
      return true;
    } catch (e, s) {
      developer.log(
        '招待コード使用エラー',
        name: 'GroupInvitationService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      rethrow;
    }
  }

  /// ユーザーをグループに追加
  static Future<void> _addUserToGroup(String groupId) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      // グループの現在の情報を取得
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();

      if (!groupDoc.exists) {
        throw Exception('グループが見つかりません');
      }

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      // 既にメンバーかチェック
      final isAlreadyMember = members.any((member) => member['uid'] == _uid);
      if (isAlreadyMember) {
        developer.log(
          '既にグループのメンバーです - groupId: $groupId, uid: $_uid',
          name: 'GroupInvitationService',
        );
        // 既にメンバーの場合は成功として扱う（エラーを投げない）
        return;
      }

      // 新しいメンバーを追加
      final photoUrl = _photoUrl;
      developer.log(
        'GroupInvitationService: メンバー追加 - UID: $_uid, 表示名: $_userDisplayName, プロフィール画像: $photoUrl',
        name: 'GroupInvitationService',
      );
      final newMember = {
        'uid': _uid,
        'email': _auth.currentUser?.email ?? '',
        'displayName': _userDisplayName,
        'photoUrl': photoUrl, // プロフィール画像URLを追加
        'role': 'member', // 招待で参加した場合は通常メンバー
        'joinedAt': DateTime.now().toIso8601String(),
        'isActive': true,
      };

      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([newMember]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ユーザーの参加グループリストにも追加（既に存在しない場合のみ）
      final userGroupDoc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('userGroups')
          .doc(groupId)
          .get();

      if (!userGroupDoc.exists) {
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('userGroups')
            .doc(groupId)
            .set({
              'groupId': groupId,
              'groupName': groupData['name'] ?? '',
              'role': 'member',
              'joinedAt': DateTime.now().toIso8601String(),
              'isActive': true,
            });
      }

      developer.log(
        'グループ $groupId にメンバーとして参加しました',
        name: 'GroupInvitationService',
      );
    } catch (e) {
      developer.log(
        'グループ参加エラー',
        name: 'GroupInvitationService',
        error: e,
        level: 1000,
      );
      rethrow;
    }
  }

  /// グループの招待コード一覧を取得
  static Future<List<Map<String, dynamic>>> getGroupInvitationCodes(
    String groupId,
  ) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      final snapshot = await _firestore
          .collection('group_invitations')
          .where('groupId', isEqualTo: groupId)
          .orderBy('createdAt', descending: true)
          .get();

      final invitations = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final invitationInfo = await getInvitationInfo(doc.id);
        if (invitationInfo != null) {
          invitations.add(invitationInfo);
        }
      }

      return invitations;
    } catch (e, s) {
      developer.log(
        '招待コード一覧取得エラー',
        name: 'GroupInvitationService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      return [];
    }
  }

  /// 招待コードを無効化
  static Future<void> deactivateInvitationCode(String invitationCode) async {
    if (_uid == null) throw Exception('未ログイン');

    try {
      await _firestore
          .collection('group_invitations')
          .doc(invitationCode)
          .update({
            'isActive': false,
            'deactivatedAt': FieldValue.serverTimestamp(),
            'deactivatedBy': _uid,
          });

      developer.log(
        '招待コード「$invitationCode」を無効化しました',
        name: 'GroupInvitationService',
      );
    } catch (e) {
      developer.log(
        '招待コード無効化エラー',
        name: 'GroupInvitationService',
        error: e,
        level: 1000,
      );
      rethrow;
    }
  }

  /// 期限切れの招待コードをクリーンアップ
  static Future<void> cleanupExpiredInvitationCodes() async {
    try {
      final now = Timestamp.now();

      // 期限切れの招待コードを取得
      final snapshot = await _firestore
          .collection('group_invitations')
          .where('expiresAt', isLessThan: now)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'deactivatedAt': FieldValue.serverTimestamp(),
          'deactivatedReason': 'expired',
        });
      }

      await batch.commit();
      developer.log(
        '期限切れ招待コード ${snapshot.docs.length} 件をクリーンアップしました',
        name: 'GroupInvitationService',
      );
    } catch (e, s) {
      developer.log(
        '招待コードクリーンアップエラー',
        name: 'GroupInvitationService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
    }
  }

  /// QRコード用のURL生成
  static String generateQRCodeUrl(String invitationCode) {
    // 実際のアプリでは適切なディープリンクURLを使用
    return 'https://yourapp.com/join?code=$invitationCode';
  }

  /// 招待コードの統計情報を取得
  static Future<Map<String, dynamic>> getInvitationCodeStats(
    String invitationCode,
  ) async {
    try {
      final invitationInfo = await getInvitationInfo(invitationCode);
      if (invitationInfo == null) {
        return {};
      }

      final usedBy = List<String>.from(invitationInfo['usedBy'] ?? []);
      final maxUses = invitationInfo['maxUses'] as int?;
      final currentUses = invitationInfo['currentUses'] as int? ?? 0;

      return {
        'totalUses': currentUses,
        'maxUses': maxUses,
        'remainingUses': maxUses != null ? maxUses - currentUses : null,
        'usageRate': maxUses != null ? currentUses / maxUses : null,
        'uniqueUsers': usedBy.length,
        'isActive': invitationInfo['isActive'],
        'isExpired': invitationInfo['isExpired'],
        'isValid': invitationInfo['isValid'],
        'createdAt': invitationInfo['createdAt'],
        'expiresAt': invitationInfo['expiresAt'],
      };
    } catch (e, s) {
      developer.log(
        '招待コード統計取得エラー',
        name: 'GroupInvitationService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      return {};
    }
  }

  /// 招待コードからグループ情報を取得（参加前のプレビュー用）
  static Future<Map<String, dynamic>?> getGroupInfoFromInvitationCode(
    String invitationCode,
  ) async {
    try {
      final invitationInfo = await getInvitationInfo(invitationCode);
      if (invitationInfo == null || !invitationInfo['isValid']) {
        return null;
      }

      final groupId = invitationInfo['groupId'] as String;
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();

      if (!groupDoc.exists) {
        return null;
      }

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      return {
        'groupId': groupId,
        'groupName': groupData['name'] ?? '',
        'groupDescription': groupData['description'] ?? '',
        'memberCount': members.length,
        'createdAt': groupData['createdAt'],
        'invitationCode': invitationCode,
        'invitationValid': invitationInfo['isValid'],
        'invitationExpiresAt': invitationInfo['expiresAt'],
      };
    } catch (e, s) {
      developer.log(
        'グループ情報取得エラー',
        name: 'GroupInvitationService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      return null;
    }
  }

  /// グループの招待コードを削除
  static Future<void> deleteGroupInvitations(String groupId) async {
    try {
      developer.log(
        'グループ招待コード削除開始 - groupId: $groupId',
        name: 'GroupInvitationService',
      );

      // グループに関連する招待コードを取得
      final querySnapshot = await _firestore
          .collection('group_invitations')
          .where('groupId', isEqualTo: groupId)
          .get();

      // 招待コードを削除
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      if (querySnapshot.docs.isNotEmpty) {
        await batch.commit();
        developer.log(
          'グループ招待コード削除完了 - groupId: $groupId, 削除件数: ${querySnapshot.docs.length}',
          name: 'GroupInvitationService',
        );
      } else {
        developer.log(
          'グループ招待コードは存在しませんでした - groupId: $groupId',
          name: 'GroupInvitationService',
        );
      }
    } catch (e) {
      developer.log(
        'グループ招待コード削除エラー - groupId: $groupId',
        name: 'GroupInvitationService',
        error: e,
        level: 1000,
      );
      rethrow;
    }
  }
}
