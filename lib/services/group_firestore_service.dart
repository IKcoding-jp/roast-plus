import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_models.dart';
import 'group_invitation_service.dart';

import 'dart:math';
import 'dart:async';

class GroupFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // リトライ設定
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _timeout = Duration(seconds: 30);

  static String? get _uid {
    final uid = _auth.currentUser?.uid;
    return uid != null && uid.isNotEmpty ? uid : null;
  }

  /// リトライ機能付きの操作実行
  static Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int retryCount = 0;
    while (true) {
      try {
        return await operation().timeout(_timeout);
      } catch (e) {
        retryCount++;
        print('GroupFirestoreService: 操作失敗 (試行 $retryCount/$_maxRetries): $e');

        if (retryCount >= _maxRetries) {
          print('GroupFirestoreService: 最大リトライ回数に達しました');
          rethrow;
        }

        // リトライ前に少し待機
        await Future.delayed(_retryDelay);
        print('GroupFirestoreService: リトライ中...');
      }
    }
  }

  static String? get _email {
    final email = _auth.currentUser?.email;
    return email != null && email.isNotEmpty ? email : null;
  }

  static String? get _displayName => _auth.currentUser?.displayName;
  static String? get _photoUrl => _auth.currentUser?.photoURL;

  /// 招待コードを生成
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// グループを作成
  static Future<Group> createGroup({
    required String name,
    required String description,
  }) async {
    return _retryOperation(() async {
      try {
        print('GroupFirestoreService: グループ作成開始');

        if (_uid == null) throw Exception('未ログイン');
        if (_email == null) throw Exception('メールアドレスが取得できません');

        final now = DateTime.now();
        final groupId = _firestore.collection('groups').doc().id;

        print('GroupFirestoreService: グループID生成: $groupId');

        final creator = GroupMember(
          uid: _uid!,
          email: _email!,
          displayName: _displayName ?? 'Unknown User',
          photoUrl: _photoUrl,
          role: GroupRole.admin, // グループ作成者は管理者として扱う
          joinedAt: now,
          lastActiveAt: now,
        );

        // デフォルト設定を作成
        final defaultSettings = GroupSettings.defaultSettings();

        // 招待コードを生成（8文字のランダム文字列）
        final inviteCode = _generateInviteCode();

        print('GroupFirestoreService: 招待コード生成: $inviteCode');

        final group = Group(
          id: groupId,
          name: name,
          description: description,
          createdBy: _uid!,
          createdAt: now,
          updatedAt: now,
          members: [creator],
          settings: defaultSettings.toJson(),
          inviteCode: inviteCode,
        );

        print('GroupFirestoreService: グループドキュメント保存開始');
        await _firestore
            .collection('groups')
            .doc(groupId)
            .set(group.toJson())
            .timeout(_timeout);
        print('GroupFirestoreService: グループドキュメント保存完了');

        // ユーザーのグループ参加情報も保存
        print('GroupFirestoreService: ユーザーグループ情報保存開始');
        await _firestore
            .collection('users')
            .doc(_uid)
            .collection('userGroups')
            .doc(groupId)
            .set({
              'groupId': groupId,
              'groupName': name,
              'role': GroupRole.admin.name,
              'joinedAt': now.toIso8601String(),
            })
            .timeout(_timeout);
        print('GroupFirestoreService: ユーザーグループ情報保存完了');

        print('GroupFirestoreService: グループ作成完了');
        return group;
      } catch (e) {
        print('GroupFirestoreService: グループ作成エラー: $e');
        rethrow;
      }
    });
  }



  /// ユーザーが参加しているグループを取得
  static Future<List<Group>> getUserGroups() async {
    return _retryOperation(() async {
      if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

      final userGroupsSnapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('userGroups')
          .get()
          .timeout(_timeout);

      if (userGroupsSnapshot.docs.isEmpty) {
        return [];
      }

      // 並列でグループ情報を取得（読み込み時間を短縮）
      final futures = userGroupsSnapshot.docs.map((doc) async {
        final groupId = doc.data()['groupId'] as String;
        final groupDoc = await _firestore
            .collection('groups')
            .doc(groupId)
            .get()
            .timeout(_timeout);
        if (groupDoc.exists) {
          return Group.fromJson(groupDoc.data()!);
        }
        return null;
      });

      final results = await Future.wait(futures);
      return results.whereType<Group>().toList();
    });
  }

  /// グループの詳細を取得
  static Future<Group?> getGroup(String groupId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromJson(doc.data()!);
  }

  /// グループを更新
  static Future<void> updateGroup(Group group) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    // リーダーのみ更新可能
    if (!group.isLeader(_uid!)) {
      throw Exception('リーダーのみグループを更新できます');
    }

    // 更新日時を現在時刻に設定
    final updatedGroup = group.copyWith(updatedAt: DateTime.now());

    print('GroupFirestoreService: グループ更新開始');
    print('GroupFirestoreService: グループID: ${group.id}');
    print('GroupFirestoreService: 新しい名前: ${updatedGroup.name}');
    print('GroupFirestoreService: 新しい説明: ${updatedGroup.description}');

    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    print('GroupFirestoreService: グループ更新完了');
  }

  /// グループを削除
  static Future<void> deleteGroup(String groupId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // リーダーのみ削除可能
    if (!group.isLeader(_uid!)) {
      throw Exception('リーダーのみグループを削除できます');
    }

    print('GroupFirestoreService: グループ削除開始 - groupId: $groupId');

    try {
      // グループに保存されたデータを削除
      await _deleteGroupData(groupId);

      // グループの招待コードを削除
      await GroupInvitationService.deleteGroupInvitations(groupId);

      // グループの招待データを削除
      await _deleteGroupInvitations(groupId);

      // グループを削除
      await _firestore.collection('groups').doc(groupId).delete();

      // 全メンバーの参加情報を削除
      for (final member in group.members) {
        await _firestore
            .collection('users')
            .doc(member.uid)
            .collection('userGroups')
            .doc(groupId)
            .delete();
      }

      print('GroupFirestoreService: グループ削除完了 - groupId: $groupId');
    } catch (e) {
      print('GroupFirestoreService: グループ削除エラー: $e');
      rethrow;
    }
  }

  /// グループに保存されたデータを削除
  static Future<void> _deleteGroupData(String groupId) async {
    print('GroupFirestoreService: グループデータ削除開始 - groupId: $groupId');

    try {
      // グループの共有データを削除
      await _deleteGroupSharedData(groupId);

      // グループのサブコレクションを削除
      await _deleteGroupSubcollections(groupId);

      print('GroupFirestoreService: グループデータ削除完了 - groupId: $groupId');
    } catch (e) {
      print('GroupFirestoreService: グループデータ削除エラー: $e');
      rethrow;
    }
  }

  /// グループの共有データを削除
  static Future<void> _deleteGroupSharedData(String groupId) async {
    print('GroupFirestoreService: グループ共有データ削除開始 - groupId: $groupId');

    try {
      // 共有データの種類を定義
      final dataTypes = [
        'today_schedule', // 本日のスケジュール
        'time_labels', // 時間ラベル
        'drip_counter', // ドリップカウンター
        'assignment_board', // 担当ボード
        'schedule', // スケジュール
        'today_assignment', // 今日の担当
      ];

      // 各データタイプを削除
      for (final dataType in dataTypes) {
        try {
          await _firestore
              .collection('groups')
              .doc(groupId)
              .collection('shared_data')
              .doc(dataType)
              .delete();
          print('GroupFirestoreService: 共有データ削除完了 - dataType: $dataType');
        } catch (e) {
          print(
            'GroupFirestoreService: 共有データ削除エラー - dataType: $dataType, error: $e',
          );
          // 個別のエラーは無視して続行
        }
      }
    } catch (e) {
      print('GroupFirestoreService: グループ共有データ削除エラー: $e');
      rethrow;
    }
  }

  /// グループのサブコレクションを削除
  static Future<void> _deleteGroupSubcollections(String groupId) async {
    print('GroupFirestoreService: グループサブコレクション削除開始 - groupId: $groupId');

    try {
      // 削除対象のサブコレクション
      final subcollections = [
        'roast_records', // 焙煎記録
        'tasting_records', // 試飲記録
        'drip_pack_records', // ドリップパック記録
        'work_progress_records', // 作業進捗記録
        'attendance_records', // 出勤記録
        'memo_records', // メモ記録
        'group_gamification', // ゲーミフィケーション
        'group_settings', // グループ設定
        'group_invitations', // グループ招待
      ];

      // 各サブコレクションを削除
      for (final subcollection in subcollections) {
        try {
          await _deleteSubcollection(groupId, subcollection);
          print(
            'GroupFirestoreService: サブコレクション削除完了 - subcollection: $subcollection',
          );
        } catch (e) {
          print(
            'GroupFirestoreService: サブコレクション削除エラー - subcollection: $subcollection, error: $e',
          );
          // 個別のエラーは無視して続行
        }
      }
    } catch (e) {
      print('GroupFirestoreService: グループサブコレクション削除エラー: $e');
      rethrow;
    }
  }

  /// サブコレクションを削除
  static Future<void> _deleteSubcollection(
    String groupId,
    String subcollectionName,
  ) async {
    try {
      final subcollectionRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection(subcollectionName);

      // サブコレクション内の全ドキュメントを取得
      final querySnapshot = await subcollectionRef.get();

      // バッチ処理で全ドキュメントを削除
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      // バッチを実行
      if (querySnapshot.docs.isNotEmpty) {
        await batch.commit();
        print(
          'GroupFirestoreService: サブコレクション削除完了 - $subcollectionName: ${querySnapshot.docs.length}件',
        );
      } else {
        print('GroupFirestoreService: サブコレクションは空でした - $subcollectionName');
      }
    } catch (e) {
      print('GroupFirestoreService: サブコレクション削除エラー - $subcollectionName: $e');
      rethrow;
    }
  }

  /// グループの招待データを削除
  static Future<void> _deleteGroupInvitations(String groupId) async {
    try {
      print('GroupFirestoreService: グループ招待データ削除開始 - groupId: $groupId');

      // グループに関連する招待を取得
      final querySnapshot = await _firestore
          .collection('invitations')
          .where('groupId', isEqualTo: groupId)
          .get();

      // 招待を削除
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      if (querySnapshot.docs.isNotEmpty) {
        await batch.commit();
        print(
          'GroupFirestoreService: グループ招待データ削除完了 - groupId: $groupId, 削除件数: ${querySnapshot.docs.length}',
        );
      } else {
        print('GroupFirestoreService: グループ招待データは存在しませんでした - groupId: $groupId');
      }
    } catch (e) {
      print(
        'GroupFirestoreService: グループ招待データ削除エラー - groupId: $groupId, error: $e',
      );
      rethrow;
    }
  }

  /// メンバーを招待
  static Future<void> inviteMember({
    required String groupId,
    required String invitedEmail,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // リーダーのみ招待可能
    if (!group.isLeader(_uid!)) {
      throw Exception('リーダーのみメンバーを招待できます');
    }

    // 既にメンバーかチェック
    if (group.members.any((m) => m.email == invitedEmail)) {
      throw Exception('既にメンバーです');
    }

    final invitationId = _firestore.collection('invitations').doc().id;
    final invitation = GroupInvitation(
      id: invitationId,
      groupId: groupId,
      groupName: group.name,
      invitedBy: _uid!,
      invitedByEmail: _email!,
      invitedEmail: invitedEmail,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: 7)), // 7日間有効
    );

    await _firestore
        .collection('invitations')
        .doc(invitationId)
        .set(invitation.toJson());
  }

  /// 招待を承諾
  static Future<void> acceptInvitation(String invitationId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    final invitationDoc = await _firestore
        .collection('invitations')
        .doc(invitationId)
        .get();
    if (!invitationDoc.exists) throw Exception('招待が見つかりません');

    final invitation = GroupInvitation.fromJson(invitationDoc.data()!);

    // 招待されたメールアドレスと一致するかチェック
    if (invitation.invitedEmail != _email) {
      throw Exception('この招待はあなた宛てではありません');
    }

    if (!invitation.isValid) {
      throw Exception('招待が無効です');
    }

    final group = await getGroup(invitation.groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // メンバーを追加
    final newMember = GroupMember(
      uid: _uid!,
      email: _email!,
      displayName: _displayName ?? 'Unknown User',
      photoUrl: _photoUrl,
      role: GroupRole.member, // 招待されたメンバーはメンバーとして扱う
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    final updatedMembers = [...group.members, newMember];
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // ユーザーのグループ参加情報を保存
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('userGroups')
        .doc(group.id)
        .set({
          'groupId': group.id,
          'groupName': group.name,
          'role': GroupRole.member.name,
          'joinedAt': DateTime.now().toIso8601String(),
        });

    print(
      'GroupFirestoreService: 招待コード参加完了 - グループID: ${group.id}, メンバー数: ${updatedGroup.members.length}',
    );

    // 招待を更新
    await _firestore.collection('invitations').doc(invitationId).update({
      'isAccepted': true,
      'acceptedAt': DateTime.now().toIso8601String(),
    });

    print(
      'GroupFirestoreService: 招待承諾完了 - グループID: ${group.id}, メンバー数: ${updatedGroup.members.length}',
    );
  }

  /// 招待コードでグループに参加
  static Future<void> joinGroupByInviteCode(String inviteCode) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    // 招待コードでグループを検索
    final groupsSnapshot = await _firestore
        .collection('groups')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (groupsSnapshot.docs.isEmpty) {
      throw Exception('招待コードが無効です');
    }

    final groupDoc = groupsSnapshot.docs.first;
    final group = Group.fromJson(groupDoc.data());

    // 既にメンバーかチェック
    if (group.members.any((m) => m.uid == _uid)) {
      throw Exception('既にグループのメンバーです');
    }

    // メンバーを追加
    final newMember = GroupMember(
      uid: _uid!,
      email: _email!,
      displayName: _displayName ?? 'Unknown User',
      photoUrl: _photoUrl,
      role: GroupRole.member, // 招待コードで参加したメンバーはメンバーとして扱う
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    final updatedMembers = [...group.members, newMember];
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // ユーザーのグループ参加情報を保存
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('userGroups')
        .doc(group.id)
        .set({
          'groupId': group.id,
          'groupName': group.name,
          'role': GroupRole.member.name,
          'joinedAt': DateTime.now().toIso8601String(),
        });
  }

  /// 招待を拒否
  static Future<void> declineInvitation(String invitationId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    final invitationDoc = await _firestore
        .collection('invitations')
        .doc(invitationId)
        .get();
    if (!invitationDoc.exists) throw Exception('招待が見つかりません');

    final invitation = GroupInvitation.fromJson(invitationDoc.data()!);

    if (invitation.invitedEmail != _email) {
      throw Exception('この招待はあなた宛てではありません');
    }

    await _firestore.collection('invitations').doc(invitationId).update({
      'isDeclined': true,
    });
  }

  /// ユーザーの招待一覧を取得
  static Future<List<GroupInvitation>> getUserInvitations() async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    final invitationsSnapshot = await _firestore
        .collection('invitations')
        .where('invitedEmail', isEqualTo: _email)
        .where('isAccepted', isEqualTo: false)
        .where('isDeclined', isEqualTo: false)
        .get();

    return invitationsSnapshot.docs
        .map((doc) => GroupInvitation.fromJson(doc.data()))
        .where((invitation) => invitation.isValid)
        .toList();
  }

  /// メンバーを削除
  static Future<void> removeMember({
    required String groupId,
    required String memberUid,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // リーダーのみ削除可能
    if (!group.isLeader(_uid!)) {
      throw Exception('リーダーのみメンバーを削除できます');
    }

    // 自分自身は削除できない
    if (memberUid == _uid) {
      throw Exception('自分自身を削除することはできません');
    }

    final updatedMembers = group.members
        .where((m) => m.uid != memberUid)
        .toList();
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // メンバーの参加情報を削除
    await _firestore
        .collection('users')
        .doc(memberUid)
        .collection('userGroups')
        .doc(groupId)
        .delete();
  }

  /// メンバーの権限を変更
  static Future<void> changeMemberRole({
    required String groupId,
    required String memberUid,
    required GroupRole newRole,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // リーダーのみ権限変更可能
    if (!group.isLeader(_uid!)) {
      throw Exception('リーダーのみ権限を変更できます');
    }

    final updatedMembers = group.members.map((member) {
      if (member.uid == memberUid) {
        return member.copyWith(role: newRole);
      }
      return member;
    }).toList();

    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // ユーザーの参加情報も更新
    await _firestore
        .collection('users')
        .doc(memberUid)
        .collection('userGroups')
        .doc(groupId)
        .update({'role': newRole.name});
  }

  /// グループから脱退
  static Future<void> leaveGroup(String groupId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    final updatedMembers = group.members.where((m) => m.uid != _uid).toList();
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // 自分の参加情報を削除
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('userGroups')
        .doc(groupId)
        .delete();
  }

  /// グループのデータを同期（グループメンバー間でデータを共有）
  static Future<void> syncGroupData({
    required String groupId,
    required String dataType,
    required Map<String, dynamic> data,
  }) async {
    print('GroupFirestoreService: syncGroupData開始');
    print('GroupFirestoreService: グループID: $groupId');
    print('GroupFirestoreService: データタイプ: $dataType');
    print('GroupFirestoreService: 同期データ: $data');

    if (_uid == null || _uid!.isEmpty) {
      print('GroupFirestoreService: 未ログインエラー');
      throw Exception('未ログイン');
    }

    print('GroupFirestoreService: ユーザーID: $_uid');
    final group = await getGroup(groupId);
    if (group == null) {
      print('GroupFirestoreService: グループが見つかりません');
      throw Exception('グループが見つかりません');
    }

    print('GroupFirestoreService: グループ取得完了');
    print(
      'GroupFirestoreService: グループメンバー: ${group.members.map((m) => m.uid).toList()}',
    );

    // メンバーのみ同期可能
    if (!group.isMember(_uid!)) {
      print('GroupFirestoreService: グループメンバーではありません');
      throw Exception('グループメンバーのみデータを同期できます');
    }

    print('GroupFirestoreService: メンバー権限チェック完了、Firestoreに保存開始');
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sharedData')
        .doc(dataType)
        .set({
          'data': data,
          'updatedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    print('GroupFirestoreService: Firestore保存完了');
  }

  /// グループの共有データを取得
  static Future<Map<String, dynamic>?> getGroupData({
    required String groupId,
    required String dataType,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // メンバーのみ取得可能
    if (!group.isMember(_uid!)) {
      throw Exception('グループメンバーのみデータを取得できます');
    }

    final doc = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sharedData')
        .doc(dataType)
        .get();

    if (!doc.exists) return null;
    return doc.data()?['data'] as Map<String, dynamic>?;
  }

  /// グループの共有データの変更を監視
  static Stream<Map<String, dynamic>?> watchGroupData({
    required String groupId,
    required String dataType,
  }) {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sharedData')
        .doc(dataType)
        .snapshots()
        .map((doc) => doc.data()?['data'] as Map<String, dynamic>?);
  }

  /// グループ設定を取得
  static Future<GroupSettings?> getGroupSettings(String groupId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) return null;

    try {
      final settings = GroupSettings.fromJson(group.settings);

      // 管理者の設定を尊重するため、自動更新は行わない
      return settings;
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定を返す
      return GroupSettings.defaultSettings();
    }
  }

  /// グループ設定の変更をリアルタイム監視
  static Stream<GroupSettings?> watchGroupSettings(String groupId) {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    return _firestore.collection('groups').doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;

      try {
        final groupData = doc.data()!;
        final settingsData = groupData['settings'] as Map<String, dynamic>?;
        if (settingsData == null) return GroupSettings.defaultSettings();

        final settings = GroupSettings.fromJson(settingsData);

        // 管理者の設定を尊重するため、自動更新は行わない
        return settings;
      } catch (e) {
        // 古い形式の設定の場合はデフォルト設定を返す
        return GroupSettings.defaultSettings();
      }
    });
  }

  /// グループ設定を更新
  static Future<void> updateGroupSettings({
    required String groupId,
    required GroupSettings settings,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    print('GroupFirestoreService: 設定更新開始');
    print('GroupFirestoreService: グループID: $groupId');
    print('GroupFirestoreService: ユーザーID: $_uid');
    print('GroupFirestoreService: 更新する設定: $settings');
    print(
      'GroupFirestoreService: 更新する設定のdataPermissions: ${settings.dataPermissions}',
    );

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    print('GroupFirestoreService: グループ取得完了');
    print('GroupFirestoreService: 現在のグループ設定: ${group.settings}');

    // 管理者またはリーダーのみ設定変更可能
    final userRole = group.getMemberRole(_uid!);
    print('GroupFirestoreService: ユーザーロール: $userRole');

    if (userRole != GroupRole.admin && userRole != GroupRole.leader) {
      print('GroupFirestoreService: 権限不足');
      throw Exception('管理者またはリーダーのみ設定を変更できます');
    }

    print('GroupFirestoreService: 権限チェック完了');

    final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
    // settingsフィールドのみをmergeでsetする
    await _firestore.collection('groups').doc(groupId).set({
      'settings': updatedSettings.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    print('GroupFirestoreService: Firestore set(merge: true)で更新完了');
  }

  /// 指定されたデータタイプの編集権限をチェック
  static Future<bool> canEditDataType({
    required String groupId,
    required String dataType,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) return false;

    final userRole = group.getMemberRole(_uid!);
    if (userRole == null) return false;

    try {
      return GroupSettings.fromJson(
        group.settings,
      ).canEditDataType(dataType, userRole);
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定で判定
      return GroupSettings.defaultSettings().canEditDataType(
        dataType,
        userRole,
      );
    }
  }

  /// 指定されたデータタイプの同期権限をチェック
  static Future<bool> canSyncDataType({
    required String groupId,
    required String dataType,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) return false;

    final userRole = group.getMemberRole(_uid!);
    if (userRole == null) return false;

    try {
      // リーダーは常に同期可能
      if (userRole == GroupRole.admin || userRole == GroupRole.leader) {
        return true;
      }
      // メンバーは常に同期可能（データ同期は基本的な機能）
      return true;
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定で判定
      if (userRole == GroupRole.admin || userRole == GroupRole.leader) {
        return true;
      }
      return true;
    }
  }
}
