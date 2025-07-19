import 'package:cloud_firestore/cloud_firestore.dart';

class RoastRecord {
  final String id;
  final String bean;
  final int weight;
  final String roast;
  final String time;
  final String memo;
  final DateTime timestamp;

  RoastRecord({
    required this.id,
    required this.bean,
    required this.weight,
    required this.roast,
    required this.time,
    required this.memo,
    required this.timestamp,
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
  }) {
    return RoastRecord(
      id: id ?? this.id,
      bean: bean ?? this.bean,
      weight: weight ?? this.weight,
      roast: roast ?? this.roast,
      time: time ?? this.time,
      memo: memo ?? this.memo,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
