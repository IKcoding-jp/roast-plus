import 'package:flutter/material.dart';

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
