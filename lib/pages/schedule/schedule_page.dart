import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../models/theme_settings.dart';
import '../../models/roast_break_time.dart';
import '../../models/group_provider.dart';
import '../../services/encrypted_local_storage_service.dart';
import 'today_schedule.dart';
import 'roast_scheduler_tab.dart';
import 'schedule_time_label_edit_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RoastBreakTime> _roastBreakTimes = [];
  VoidCallback? _openTimeLabelEditCallback; // 時間ラベル編集コールバック

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoastBreakTimes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoastBreakTimes() async {
    try {
      final jsonStr = await EncryptedLocalStorageService.getString(
        'roastBreakTimes',
      );
      if (jsonStr != null) {
        final list = (json.decode(jsonStr) as List)
            .map((e) => RoastBreakTime.fromJson(e))
            .toList();
        setState(() {
          _roastBreakTimes = list;
        });
      }
    } catch (e) {
      debugPrint('SchedulePage: 休憩時間読み込みエラー: $e');
    }
  }

  void _openTimeLabelEdit() {
    if (_openTimeLabelEditCallback != null) {
      _openTimeLabelEditCallback!();
    } else {
      // コールバックが設定されていない場合は、直接時間ラベル編集ページを開く
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleTimeLabelEditPage(
            labels: [],
            onLabelsChanged: (labels) async {
              // ラベル変更時の処理（必要に応じて実装）
            },
          ),
        ),
      );
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
                Icon(Icons.pending_actions, color: themeSettings.iconColor),
                SizedBox(width: 8),
                Text(
                  'スケジュール管理',
                  style: TextStyle(
                    color: themeSettings.appBarTextColor,
                    fontSize: kIsWeb ? 22 : 20 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
                SizedBox(width: 8),
                // グループアイコンをタイトルの右側に配置
                Consumer<GroupProvider>(
                  builder: (context, groupProvider, child) {
                    if (groupProvider.groups.isNotEmpty) {
                      return Container(
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
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],
            ),
            backgroundColor: themeSettings.appBarColor,
            iconTheme: IconThemeData(color: themeSettings.iconColor),
            actions: [
              // 時間ラベル編集ボタンをAppBarに追加（Web版では非表示、本日のスケジュールタブの時のみ表示）
              if (!kIsWeb)
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    return _tabController.index == 0
                        ? IconButton(
                            icon: Icon(
                              Icons.label,
                              color: themeSettings.iconColor,
                            ),
                            onPressed: _openTimeLabelEdit,
                            tooltip: '時間ラベルを編集',
                          )
                        : SizedBox.shrink();
                  },
                ),
            ],
            bottom: kIsWeb
                ? null // Web版ではTabBarを非表示
                : PreferredSize(
                    preferredSize: Size.fromHeight(kToolbarHeight),
                    child: Container(
                      decoration: BoxDecoration(
                        color: themeSettings.cardBackgroundColor,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: false,
                        labelPadding: EdgeInsets.symmetric(
                          horizontal: (12 * themeSettings.fontSizeScale).clamp(
                            4.0,
                            12.0,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: (12 * themeSettings.fontSizeScale).clamp(
                            4.0,
                            12.0,
                          ),
                        ),
                        indicatorPadding: EdgeInsets.symmetric(
                          horizontal: (6 * themeSettings.fontSizeScale).clamp(
                            2.0,
                            8.0,
                          ),
                        ),
                        tabs: [
                          Tab(
                            child: Text(
                              '本日のスケジュール',
                              style: TextStyle(
                                fontSize: (16 * themeSettings.fontSizeScale)
                                    .clamp(10.0, 16.0),
                                fontWeight: FontWeight.w600,
                                fontFamily: themeSettings.fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Tab(
                            child: Text(
                              'ローストスケジュール',
                              style: TextStyle(
                                fontSize: (16 * themeSettings.fontSizeScale)
                                    .clamp(10.0, 16.0),
                                fontWeight: FontWeight.w600,
                                fontFamily: themeSettings.fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                        labelColor: themeSettings.fontColor1,
                        unselectedLabelColor: themeSettings.fontColor1
                            .withValues(alpha: 0.7),
                        indicatorColor: themeSettings.buttonColor,
                        indicatorWeight: 3,
                      ),
                    ),
                  ),
          ),
          body: kIsWeb
              ? Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 1400, // Web版ではより広い最大幅
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 本日のスケジュール（左側）
                          Expanded(
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: themeSettings.cardBackgroundColor,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // セクションヘッダー
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: themeSettings.buttonColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.today,
                                          color: themeSettings.buttonColor,
                                          size: 24,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          '本日のスケジュール',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: themeSettings.fontColor1,
                                          ),
                                        ),
                                        Spacer(),
                                        // Web版での時間ラベル編集ボタン
                                        if (kIsWeb)
                                          IconButton(
                                            icon: Icon(
                                              Icons.label,
                                              color: themeSettings.iconColor,
                                              size: 20,
                                            ),
                                            onPressed: _openTimeLabelEdit,
                                            tooltip: '時間ラベルを編集',
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // 本日のスケジュールコンテンツ
                                  Expanded(
                                    child: TodaySchedule(
                                      onEditTimeLabels: (callback) {
                                        _openTimeLabelEditCallback = callback;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 24), // 左右の間隔
                          // ローストスケジュール（右側）
                          Expanded(
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: themeSettings.cardBackgroundColor,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // セクションヘッダー
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: themeSettings.buttonColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          color: themeSettings.buttonColor,
                                          size: 24,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'ローストスケジュール',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: themeSettings.fontColor1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ローストスケジュールコンテンツ
                                  Expanded(
                                    child: RoastSchedulerTab(
                                      breakTimes: _roastBreakTimes,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // --- 本日のスケジュールタブ ---
                    TodaySchedule(
                      onEditTimeLabels: (callback) {
                        _openTimeLabelEditCallback = callback;
                      },
                    ),
                    // --- ローストスケジュールタブ ---
                    RoastSchedulerTab(breakTimes: _roastBreakTimes),
                  ],
                ),
        );
      },
    );
  }
}
