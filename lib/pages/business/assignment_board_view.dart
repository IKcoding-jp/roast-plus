import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roastplus/models/attendance_models.dart';
import 'package:roastplus/models/theme_settings.dart';
import 'package:roastplus/pages/business/assignment_board_controller.dart';
import 'package:roastplus/pages/business/utils/assignment_utils.dart';
import 'package:roastplus/pages/business/widgets/member_card.dart';
import 'package:roastplus/widgets/lottie_animation_widget.dart';
import 'package:roastplus/models/group_provider.dart';
import 'package:roastplus/pages/labels/label_edit_page.dart';
import 'package:roastplus/pages/members/member_edit_page.dart';
import 'package:roastplus/pages/history/assignment_history_page.dart';
import 'package:roastplus/pages/settings/assignment_settings_page.dart';
import 'package:roastplus/models/group_models.dart'; // Teamモデルのインポートを追加


class AssignmentBoardView extends StatelessWidget {
  final AssignmentBoardController controller;
  final VoidCallback onReset;

  const AssignmentBoardView({Key? key, required this.controller, required this.onReset}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    final visibleAttendance = controller.todayAttendance.where((record) {
      final allMembers = controller.currentTeams.expand((t) => t.members).toSet();
      return allMembers.contains(record.memberName);
    }).toList();

    final todayIsWeekend = isWeekend();
    final isButtonDisabled =
        todayIsWeekend && !controller.developerMode ||
        controller.assignedToday ||
        controller.shuffling;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.group_work, color: themeSettings.appBarTextColor, size: 24), // `group_work` アイコンに変更
            SizedBox(width: 8),
            Text(
              '担当表',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontSize: 20 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                if (groupProvider.groups.isNotEmpty) {
                  return Container(
                    margin: EdgeInsets.only(left: 12),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade400),
                    ),
                    child: Icon(
                      Icons.groups,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ],
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        actions: [
          if (controller.canEditAssignment == true) ...[
            IconButton(
              icon: Icon(Icons.person_add),
              tooltip: 'メンバー編集',
              onPressed: () async {
                final groupProvider = context.read<GroupProvider>();

                List<String>? currentLeftLabels;
                List<String>? currentRightLabels;
                if (groupProvider.hasGroup) {
                  currentLeftLabels = List<String>.from(controller.currentLeftLabels);
                  currentRightLabels = List<String>.from(controller.currentRightLabels);
                }

                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MemberEditPage()),
                );

                if (!groupProvider.hasGroup) {
                  await controller.reloadMembersOnly();
                }

                if (groupProvider.hasGroup &&
                    currentLeftLabels != null &&
                    currentRightLabels != null) {
                  // Controllerで直接更新
                  controller.leftLabels = currentLeftLabels;
                  controller.rightLabels = currentRightLabels;
                  controller.notifyListeners();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.label),
              tooltip: 'ラベル編集',
              onPressed: () async {
                final groupProvider = context.read<GroupProvider>();

                List<Team>? currentTeams;
                if (groupProvider.hasGroup) {
                  currentTeams = List<Team>.from(controller.currentTeams);
                }

                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LabelEditPage()),
                );

                if (!groupProvider.hasGroup) {
                  await controller.reloadLabelsOnly();
                }

                if (groupProvider.hasGroup && currentTeams != null) {
                  // Controllerで直接更新
                  controller.teams = currentTeams;
                  controller.notifyListeners();
                }
              },
            ),
          ],
          IconButton(
            icon: Icon(Icons.list),
            tooltip: '担当履歴',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AssignmentHistoryPage()),
              );
            },
          ),
          if (controller.canEditAssignment == true)
            IconButton(
              icon: Icon(Icons.settings),
              tooltip: '設定',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(onReset: onReset),
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        color: themeSettings.backgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              if (!controller.hasGroup) // グループに所属していない場合のメッセージ
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    'グループに所属していないため、担当表機能は利用できません。グループに参加するか、作成してください。',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (controller.isLoading) // ローディング表示
                Center(
                  child: CircularProgressIndicator(color: themeSettings.iconColor), // CircularProgressIndicatorの色をiconColorに変更
                )
              else ...[
                if (!controller.isAttendanceLoading && visibleAttendance.isNotEmpty)
                  Card(
                    elevation: 4,
                    color: themeSettings.backgroundColor2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                '今日の出勤状況',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: visibleAttendance.map((record) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      record.status == AttendanceStatus.present
                                          ? Colors.white
                                          : Colors.red,
                                  border: Border.all(
                                    color:
                                        record.status == AttendanceStatus.present
                                            ? Colors.grey.shade400
                                            : Colors.red.shade700,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  record.memberName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        record.status == AttendanceStatus.present
                                            ? Colors.black
                                            : Colors.white,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeSettings.backgroundColor2,
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(width: 80),
                            ...controller.currentTeams.map(
                              (team) => Expanded(
                                child: Center(
                                  child: Text(
                                    team.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: themeSettings.fontColor1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 80),
                          ],
                        ),
                      ),
                      if (controller.currentLeftLabels.isEmpty &&
                          controller.currentTeams.every((t) => t.members.isEmpty))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              'メンバーとラベルを追加してください',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else
                        ...List.generate(controller.currentLeftLabels.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    i < controller.currentLeftLabels.length
                                        ? controller.currentLeftLabels[i]
                                        : '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: themeSettings.fontColor1,
                                    ),
                                  ),
                                ),
                                ...controller.currentTeams.map(
                                  (team) => Expanded(
                                    child: Center(
                                      child: MemberCard(
                                        name:
                                            i < team.members.length &&
                                                    team.members[i].isNotEmpty
                                                ? team.members[i]
                                                : '未設定',
                                        attendanceStatus: controller.getMemberAttendanceStatus(
                                          // `controller.` を追加
                                          i < team.members.length &&
                                                  team.members[i].isNotEmpty
                                              ? team.members[i]
                                              : '未設定',
                                        ),
                                        onTap: () {
                                          if (i < team.members.length &&
                                              team.members[i].isNotEmpty) {
                                            controller.showAttendanceDialog(
                                              context, // contextを渡す
                                              team.members[i],
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    i < controller.currentRightLabels.length
                                        ? controller.currentRightLabels[i]
                                        : '',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: themeSettings.fontColor1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                if (controller.canEditAssignment == true) ...[
                  if (controller.developerMode)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'デバッグ: 編集権限=${controller.canEditAssignment}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ElevatedButton(
                    onPressed:
                        isButtonDisabled ? null : controller.shuffleAssignments,
                    child: Text(() {
                      if (todayIsWeekend && !controller.developerMode) return '土日は休み';
                      if (controller.assignedToday) return '今日はすでに決定済み';
                      if (controller.shuffling) return 'シャッフル中...';
                      return '今日の担当を決める';
                    }()),
                  ),
                ] else
                  SizedBox.shrink(),
                SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 