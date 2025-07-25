import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GroupStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 今日の焙煎記録数を取得
  Future<int> getTodayRoastRecordsCount(String groupId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roast_records')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
          )
          .where('timestamp', isLessThan: endOfDay.toIso8601String())
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('今日の焙煎記録数取得エラー: $e');
      return 0;
    }
  }

  // 今週の活動回数を取得
  Future<int> getThisWeekActivityCount(String groupId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDay = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );

      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roast_records')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: startOfWeekDay.toIso8601String(),
          )
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('今週の活動回数取得エラー: $e');
      return 0;
    }
  }

  // 総焙煎時間を取得（時間単位）
  Future<double> getTotalRoastTime(String groupId) async {
    try {
      final querySnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('roast_records')
          .get();

      int totalMinutes = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timeString = data['time'] as String?;

        if (timeString != null) {
          final timeParts = timeString.split(':');
          if (timeParts.length == 2) {
            final minutes = int.tryParse(timeParts[0]) ?? 0;
            final seconds = int.tryParse(timeParts[1]) ?? 0;
            totalMinutes += minutes + (seconds / 60).round();
          }
        }
      }

      return (totalMinutes / 60).roundToDouble();
    } catch (e) {
      debugPrint('総焙煎時間取得エラー: $e');
      return 0.0;
    }
  }

  // グループの統計情報を一括取得
  Future<Map<String, dynamic>> getGroupStatistics(String groupId) async {
    try {
      final todayCount = await getTodayRoastRecordsCount(groupId);
      final weekCount = await getThisWeekActivityCount(groupId);
      final totalTime = await getTotalRoastTime(groupId);

      return {
        'todayRoastCount': todayCount,
        'thisWeekActivityCount': weekCount,
        'totalRoastTime': totalTime,
      };
    } catch (e) {
      debugPrint('グループ統計情報取得エラー: $e');
      return {
        'todayRoastCount': 0,
        'thisWeekActivityCount': 0,
        'totalRoastTime': 0.0,
      };
    }
  }
}
