import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_models.dart';

class GroupFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid {
    final uid = _auth.currentUser?.uid;
    return uid != null && uid.isNotEmpty ? uid : null;
  }

  static String? get _email {
    final email = _auth.currentUser?.email;
    return email != null && email.isNotEmpty ? email : null;
  }

  static String? get _displayName => _auth.currentUser?.displayName;
  static String? get _photoUrl => _auth.currentUser?.photoURL;

  /// グループを作成
  static Future<Group> createGroup({
    required String name,
    required String description,
  }) async {
    if (_uid == null) throw Exception('未ログイン');
    if (_email == null) throw Exception('メールアドレスが取得できません');

    final now = DateTime.now();
    final groupId = _firestore.collection('groups').doc().id;

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

    final group = Group(
      id: groupId,
      name: name,
      description: description,
      createdBy: _uid!,
      createdAt: now,
      updatedAt: now,
      members: [creator],
      settings: defaultSettings.toJson(),
    );

    await _firestore.collection('groups').doc(groupId).set(group.toJson());

    // ユーザーのグループ参加情報も保存
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
        });

    return group;
  }

  /// ユーザーが参加しているグループを取得
  static Future<List<Group>> getUserGroups() async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final userGroupsSnapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('userGroups')
        .get();

    final groups = <Group>[];
    for (final doc in userGroupsSnapshot.docs) {
      final groupId = doc.data()['groupId'] as String;
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (groupDoc.exists) {
        groups.add(Group.fromJson(groupDoc.data()!));
      }
    }

    return groups;
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

    final updatedGroup = group.copyWith(updatedAt: DateTime.now());
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());
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

    // 招待を更新
    await _firestore.collection('invitations').doc(invitationId).update({
      'isAccepted': true,
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
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // メンバーのみ同期可能
    if (!group.isMember(_uid!)) {
      throw Exception('グループメンバーのみデータを同期できます');
    }

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
      return GroupSettings.fromJson(group.settings);
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定を返す
      return GroupSettings.defaultSettings();
    }
  }

  /// グループ設定を更新
  static Future<void> updateGroupSettings({
    required String groupId,
    required GroupSettings settings,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // リーダーのみ設定変更可能
    if (!group.isLeader(_uid!)) {
      throw Exception('リーダーのみ設定を変更できます');
    }

    final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
    final updatedGroup = group.copyWith(
      settings: updatedSettings.toJson(),
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection('groups')
        .doc(groupId)
        .update(updatedGroup.toJson());
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
      final settings = GroupSettings.fromJson(group.settings);
      return settings.canEditDataType(dataType, userRole);
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定で判定
      final defaultSettings = GroupSettings.defaultSettings();
      return defaultSettings.canEditDataType(dataType, userRole);
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
      final settings = GroupSettings.fromJson(group.settings);
      // リーダーは常に同期可能
      if (userRole == GroupRole.admin || userRole == GroupRole.leader) {
        return true;
      }
      // メンバーは設定に応じて同期可能
      return settings.allowMemberDataSync;
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定で判定
      final defaultSettings = GroupSettings.defaultSettings();
      if (userRole == GroupRole.admin || userRole == GroupRole.leader) {
        return true;
      }
      return defaultSettings.allowMemberDataSync;
    }
  }
}
