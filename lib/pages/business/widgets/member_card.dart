import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/models/theme_settings.dart';
import 'package:roastplus/models/attendance_models.dart';

class MemberCard extends StatelessWidget {
  final String name;
  final AttendanceStatus attendanceStatus;
  final VoidCallback? onTap;

  const MemberCard({
    super.key,
    required this.name,
    this.attendanceStatus = AttendanceStatus.present,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.isEmpty ? '未設定' : name;
    final isUnset = displayName == '未設定';

    // 出勤退勤状態に基づいて色を決定
    Color? cardColor;
    Color? textColor;
    Color? borderColor;

    if (isUnset) {
      cardColor = Provider.of<ThemeSettings>(context).backgroundColor2;
      textColor = Colors.grey[600];
      borderColor = Colors.grey.shade400;
    } else {
      switch (attendanceStatus) {
        case AttendanceStatus.present:
          cardColor = Colors.white;
          textColor = Colors.black;
          borderColor = Colors.grey.shade400;
          break;
        case AttendanceStatus.absent:
          cardColor = Colors.red;
          textColor = Colors.white;
          borderColor = Colors.red.shade700;
          break;
      }
    }

    return GestureDetector(
      onTap: isUnset ? null : onTap,
      child: Container(
        width: 100,
        padding: EdgeInsets.symmetric(vertical: 10),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
