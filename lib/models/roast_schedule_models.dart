import 'package:flutter/material.dart';

// ローストスケジュールメモ用のモデル
class RoastScheduleMemo {
  final String id;
  final String time;
  final String? beanName;
  final int? weight;
  final int? quantity;
  final String? roastLevel;
  final bool isAfterPurge;
  final bool isRoasterOn;
  final DateTime date; // 日付フィールドを追加
  final DateTime createdAt;
  final DateTime updatedAt;

  RoastScheduleMemo({
    required this.id,
    required this.time,
    this.beanName,
    this.weight,
    this.quantity,
    this.roastLevel,
    this.isAfterPurge = false,
    this.isRoasterOn = false,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'beanName': beanName,
    'weight': weight,
    'quantity': quantity,
    'roastLevel': roastLevel,
    'isAfterPurge': isAfterPurge,
    'isRoasterOn': isRoasterOn,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory RoastScheduleMemo.fromJson(Map<String, dynamic> json) {
    return RoastScheduleMemo(
      id: json['id'] ?? '',
      time: json['time'] ?? '',
      beanName: json['beanName'],
      weight: json['weight'],
      quantity: json['quantity'],
      roastLevel: json['roastLevel'],
      isAfterPurge: json['isAfterPurge'] ?? false,
      isRoasterOn: json['isRoasterOn'] ?? false,
      date: DateTime.parse(
        json['date'] ?? json['createdAt'],
      ), // 後方互換性のためcreatedAtをフォールバック
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  RoastScheduleMemo copyWith({
    String? id,
    String? time,
    String? beanName,
    int? weight,
    int? quantity,
    String? roastLevel,
    bool? isAfterPurge,
    bool? isRoasterOn,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoastScheduleMemo(
      id: id ?? this.id,
      time: time ?? this.time,
      beanName: beanName ?? this.beanName,
      weight: weight ?? this.weight,
      quantity: quantity ?? this.quantity,
      roastLevel: roastLevel ?? this.roastLevel,
      isAfterPurge: isAfterPurge ?? this.isAfterPurge,
      isRoasterOn: isRoasterOn ?? this.isRoasterOn,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ローストスケジュールメモのプロバイダー
class RoastScheduleMemoProvider extends ChangeNotifier {
  List<RoastScheduleMemo> _memos = [];

  List<RoastScheduleMemo> get memos => _memos;

  void setMemos(List<RoastScheduleMemo> memos) {
    _memos = memos;
    notifyListeners();
  }

  void addMemo(RoastScheduleMemo memo) {
    _memos.add(memo);
    _sortMemos();
    notifyListeners();
  }

  void updateMemo(RoastScheduleMemo memo) {
    final index = _memos.indexWhere((m) => m.id == memo.id);
    if (index != -1) {
      _memos[index] = memo;
      _sortMemos();
      notifyListeners();
    }
  }

  void removeMemo(String id) {
    _memos.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void clearMemos() {
    _memos.clear();
    notifyListeners();
  }

  void _sortMemos() {
    _memos.sort((a, b) {
      // 時間でソート（HH:MM形式）
      final timeA = _parseTime(a.time);
      final timeB = _parseTime(b.time);
      return timeA.compareTo(timeB);
    });
  }

  int _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return hour * 60 + minute;
    }
    return 0;
  }
}

// 以下は既存のコードを保持（後方互換性のため）
class RoastBeanInput {
  String type;
  int? weight; // 1袋あたりの重さ（g）
  int? bags;
  String? roastLevel;
  RoastBeanInput({this.type = '', this.bags});

  Map<String, dynamic> toJson() => {
    'type': type,
    'weight': weight,
    'bags': bags,
    'roastLevel': roastLevel,
  };
  static RoastBeanInput fromJson(Map<String, dynamic> json) {
    final b = RoastBeanInput(
      type: json['type'] ?? '',
      bags: json['bags'] as int?,
    );
    b.weight = json['weight'] as int?;
    b.roastLevel = json['roastLevel'] as String?;
    return b;
  }
}

class RoastTask {
  final String type;
  final String roastLevel;
  final List<int> weights; // 1枠に詰めた重さリスト（最大2つ）
  RoastTask({
    required this.type,
    required this.roastLevel,
    required this.weights,
  });
}

class RoastScheduleResult {
  final RoastTask? task;
  final TimeOfDay? time;
  final bool afterPurge;
  RoastScheduleResult({this.task, this.time, this.afterPurge = false});
}

class RoastScheduleData {
  final List<RoastScheduleResult> amResult;
  final List<RoastScheduleResult> pmResult;
  final List<List<int>> combResults;
  final String overflowMsg;
  RoastScheduleData(
    this.amResult,
    this.pmResult,
    this.combResults,
    this.overflowMsg,
  );
}
