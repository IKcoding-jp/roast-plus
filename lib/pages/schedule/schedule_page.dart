import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../services/group_data_sync_service.dart';
import '../../services/user_settings_firestore_service.dart';
import '../../utils/performance_utils.dart';
import 'today_schedule.dart';
import 'schedule_time_label_edit_page.dart';
import '../roast/roast_scheduler_tab.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _canEditSchedule = true;
  bool _canEditTimeLabels = true;
  List<String> _currentTimeLabels = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // タブが切り替わった時にUIを更新
      setState(() {});
    });
    _checkEditPermissions();
    _loadTimeLabels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 編集権限をチェック
  Future<void> _checkEditPermissions() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.hasGroup) {
        final group = groupProvider.currentGroup!;
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          final userRole = group.getMemberRole(currentUser.uid);
          final groupSettings = groupProvider.getCurrentGroupSettings();

          if (groupSettings != null) {
            final canEditSchedule = groupSettings.canEditDataType(
              'schedule',
              userRole ?? GroupRole.member,
            );
            final canEditTimeLabels = groupSettings.canEditDataType(
              'time_labels',
              userRole ?? GroupRole.member,
            );

            setState(() {
              _canEditSchedule = canEditSchedule;
              _canEditTimeLabels = canEditTimeLabels;
            });
          }
        }
      }
    } catch (e) {
      print('スケジュール編集権限チェックエラー: $e');
    }
  }

  // 時間ラベルを読み込み
  Future<void> _loadTimeLabels() async {
    try {
      final currentLabelsData = await UserSettingsFirestoreService.getSetting(
        'todaySchedule_labels',
      );
      final currentLabels = currentLabelsData is List
          ? (currentLabelsData as List).map((e) => e.toString()).toList()
          : <String>[];

      setState(() {
        _currentTimeLabels = currentLabels;
      });
    } catch (e) {
      print('時間ラベル読み込みエラー: $e');
    }
  }

  // 時間ラベル編集ページを開く
  void _openTimeLabelEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleTimeLabelEditPage(
          labels: _currentTimeLabels,
          onLabelsChanged: (newLabels) async {
            // 時間ラベルの変更を処理
            await UserSettingsFirestoreService.saveSetting(
              'todaySchedule_labels',
              newLabels,
            );

            // グループ同期
            final groupProvider = context.read<GroupProvider>();
            if (groupProvider.hasGroup) {
              try {
                await GroupDataSyncService.syncTimeLabels(
                  groupProvider.currentGroup!.id,
                  {'labels': newLabels},
                );
              } catch (e) {
                print('時間ラベル同期エラー: $e');
              }
            }
          },
        ),
      ),
    );

    // 編集ページから戻ってきたら時間ラベルを再読み込み
    if (result != null) {
      await _loadTimeLabels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeSettings>(
      builder: (context, themeSettings, child) {
        return Scaffold(
          backgroundColor: themeSettings.backgroundColor,
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.schedule, color: themeSettings.iconColor),
                SizedBox(width: 8),
                Text(
                  'スケジュール',
                  style: TextStyle(
                    color: themeSettings.appBarTextColor,
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
            backgroundColor: themeSettings.appBarColor,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: themeSettings.backgroundColor2 ?? Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelPadding: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  indicatorPadding: EdgeInsets.symmetric(horizontal: 16),
                  tabs: [
                    Tab(
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          '本日のスケジュール',
                          style: TextStyle(
                            fontSize: (16 * themeSettings.fontSizeScale).clamp(
                              14.0,
                              20.0,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    Tab(
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          'ローストスケジュール',
                          style: TextStyle(
                            fontSize: (16 * themeSettings.fontSizeScale).clamp(
                              14.0,
                              20.0,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                  labelColor: themeSettings.fontColor1,
                  unselectedLabelColor: themeSettings.fontColor1.withOpacity(
                    0.7,
                  ),
                  indicatorColor: themeSettings.buttonColor,
                  indicatorWeight: 3,
                ),
              ),
            ),
            actions: [
              // 本日のスケジュールタブが選択されている時のみラベルアイコンを表示
              if (_tabController.index == 0 && _canEditTimeLabels)
                IconButton(
                  icon: Icon(Icons.label, color: themeSettings.appBarTextColor),
                  tooltip: '時間ラベル編集',
                  onPressed: _openTimeLabelEdit,
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 今日のスケジュールタブ
              TodaySchedule(
                onEditTimeLabels: _canEditTimeLabels
                    ? (callback) => _loadTimeLabels()
                    : null,
              ),

              // ローストスケジュールタブ
              RoastSchedulerTab(breakTimes: []),
            ],
          ),
        );
      },
    );
  }
}
