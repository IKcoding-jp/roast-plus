import 'package:flutter/material.dart';
import '../../models/theme_settings.dart';
import '../../services/attendance_firestore_service.dart';
import '../../models/attendance_models.dart';
import '../../utils/web_ui_utils.dart';
import 'home_header.dart';
import 'home_feature_section.dart';
import 'home_feature_card.dart';
import '../roast/roast_timer_page.dart';
import '../business/assignment_board_page.dart';
import '../schedule/schedule_page.dart';

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
    // WEB版とモバイル版で異なるレイアウトを適用
    if (WebUIUtils.isWeb) {
      return _buildWebLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  /// WEB版用のレイアウトを構築
  Widget _buildWebLayout() {
    final isDesktop = WebUIUtils.isDesktop(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) ...[
            // デスクトップ: 縦4列レイアウト
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第1列: 業務セクション
                  Expanded(
                    child: _buildWebSection(
                      title: '業務',
                      subtitle: '焙煎とスケジュール管理',
                      icon: Icons.work,
                      accentColor: Color(0xFF8B4513),
                      children: _buildBusinessFeatures(),
                    ),
                  ),
                  SizedBox(width: 16),

                  // 第2列: 記録セクション
                  Expanded(
                    child: _buildWebSection(
                      title: '記録',
                      subtitle: '作業記録',
                      icon: Icons.assignment,
                      accentColor: Colors.blue.shade700,
                      children: _buildRecordFeatures(),
                    ),
                  ),
                  SizedBox(width: 16),

                  // 第3列: 功績と成長セクション
                  Expanded(
                    child: _buildWebSection(
                      title: '功績と成長',
                      subtitle: 'バッジとグループ情報',
                      icon: Icons.emoji_events,
                      accentColor: Color(0xFFD4AF37),
                      children: _buildGrowthFeatures(),
                    ),
                  ),
                  SizedBox(width: 16),

                  // 第4列: サポート・設定セクション
                  Expanded(
                    child: _buildWebSection(
                      title: 'サポート・設定',
                      subtitle: '設定とヘルプ',
                      icon: Icons.settings,
                      accentColor: Color(0xFF757575),
                      children: _buildSupportFeatures(),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // タブレット・モバイル: 1列レイアウト
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildWebSection(
                    title: '業務',
                    subtitle: '焙煎とスケジュール管理',
                    icon: Icons.work,
                    accentColor: Color(0xFF8B4513),
                    children: _buildBusinessFeatures(),
                  ),
                  SizedBox(height: 20),

                  _buildWebSection(
                    title: '記録',
                    subtitle: '作業記録',
                    icon: Icons.assignment,
                    accentColor: Colors.blue.shade700,
                    children: _buildRecordFeatures(),
                  ),
                  SizedBox(height: 20),

                  _buildWebSection(
                    title: '功績と成長',
                    subtitle: 'バッジとグループ情報',
                    icon: Icons.emoji_events,
                    accentColor: Color(0xFFD4AF37),
                    children: _buildGrowthFeatures(),
                  ),
                  SizedBox(height: 20),

                  _buildWebSection(
                    title: 'サポート・設定',
                    subtitle: '設定とヘルプ',
                    icon: Icons.settings,
                    accentColor: Color(0xFF757575),
                    children: _buildSupportFeatures(),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 20),
        ],
      ),
    );
  }

  /// WEB版用のセクションを構築
  Widget _buildWebSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<HomeFeatureCard> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16 * WebUIUtils.getFontSizeScale(context),
                        fontWeight: FontWeight.bold,
                        color: widget.themeSettings.fontColor1,
                        fontFamily: widget.themeSettings.fontFamily,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12 * WebUIUtils.getFontSizeScale(context),
                        color: widget.themeSettings.fontColor1.withValues(
                          alpha: 0.7,
                        ),
                        fontFamily: widget.themeSettings.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        // グリッドレイアウトでカードを表示
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: children,
        ),
      ],
    );
  }

  /// モバイル版用のレイアウトを構築（従来の実装）
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          HomeHeader(themeSettings: widget.themeSettings),
          SizedBox(height: 24),

          // 業務セクション
          HomeFeatureSection(
            themeSettings: widget.themeSettings,
            title: '業務',
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

  /// 業務機能カードを構築
  List<HomeFeatureCard> _buildBusinessFeatures() {
    // 業務セクション統一色（オレンジ系）
    const businessColor = Color(0xFFE65100); // オレンジ（火・熱を表現）

    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎タイマー',
        icon: Icons.timer,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoastTimerPage()),
        ),
        isImportant: true, // 重要機能
        customColor: businessColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎記録入力',
        icon: Icons.edit_note,
        onTap: () => Navigator.pushNamed(context, '/roast_record'),
        isImportant: true, // 重要機能
        customColor: businessColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎分析',
        icon: Icons.insights,
        onTap: () => Navigator.pushNamed(context, '/roast_analysis'),
        customColor: businessColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎記録一覧',
        icon: Icons.analytics,
        onTap: () => Navigator.pushNamed(context, '/roast_record_list'),
        customColor: businessColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '担当表',
        icon: Icons.group,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AssignmentBoard()),
        ),
        badge: _buildAttendanceBadge(),
        customColor: businessColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'スケジュール',
        icon: Icons.schedule,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SchedulePage()),
        ),
        customColor: businessColor,
      ),
    ];
  }

  /// 記録機能カードを構築
  List<HomeFeatureCard> _buildRecordFeatures() {
    // 記録セクション統一色（ブルー系）
    const recordColor = Color(0xFF1976D2); // ブルー（記録・データを表現）

    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'ドリップカウンター',
        icon: Icons.add_circle_outline,
        onTap: () => Navigator.pushNamed(context, '/drip'),
        isImportant: true, // 重要機能
        customColor: recordColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '試飲感想記録',
        icon: Icons.coffee,
        onTap: () => Navigator.pushNamed(context, '/tasting'),
        customColor: recordColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '作業進捗',
        icon: Icons.trending_up,
        onTap: () => Navigator.pushNamed(context, '/work_progress'),
        customColor: recordColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'カレンダー',
        icon: Icons.calendar_today,
        onTap: () => Navigator.pushNamed(context, '/calendar'),
        customColor: recordColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '計算機',
        icon: Icons.calculate,
        onTap: () => Navigator.pushNamed(context, '/calculator'),
        customColor: recordColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'メモ・TODO',
        icon: Icons.checklist,
        onTap: () => Navigator.pushNamed(context, '/todo'),
        customColor: recordColor,
      ),
    ];
  }

  /// 功績と成長カードを構築
  List<HomeFeatureCard> _buildGrowthFeatures() {
    // 功績と成長セクション統一色（ゴールド系）
    const growthColor = Color(0xFFD4AF37); // ゴールド（達成・栄誉を表現）

    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'グループ情報',
        icon: Icons.group_work,
        onTap: () => Navigator.pushNamed(context, '/group_info'),
        customColor: growthColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'バッジ一覧',
        icon: Icons.emoji_events,
        onTap: () => Navigator.pushNamed(context, '/badges'),
        customColor: growthColor,
      ),
    ];
  }

  /// サポート・設定カードを構築
  List<HomeFeatureCard> _buildSupportFeatures() {
    // サポート・設定セクション統一色（グレー系）
    const supportColor = Color(0xFF757575); // グレー（サポート・設定を表現）

    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '使い方ガイド',
        icon: Icons.help_outline,
        onTap: () => Navigator.pushNamed(context, '/help'),
        customColor: supportColor,
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '設定',
        icon: Icons.settings,
        onTap: () => Navigator.pushNamed(context, '/settings'),
        customColor: supportColor,
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
                color: Colors.green.withValues(alpha: 0.3),
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
