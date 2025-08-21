// ignore_for_file: constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

/// グループの権限レベル
enum GroupRole {
  admin, // 管理者（全権限）
  leader, // リーダー（編集・追加可能）
  member, // メンバー（閲覧のみ）
}

enum AccessLevel { adminOnly, adminLeader, allMembers }

/// グループ設定
class GroupSettings {
  final bool allowMemberInvite; // メンバーが招待できるか
  final bool allowMemberViewMembers; // メンバーがメンバー一覧を見れるか
  final bool allowLeaderManageGroup; // リーダーがグループ管理（権限設定・名前変更・削除）できるか
  final Map<String, AccessLevel> dataPermissions; // データタイプごとの権限設定
  final DateTime? updatedAt;

  const GroupSettings({
    this.allowMemberInvite = false,
    this.allowMemberViewMembers = true,
    this.allowLeaderManageGroup = false,
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
      'allowLeaderManageGroup': allowLeaderManageGroup,
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
                orElse: () => AccessLevel.adminLeader,
              ),
            ),
          ) ??
          {},
      allowMemberInvite: json['allowMemberInvite'] as bool? ?? false,
      allowMemberViewMembers: json['allowMemberViewMembers'] as bool? ?? true,
      allowLeaderManageGroup: json['allowLeaderManageGroup'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  GroupSettings copyWith({
    bool? allowMemberInvite,
    bool? allowMemberViewMembers,
    bool? allowLeaderManageGroup,
    Map<String, AccessLevel>? dataPermissions,
    DateTime? updatedAt,
  }) {
    return GroupSettings(
      allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,
      allowMemberViewMembers:
          allowMemberViewMembers ?? this.allowMemberViewMembers,
      allowLeaderManageGroup:
          allowLeaderManageGroup ?? this.allowLeaderManageGroup,
      dataPermissions: dataPermissions ?? this.dataPermissions,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// デフォルト設定を取得
  static GroupSettings defaultSettings() {
    return const GroupSettings(
      dataPermissions: {
        'roastRecordInput': AccessLevel.allMembers,
        'work_progress': AccessLevel.adminLeader, // ← 追加
        'roastRecords': AccessLevel.adminLeader,
        'dripCounter': AccessLevel.allMembers,
        'assignment_board': AccessLevel.allMembers, // 担当表関連の権限を一本化
        'todaySchedule': AccessLevel.allMembers, // メンバーが編集できるように変更
        'taskStatus': AccessLevel.allMembers,
        'cuppingNotes': AccessLevel.allMembers,
        'circleStamps': AccessLevel.adminOnly,
        'roast_schedule': AccessLevel.allMembers,
      },
      allowMemberInvite: false,
      allowMemberViewMembers: true,
      updatedAt: null,
    );
  }

  /// 指定されたデータタイプの権限を取得
  AccessLevel getPermissionForDataType(String dataType) {
    developer.log(
      'GroupSettings: データタイプ権限取得 - データタイプ: $dataType',
      name: 'GroupSettings',
    );
    developer.log(
      'GroupSettings: 現在の権限設定: $dataPermissions',
      name: 'GroupSettings',
    );

    // 明示的に設定された権限を優先
    if (dataPermissions.containsKey(dataType)) {
      final permission = dataPermissions[dataType]!;
      developer.log(
        'GroupSettings: 明示的に設定された権限を使用: $permission',
        name: 'GroupSettings',
      );
      return permission;
    }

    // work_progressの権限が存在しない場合はroastRecordInputの権限を参照（後方互換）
    if (dataType == 'work_progress' &&
        dataPermissions.containsKey('roastRecordInput')) {
      final fallbackPermission = dataPermissions['roastRecordInput']!;
      developer.log(
        'GroupSettings: work_progress権限が存在しないため、roastRecordInput権限を参照: $fallbackPermission',
        name: 'GroupSettings',
      );
      return fallbackPermission;
    }

    // today_scheduleの権限が存在しない場合はtodayScheduleの権限を参照
    if (dataType == 'today_schedule' &&
        dataPermissions.containsKey('todaySchedule')) {
      final todaySchedulePermission = dataPermissions['todaySchedule']!;
      developer.log(
        'GroupSettings: today_schedule権限が存在しないため、todaySchedule権限を参照: $todaySchedulePermission',
        name: 'GroupSettings',
      );
      return todaySchedulePermission;
    }

    // roast_scheduleの権限が存在しない場合はtoday_schedule / todaySchedule など近いキーを参照（後方互換）
    if (dataType == 'roast_schedule') {
      if (dataPermissions.containsKey('today_schedule')) {
        final fallbackPermission = dataPermissions['today_schedule']!;
        developer.log(
          'GroupSettings: roast_schedule権限が存在しないため、today_schedule権限を参照: $fallbackPermission',
          name: 'GroupSettings',
        );
        return fallbackPermission;
      }
      if (dataPermissions.containsKey('todaySchedule')) {
        final fallbackPermission = dataPermissions['todaySchedule']!;
        developer.log(
          'GroupSettings: roast_schedule権限が存在しないため、todaySchedule権限を参照: $fallbackPermission',
          name: 'GroupSettings',
        );
        return fallbackPermission;
      }
      if (dataPermissions.containsKey('schedule')) {
        final fallbackPermission = dataPermissions['schedule']!;
        developer.log(
          'GroupSettings: roast_schedule権限が存在しないため、schedule権限を参照: $fallbackPermission',
          name: 'GroupSettings',
        );
        return fallbackPermission;
      }
    }

    final permission = dataPermissions[dataType] ?? AccessLevel.adminLeader;
    developer.log(
      'GroupSettings: デフォルト権限を使用: $permission',
      name: 'GroupSettings',
    );

    return permission;
  }

  /// 指定されたデータタイプの編集権限をチェック
  bool canEditDataType(String dataType, GroupRole userRole) {
    developer.log(
      'GroupSettings: 編集権限チェック開始 - データタイプ: $dataType, ユーザーロール: $userRole',
      name: 'GroupSettings',
    );

    final accessLevel = getPermissionForDataType(dataType);
    developer.log(
      'GroupSettings: 設定されたアクセスレベル: $accessLevel',
      name: 'GroupSettings',
    );

    final result = switch (accessLevel) {
      AccessLevel.adminOnly => userRole == GroupRole.admin,
      AccessLevel.adminLeader =>
        userRole == GroupRole.admin || userRole == GroupRole.leader,
      AccessLevel.allMembers => true,
    };

    developer.log('GroupSettings: 編集権限結果: $result', name: 'GroupSettings');
    developer.log(
      'GroupSettings: 権限チェック詳細 - admin_only: ${userRole == GroupRole.admin}, admin_leader: ${userRole == GroupRole.admin || userRole == GroupRole.leader}',
      name: 'GroupSettings',
    );
    return result;
  }

  /// 既存のグループのtodaySchedule権限を自動的に更新
  GroupSettings updateTodaySchedulePermission() {
    final updatedPermissions = Map<String, AccessLevel>.from(dataPermissions);

    // today_scheduleの権限が存在しない場合のみ、todayScheduleと同じ値に設定
    if (!updatedPermissions.containsKey('today_schedule') &&
        updatedPermissions.containsKey('todaySchedule')) {
      final todaySchedulePermission = updatedPermissions['todaySchedule']!;
      developer.log(
        'GroupSettings: today_schedule権限が存在しないため、todayScheduleと同じ値に設定: $todaySchedulePermission',
        name: 'GroupSettings',
      );
      updatedPermissions['today_schedule'] = todaySchedulePermission;
    }

    return copyWith(
      dataPermissions: updatedPermissions,
      updatedAt: DateTime.now(),
    );
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
      developer.log('Group: getMemberRole開始 - uid: $uid', name: 'Group');
      developer.log('Group: メンバー数: ${members.length}', name: 'Group');
      developer.log(
        'Group: メンバー一覧: ${members.map((m) => '${m.uid}:${m.role}').toList()}',
        name: 'Group',
      );

      final member = members.firstWhere(
        (m) => m.uid == uid,
        orElse: () {
          developer.log('Group: メンバーが見つかりません - uid: $uid', name: 'Group');
          return GroupMember(
            uid: '',
            email: '',
            displayName: '',
            role: GroupRole.member,
            joinedAt: DateTime.now(),
          );
        },
      );

      if (member.uid.isNotEmpty) {
        developer.log(
          'Group: メンバーが見つかりました - uid: ${member.uid}, role: ${member.role}',
          name: 'Group',
        );
        return member.role;
      } else {
        developer.log('Group: メンバーのuidが空です - デフォルトロールを返します', name: 'Group');
        return GroupRole.member;
      }
    } catch (e, st) {
      developer.log(
        'Group: getMemberRole エラー - uid: $uid',
        name: 'Group',
        error: e,
        stackTrace: st,
      );
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
