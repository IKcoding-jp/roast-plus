import 'package:flutter/material.dart';

class RoastBreakTime {
  final TimeOfDay start;
  final TimeOfDay end;

  RoastBreakTime({required this.start, required this.end});

  factory RoastBreakTime.fromJson(Map<String, dynamic> json) {
    return RoastBreakTime(
      start: TimeOfDay(
        hour: json['startHour'] as int,
        minute: json['startMinute'] as int,
      ),
      end: TimeOfDay(
        hour: json['endHour'] as int,
        minute: json['endMinute'] as int,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'startHour': start.hour,
    'startMinute': start.minute,
    'endHour': end.hour,
    'endMinute': end.minute,
  };

  bool contains(TimeOfDay t) {
    final tMinutes = t.hour * 60 + t.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return tMinutes >= startMinutes && tMinutes < endMinutes;
  }
}
