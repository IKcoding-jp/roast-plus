
enum AttendanceStatus {
  present, // 出勤（白）
  absent,  // 退勤（赤）
}

class AttendanceRecord {
  final String memberId;
  final String memberName;
  final AttendanceStatus status;
  final DateTime timestamp;
  final String dateKey; // YYYY-MM-DD形式

  AttendanceRecord({
    required this.memberId,
    required this.memberName,
    required this.status,
    required this.timestamp,
    required this.dateKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'dateKey': dateKey,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      memberId: map['memberId'] ?? '',
      memberName: map['memberName'] ?? '',
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AttendanceStatus.present,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      dateKey: map['dateKey'] ?? '',
    );
  }

  AttendanceRecord copyWith({
    String? memberId,
    String? memberName,
    AttendanceStatus? status,
    DateTime? timestamp,
    String? dateKey,
  }) {
    return AttendanceRecord(
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      dateKey: dateKey ?? this.dateKey,
    );
  }
}

class AttendanceSummary {
  final String dateKey;
  final List<AttendanceRecord> records;
  final int presentCount;
  final int absentCount;
  final int totalCount;

  AttendanceSummary({
    required this.dateKey,
    required this.records,
  }) : presentCount = records.where((r) => r.status == AttendanceStatus.present).length,
       absentCount = records.where((r) => r.status == AttendanceStatus.absent).length,
       totalCount = records.length;

  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'records': records.map((r) => r.toMap()).toList(),
      'presentCount': presentCount,
      'absentCount': absentCount,
      'totalCount': totalCount,
    };
  }

  factory AttendanceSummary.fromMap(Map<String, dynamic> map) {
    return AttendanceSummary(
      dateKey: map['dateKey'] ?? '',
      records: (map['records'] as List<dynamic>?)
          ?.map((r) => AttendanceRecord.fromMap(r))
          .toList() ?? [],
    );
  }
} 