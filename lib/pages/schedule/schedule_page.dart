import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/theme_settings.dart';
import '../../models/roast_break_time.dart';
import '../roast/roast_scheduler_tab.dart';
import 'today_schedule.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RoastBreakTime> _roastBreakTimes = [];
  void Function()? _onEditTimeLabels;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadRoastBreakTimes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoastBreakTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('roastBreakTimes');
      if (jsonStr != null) {
        final list = (json.decode(jsonStr) as List)
            .map((e) => RoastBreakTime.fromJson(e))
            .toList();
        setState(() {
          _roastBreakTimes = list;
        });
      }
    } catch (e) {
      print('SchedulePage: 休憩時間読み込みエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.local_fire_department, color: themeSettings.iconColor),
              SizedBox(width: 8),
              Text(
                'スケジュール管理',
                style: TextStyle(
                  color: themeSettings.appBarTextColor,
                  fontSize: 20 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
            ],
          ),
          actions: [
            if (_tabController.index == 0)
              IconButton(
                icon: Icon(Icons.edit, color: themeSettings.iconColor),
                tooltip: '時間ラベルを編集',
                onPressed: () {
                  if (_onEditTimeLabels != null) _onEditTimeLabels!();
                },
              ),
          ],
          backgroundColor: themeSettings.appBarColor,
          iconTheme: IconThemeData(color: themeSettings.iconColor),
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
                  horizontal: (6 * themeSettings.fontSizeScale).clamp(2.0, 8.0),
                ),
                tabs: [
                  Tab(
                    child: Text(
                      '本日のスケジュール',
                      style: TextStyle(
                        fontSize: (16 * themeSettings.fontSizeScale).clamp(
                          10.0,
                          16.0,
                        ),
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
                        fontSize: (16 * themeSettings.fontSizeScale).clamp(
                          10.0,
                          16.0,
                        ),
                        fontWeight: FontWeight.w600,
                        fontFamily: themeSettings.fontFamily,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
                labelColor: themeSettings.fontColor1,
                unselectedLabelColor: themeSettings.fontColor1.withOpacity(0.7),
                indicatorColor: themeSettings.buttonColor,
                indicatorWeight: 3,
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // --- 本日のスケジュールタブ ---
            TodaySchedule(onEditTimeLabels: (cb) => _onEditTimeLabels = cb),
            // --- ローストスケジュールタブ ---
            RoastSchedulerTab(breakTimes: _roastBreakTimes),
          ],
        ),
      ),
    );
  }
}
