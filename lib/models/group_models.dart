import 'package:cloud_firestore/cloud_firestore.dart';

/// グループの権限レベル
enum GroupRole {
  leader, // リーダー（編集・追加可能）
  member, // メンバー（閲覧のみ）
}

/// データタイプの権限設定
enum DataPermission {
  leaderOnly, // リーダーのみ編集可能
  allMembers, // 全メンバーが編集可能
  readOnly, // 閲覧のみ
}

/// グループ設定
class GroupSettings {
  final Map<String, DataPermission> dataPermissions;
  final bool allowMemberInvite; // メンバーが招待できるか
  final bool allowMemberDataSync; // メンバーがデータ同期できるか
  final bool allowMemberViewMembers; // メンバーがメンバー一覧を見れるか
  final DateTime updatedAt;

  GroupSettings({
    required this.dataPermissions,
    this.allowMemberInvite = false,
    this.allowMemberDataSync = true,
    this.allowMemberViewMembers = true,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'dataPermissions': dataPermissions.map(
        (key, value) => MapEntry(key, value.name),
      ),
      'allowMemberInvite': allowMemberInvite,
      'allowMemberDataSync': allowMemberDataSync,
      'allowMemberViewMembers': allowMemberViewMembers,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GroupSettings.fromJson(Map<String, dynamic> json) {
    return GroupSettings(
      dataPermissions: (json['dataPermissions'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          DataPermission.values.firstWhere(
            (e) => e.name == value,
            orElse: () => DataPermission.leaderOnly,
          ),
        ),
      ),
      allowMemberInvite: json['allowMemberInvite'] as bool? ?? false,
      allowMemberDataSync: json['allowMemberDataSync'] as bool? ?? true,
      allowMemberViewMembers: json['allowMemberViewMembers'] as bool? ?? true,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  GroupSettings copyWith({
    Map<String, DataPermission>? dataPermissions,
    bool? allowMemberInvite,
    bool? allowMemberDataSync,
    bool? allowMemberViewMembers,
    DateTime? updatedAt,
  }) {
    return GroupSettings(
      dataPermissions: dataPermissions ?? this.dataPermissions,
      allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,
      allowMemberDataSync: allowMemberDataSync ?? this.allowMemberDataSync,
      allowMemberViewMembers:
          allowMemberViewMembers ?? this.allowMemberViewMembers,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// デフォルト設定を取得
  factory GroupSettings.defaultSettings() {
    return GroupSettings(
      dataPermissions: {
        'roast_records': DataPermission.leaderOnly,
        'todo_list': DataPermission.allMembers,
        'drip_counter_records': DataPermission.allMembers,
        'assignment_board': DataPermission.leaderOnly,
        'today_assignment': DataPermission.leaderOnly,
        'assignment_history': DataPermission.leaderOnly,
        'schedule': DataPermission.allMembers,
        'today_schedule': DataPermission.leaderOnly, // リーダーのみに変更
        'time_labels': DataPermission.leaderOnly, // リーダーのみに変更
        'settings': DataPermission.leaderOnly,
      },
      allowMemberInvite: false,
      allowMemberDataSync: true, // メンバーもデータ同期可能
      allowMemberViewMembers: true,
      updatedAt: DateTime.now(),
    );
  }

  /// 指定されたデータタイプの権限を取得
  DataPermission getPermissionForDataType(String dataType) {
    return dataPermissions[dataType] ?? DataPermission.leaderOnly;
  }

  /// 指定されたデータタイプが編集可能かチェック
  bool canEditDataType(String dataType, GroupRole userRole) {
    final permission = getPermissionForDataType(dataType);
    print('GroupSettings: canEditDataType チェック');
    print('GroupSettings: データタイプ: $dataType');
    print('GroupSettings: ユーザーロール: $userRole');
    print('GroupSettings: 権限設定: $permission');

    final result = switch (permission) {
      DataPermission.leaderOnly => userRole == GroupRole.leader,
      DataPermission.allMembers => true,
      DataPermission.readOnly => false,
    };

    print('GroupSettings: 編集可能: $result');
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
    return member.role == GroupRole.leader;
  }

  /// 指定されたユーザーがメンバーかどうかをチェック
  bool isMember(String uid) {
    return members.any((m) => m.uid == uid);
  }

  /// 指定されたユーザーの権限を取得
  GroupRole? getMemberRole(String uid) {
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
    return member.uid.isNotEmpty ? member.role : null;
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
