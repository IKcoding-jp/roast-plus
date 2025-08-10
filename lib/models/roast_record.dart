import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_models.dart';

class RoastRecord {
  final String id;
  final String bean;
  final int weight;
  final String roast;
  final String time;
  final String memo;
  final DateTime timestamp;
  final AccessLevel accessLevel;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  RoastRecord({
    required this.id,
    required this.bean,
    required this.weight,
    required this.roast,
    required this.time,
    required this.memo,
    required this.timestamp,
    this.accessLevel = AccessLevel.adminLeader,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory RoastRecord.fromMap(Map<String, dynamic> map, {String? id}) {
    return RoastRecord(
      id: id ?? map['id'] ?? '',
      bean: map['bean'] ?? '',
      weight: map['weight'] ?? 0,
      roast: map['roast'] ?? '',
      time: map['time'] ?? '',
      memo: map['memo'] ?? '',
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      accessLevel: AccessLevel.values.firstWhere(
        (e) => e.name == (map['accessLevel'] ?? 'admin_leader'),
        orElse: () => AccessLevel.adminLeader,
      ),
      createdBy: map['createdBy'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : null,
      updatedBy: map['updatedBy'],
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bean': bean,
      'weight': weight,
      'roast': roast,
      'time': time,
      'memo': memo,
      'timestamp': timestamp.toIso8601String(),
      'accessLevel': accessLevel.name,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedBy': updatedBy,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  RoastRecord copyWith({
    String? id,
    String? bean,
    int? weight,
    String? roast,
    String? time,
    String? memo,
    DateTime? timestamp,
    AccessLevel? accessLevel,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return RoastRecord(
      id: id ?? this.id,
      bean: bean ?? this.bean,
      weight: weight ?? this.weight,
      roast: roast ?? this.roast,
      time: time ?? this.time,
      memo: memo ?? this.memo,
      timestamp: timestamp ?? this.timestamp,
      accessLevel: accessLevel ?? this.accessLevel,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
