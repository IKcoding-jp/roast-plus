import 'package:cloud_firestore/cloud_firestore.dart';

/// グループの権限レベル
enum GroupRole {
  admin, // 管理者（全権限）
  leader, // リーダー（編集・追加可能）
  member, // メンバー（閲覧のみ）
}

enum AccessLevel { admin_only, admin_leader, all_members }

/// グループ設定
class GroupSettings {
  final bool allowMemberInvite; // メンバーが招待できるか
  final bool allowMemberViewMembers; // メンバーがメンバー一覧を見れるか
  final Map<String, AccessLevel> dataPermissions; // データタイプごとの権限設定
  final DateTime? updatedAt;

  const GroupSettings({
    this.allowMemberInvite = false,
    this.allowMemberViewMembers = true,
    this.dataPermissions = const {},
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'dataPermissions': dataPermissions.map(
        (key, value) => MapEntry(key, value.name),
      ),
      'allowMemberInvite': allowMemberInvite,
      'allowMemberViewMembers': allowMemberViewMembers,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory GroupSettings.fromJson(Map<String, dynamic> json) {
    return GroupSettings(
      dataPermissions:
          (json['dataPermissions'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(
          key,
              AccessLevel.values.firstWhere(
            (e) => e.name == value,
                orElse: () => AccessLevel.admin_leader,
          ),
        ),
          ) ??
          {},
      allowMemberInvite: json['allowMemberInvite'] as bool? ?? false,
      allowMemberViewMembers: json['allowMemberViewMembers'] as bool? ?? true,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  GroupSettings copyWith({
    bool? allowMemberInvite,
    bool? allowMemberViewMembers,
    Map<String, AccessLevel>? dataPermissions,
    DateTime? updatedAt,
  }) {
    return GroupSettings(
      allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,
      allowMemberViewMembers:
          allowMemberViewMembers ?? this.allowMemberViewMembers,
      dataPermissions: dataPermissions ?? this.dataPermissions,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// デフォルト設定を取得
  static GroupSettings defaultSettings() {
    return const GroupSettings(
      dataPermissions: {
        'roastRecordInput': AccessLevel.all_members,
        'roastRecords': AccessLevel.admin_leader,
        'dripCounter': AccessLevel.all_members,
        'assignment_board': AccessLevel.all_members, // 担当表関連の権限を一本化
        'todaySchedule': AccessLevel.admin_leader,
        'taskStatus': AccessLevel.all_members,
        'cuppingNotes': AccessLevel.all_members,
        'circleStamps': AccessLevel.admin_only,
      },
      allowMemberInvite: false,
      allowMemberViewMembers: true,
      updatedAt: null,
    );
  }

  /// 指定されたデータタイプの権限を取得
  AccessLevel getPermissionForDataType(String dataType) {
    print('GroupSettings: データタイプ権限取得 - データタイプ: $dataType');
    print('GroupSettings: 現在の権限設定: $dataPermissions');

    final permission = dataPermissions[dataType] ?? AccessLevel.admin_leader;
    print('GroupSettings: 取得した権限: $permission');

    return permission;
  }

  /// 指定されたデータタイプの編集権限をチェック
  bool canEditDataType(String dataType, GroupRole userRole) {
    print('GroupSettings: 編集権限チェック開始 - データタイプ: $dataType, ユーザーロール: $userRole');

    final accessLevel = getPermissionForDataType(dataType);
    print('GroupSettings: 設定されたアクセスレベル: $accessLevel');

    final result = switch (accessLevel) {
      AccessLevel.admin_only => userRole == GroupRole.admin,
      AccessLevel.admin_leader =>
        userRole == GroupRole.admin || userRole == GroupRole.leader,
      AccessLevel.all_members => true,
    };

    print('GroupSettings: 編集権限結果: $result');
    return result;
  }
}

/// グループメンバー情報
class GroupMember {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final GroupRole role;
  final DateTime joinedAt;
  final DateTime? lastActiveAt;

  GroupMember({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.role,
    required this.joinedAt,
    this.lastActiveAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
    };
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return GroupMember(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      role: GroupRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => GroupRole.member,
      ),
      joinedAt: parseDate(json['joinedAt']),
      lastActiveAt: json['lastActiveAt'] != null
          ? parseDate(json['lastActiveAt'])
          : null,
    );
  }

  GroupMember copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    GroupRole? role,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
  }) {
    return GroupMember(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

/// グループ情報
class Group {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GroupMember> members;
  final Map<String, dynamic> settings;
  final String? iconName; // グループアイコン名
  final String? imageUrl; // グループ画像URL
  final String inviteCode; // 招待コード

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
    required this.settings,
    this.iconName,
    this.imageUrl,
    required this.inviteCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'members': members.map((m) => m.toJson()).toList(),
      'settings': settings,
      'iconName': iconName,
      'imageUrl': imageUrl,
      'inviteCode': inviteCode,
    };
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      members: (json['members'] as List<dynamic>)
          .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      settings: json['settings'] as Map<String, dynamic>? ?? {},
      iconName: json['iconName'] as String?,
      imageUrl: json['imageUrl'] as String?,
      inviteCode: json['inviteCode'] as String? ?? '',
    );
  }

  /// 指定されたユーザーがリーダーかどうかをチェック
  bool isLeader(String uid) {
    final member = members.firstWhere(
      (m) => m.uid == uid,
      orElse: () => GroupMember(
        uid: '',
        email: '',
        displayName: '',
        role: GroupRole.member,
        joinedAt: DateTime.now(),
      ),
    );
    return member.role == GroupRole.leader || member.role == GroupRole.admin;
  }

  /// 指定されたユーザーがメンバーかどうかをチェック
  bool isMember(String uid) {
    return members.any((m) => m.uid == uid);
  }

  /// 指定されたユーザーの権限を取得
  GroupRole? getMemberRole(String uid) {
    try {
    final member = members.firstWhere(
      (m) => m.uid == uid,
      orElse: () => GroupMember(
        uid: '',
        email: '',
        displayName: '',
        role: GroupRole.member,
        joinedAt: DateTime.now(),
      ),
    );
      return member.uid.isNotEmpty ? member.role : GroupRole.member;
    } catch (e) {
      print('Group: getMemberRole エラー - uid: $uid, error: $e');
      return GroupRole.member;
    }
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<GroupMember>? members,
    Map<String, dynamic>? settings,
    String? iconName,
    String? imageUrl,
    String? inviteCode,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      settings: settings ?? this.settings,
      iconName: iconName ?? this.iconName,
      imageUrl: imageUrl ?? this.imageUrl,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}

/// グループ招待情報
class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedBy;
  final String invitedByEmail;
  final String invitedEmail;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isAccepted;
  final bool isDeclined;

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedBy,
    required this.invitedByEmail,
    required this.invitedEmail,
    required this.createdAt,
    this.expiresAt,
    this.isAccepted = false,
    this.isDeclined = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'invitedBy': invitedBy,
      'invitedByEmail': invitedByEmail,
      'invitedEmail': invitedEmail,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isAccepted': isAccepted,
      'isDeclined': isDeclined,
    };
  }

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      invitedBy: json['invitedBy'] as String,
      invitedByEmail: json['invitedByEmail'] as String,
      invitedEmail: json['invitedEmail'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isAccepted: json['isAccepted'] as bool? ?? false,
      isDeclined: json['isDeclined'] as bool? ?? false,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isValid {
    return !isAccepted && !isDeclined && !isExpired;
  }
}

class Team {
  final String id;
  final String name;
  final List<String> members;

  Team({required this.id, required this.name, required this.members});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'members': members};
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      members: List<String>.from(map['members'] ?? []),
    );
  }

  Team copyWith({String? id, String? name, List<String>? members}) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
    );
  }
}
