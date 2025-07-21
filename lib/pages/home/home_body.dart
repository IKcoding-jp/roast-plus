import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_gamification_provider.dart';
import '../../services/attendance_firestore_service.dart';
import '../../models/attendance_models.dart';
import '../../app.dart' show mainScaffoldKey;
import 'home_header.dart';
import 'home_feature_section.dart';
import 'home_feature_card.dart';

/// ホーム画面のメインコンテンツ
class HomeBody extends StatefulWidget {
  final ThemeSettings themeSettings;

  const HomeBody({super.key, required this.themeSettings});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  // 折りたたみ状態を管理
  final Map<String, bool> _expandedSections = {
    'business': false, // デフォルトで何も開かない
    'record': false,
    'growth': false,
    'support': false,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          HomeHeader(themeSettings: widget.themeSettings),
          SizedBox(height: 24),

          // 焙煎業務セクション
          HomeFeatureSection(
            themeSettings: widget.themeSettings,
            title: '焙煎業務',
            icon: Icons.work,
            accentColor: Color(0xFF8B4513), // 中煎りのコーヒー豆のようなブラウン
            isExpanded: _expandedSections['business']!,
            onToggle: () => _toggleSection('business'),
            children: _buildBusinessFeatures(),
          ),
          SizedBox(height: 24),

          // 記録セクション
          HomeFeatureSection(
            themeSettings: widget.themeSettings,
            title: '記録',
            icon: Icons.assessment,
            accentColor: Colors.blue.shade600,
            isExpanded: _expandedSections['record']!,
            onToggle: () => _toggleSection('record'),
            children: _buildRecordFeatures(),
          ),
          SizedBox(height: 24),

          // 功績と成長セクション
          HomeFeatureSection(
            themeSettings: widget.themeSettings,
            title: '功績と成長',
            icon: Icons.emoji_events,
            accentColor: Color(0xFFD4AF37), // 王冠やトロフィーを連想するゴールド
            isExpanded: _expandedSections['growth']!,
            onToggle: () => _toggleSection('growth'),
            children: _buildGrowthFeatures(),
          ),
          SizedBox(height: 24),

          // サポート・設定セクション
          HomeFeatureSection(
            themeSettings: widget.themeSettings,
            title: 'サポート・設定',
            icon: Icons.settings,
            accentColor: Color(0xFF757575), // より濃いグレーに変更
            isExpanded: _expandedSections['support']!,
            onToggle: () => _toggleSection('support'),
            children: _buildSupportFeatures(),
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  /// セクションの折りたたみ状態を切り替え
  void _toggleSection(String sectionKey) {
    setState(() {
      _expandedSections[sectionKey] = !_expandedSections[sectionKey]!;
    });
  }

  /// 焙煎業務カードを構築
  List<HomeFeatureCard> _buildBusinessFeatures() {
    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎タイマー',
        icon: Icons.timer,
        onTap: () => _switchToBottomNavTab(0),
        isImportant: true, // 重要機能
        customColor: Color(0xFF8B4513), // 濃いブラウン
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎記録入力',
        icon: Icons.edit_note,
        onTap: () => Navigator.pushNamed(context, '/roast_record'),
        isImportant: true, // 重要機能
        customColor: Color(0xFF8B4513), // 濃いブラウン
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎分析',
        icon: Icons.insights,
        onTap: () => Navigator.pushNamed(context, '/roast_analysis'),
        customColor: Colors.orange.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎記録一覧',
        icon: Icons.analytics,
        onTap: () => Navigator.pushNamed(context, '/roast_record_list'),
        customColor: Colors.orange.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '担当表',
        icon: Icons.group,
        onTap: () => _switchToBottomNavTab(4),
        badge: _buildAttendanceBadge(),
        customColor: Colors.blue.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'スケジュール',
        icon: Icons.schedule,
        onTap: () => _switchToBottomNavTab(1),
        customColor: Colors.blue.shade600,
      ),
    ];
  }

  /// 記録機能カードを構築
  List<HomeFeatureCard> _buildRecordFeatures() {
    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'カレンダー',
        icon: Icons.calendar_today,
        onTap: () => Navigator.pushNamed(context, '/calendar'),
        customColor: Colors.indigo.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'ドリップパックカウンター',
        icon: Icons.add_circle_outline,
        onTap: () => _switchToBottomNavTab(3),
        customColor: Colors.orange.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'メモ・TODO',
        icon: Icons.edit_note,
        onTap: () => Navigator.pushNamed(context, '/todo'),
        customColor: Colors.teal.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '電卓',
        icon: Icons.calculate,
        onTap: () => Navigator.pushNamed(context, '/calculator'),
        customColor: Colors.grey.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '作業状況記録',
        icon: Icons.work_outline,
        onTap: () => Navigator.pushNamed(context, '/work_progress'),
        customColor: Colors.green.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '試飲感想記録',
        icon: Icons.local_cafe,
        onTap: () => Navigator.pushNamed(context, '/tasting'),
        customColor: Color(0xFF6F4E37), // コーヒー色（セピアブラウン）
      ),
    ];
  }

  /// 功績と成長機能カードを構築
  List<HomeFeatureCard> _buildGrowthFeatures() {
    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'グループ',
        icon: Icons.group,
        onTap: () => Navigator.pushNamed(context, '/group_info'),
        customColor: Colors.blue.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'バッジ・実績',
        icon: Icons.military_tech,
        onTap: () => Navigator.pushNamed(context, '/badge_list'),
        customColor: Colors.amber.shade600,
      ),
    ];
  }

  /// サポート・設定機能カードを構築
  List<HomeFeatureCard> _buildSupportFeatures() {
    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '使い方',
        icon: Icons.help_outline,
        onTap: () => Navigator.pushNamed(context, '/help'),
        customColor: Colors.cyan.shade600,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '設定',
        icon: Icons.settings,
        onTap: () => Navigator.pushNamed(context, '/settings'),
        customColor: Colors.grey.shade600,
      ),
    ];
  }

  /// 出勤状態バッジを構築
  Widget _buildAttendanceBadge() {
    return FutureBuilder<bool>(
      future: _checkTodayAttendance(),
      builder: (context, snapshot) {
        final isAttended = snapshot.data ?? false;

        if (!isAttended) return SizedBox.shrink();

        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.check, color: Colors.white, size: 10),
        );
      },
    );
  }

  /// ボトムナビゲーションタブに切り替え
  void _switchToBottomNavTab(int index) {
    final mainScaffoldState = mainScaffoldKey.currentState;
    if (mainScaffoldState != null && mainScaffoldState.mounted) {
      mainScaffoldState.switchToTab(index);
    }
  }

  /// 今日の出勤記録をチェック
  Future<bool> _checkTodayAttendance() async {
    if (!mounted) return false;

    try {
      final records = await AttendanceFirestoreService.getTodayAttendance();
      return records.isNotEmpty &&
          records.any((record) => record.status == AttendanceStatus.present);
    } catch (e) {
      return false;
    }
  }
}
