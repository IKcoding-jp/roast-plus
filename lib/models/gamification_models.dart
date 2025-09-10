import 'package:flutter/material.dart';

/// ユーザーの称号（バッジ）を表すクラス
class UserBadge {
  final String id;
  final String name;
  final String description;
  final int iconCodePoint; // IconDataの代わりにcodePointを保存
  final Color color;
  final DateTime earnedAt;

  const UserBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconCodePoint,
    required this.color,
    required this.earnedAt,
  });

  /// IconDataを取得するメソッド
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': iconCodePoint,
      'color': color.toARGB32(),
      'earnedAt': earnedAt.toIso8601String(),
    };
  }

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconCodePoint: json['icon'],
      color: Color(json['color']),
      earnedAt: DateTime.parse(json['earnedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserBadge && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// バッジ獲得条件を表すクラス
class BadgeCondition {
  final String badgeId;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool Function(UserStats stats) checkCondition;

  const BadgeCondition({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.checkCondition,
  });

  UserBadge createBadge() {
    return UserBadge(
      id: badgeId,
      name: name,
      description: description,
      iconCodePoint: icon.codePoint,
      color: color,
      earnedAt: DateTime.now(),
    );
  }
}

/// ユーザーの活動統計
class UserStats {
  final int attendanceDays;
  final double totalRoastTimeMinutes;
  final int dripPackCount;
  final int totalRoastSessions;
  final DateTime firstActivityDate;
  final DateTime lastActivityDate;

  const UserStats({
    required this.attendanceDays,
    required this.totalRoastTimeMinutes,
    required this.dripPackCount,
    required this.totalRoastSessions,
    required this.firstActivityDate,
    required this.lastActivityDate,
  });

  /// 総焙煎時間（時間単位）
  double get totalRoastTimeHours => totalRoastTimeMinutes / 60;

  /// 活動開始からの日数
  int get daysSinceStart {
    return DateTime.now().difference(firstActivityDate).inDays + 1;
  }

  UserStats copyWith({
    int? attendanceDays,
    double? totalRoastTimeMinutes,
    int? dripPackCount,
    int? totalRoastSessions,
    DateTime? firstActivityDate,
    DateTime? lastActivityDate,
  }) {
    return UserStats(
      attendanceDays: attendanceDays ?? this.attendanceDays,
      totalRoastTimeMinutes:
          totalRoastTimeMinutes ?? this.totalRoastTimeMinutes,
      dripPackCount: dripPackCount ?? this.dripPackCount,
      totalRoastSessions: totalRoastSessions ?? this.totalRoastSessions,
      firstActivityDate: firstActivityDate ?? this.firstActivityDate,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendanceDays': attendanceDays,
      'totalRoastTimeMinutes': totalRoastTimeMinutes,
      'dripPackCount': dripPackCount,
      'totalRoastSessions': totalRoastSessions,
      'firstActivityDate': firstActivityDate.toIso8601String(),
      'lastActivityDate': lastActivityDate.toIso8601String(),
    };
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return UserStats(
      attendanceDays: json['attendanceDays'] ?? 0,
      totalRoastTimeMinutes: (json['totalRoastTimeMinutes'] ?? 0.0).toDouble(),
      dripPackCount: json['dripPackCount'] ?? 0,
      totalRoastSessions: json['totalRoastSessions'] ?? 0,
      firstActivityDate: json['firstActivityDate'] != null
          ? DateTime.parse(json['firstActivityDate'])
          : now,
      lastActivityDate: json['lastActivityDate'] != null
          ? DateTime.parse(json['lastActivityDate'])
          : now,
    );
  }

  factory UserStats.initial() {
    final now = DateTime.now();
    return UserStats(
      attendanceDays: 0,
      totalRoastTimeMinutes: 0.0,
      dripPackCount: 0,
      totalRoastSessions: 0,
      firstActivityDate: now,
      lastActivityDate: now,
    );
  }
}
