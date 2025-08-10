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
                      subtitle: 'ドリップ、テイスティング、計算機、TODO',
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
                    subtitle: 'ドリップ、テイスティング、計算機、TODO',
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
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
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
                        color: widget.themeSettings.fontColor1.withOpacity(0.7),
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
        customColor: Color(0xFFE65100), // オレンジ（火・熱を表現）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎記録入力',
        icon: Icons.edit_note,
        onTap: () => Navigator.pushNamed(context, '/roast_record'),
        isImportant: true, // 重要機能
        customColor: Color(0xFF8D6E63), // ブラウン（コーヒー豆）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎分析',
        icon: Icons.insights,
        onTap: () => Navigator.pushNamed(context, '/roast_analysis'),
        customColor: Color(0xFF6A4C93), // パープル（分析・データ）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '焙煎記録一覧',
        icon: Icons.analytics,
        onTap: () => Navigator.pushNamed(context, '/roast_record_list'),
        customColor: Color(0xFF795548), // ダークブラウン（記録）
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
        customColor: Color(0xFF1976D2), // ブルー（チームワーク）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'スケジュール',
        icon: Icons.schedule,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SchedulePage()),
        ),
        customColor: Color(0xFF388E3C), // グリーン（計画・管理）
      ),
    ];
  }

  /// 記録機能カードを構築
  List<HomeFeatureCard> _buildRecordFeatures() {
    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'ドリップカウンター',
        icon: Icons.local_cafe,
        onTap: () => Navigator.pushNamed(context, '/drip'),
        isImportant: true, // 重要機能
        customColor: Color(0xFF6F4E37), // コーヒー色（ドリップ）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'テイスティング記録',
        icon: Icons.restaurant_menu,
        onTap: () => Navigator.pushNamed(context, '/tasting'),
        customColor: Color(0xFFD81B60), // ピンク（味覚・感覚）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '作業進捗',
        icon: Icons.trending_up,
        onTap: () => Navigator.pushNamed(context, '/work_progress'),
        customColor: Color(0xFF00ACC1), // シアン（進歩・成長）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'カレンダー',
        icon: Icons.calendar_today,
        onTap: () => Navigator.pushNamed(context, '/calendar'),
        customColor: Color(0xFF7B1FA2), // ディープパープル（時間管理）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '計算機',
        icon: Icons.calculate,
        onTap: () => Navigator.pushNamed(context, '/calculator'),
        customColor: Color(0xFF424242), // ダークグレー（計算・論理）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'TODO',
        icon: Icons.checklist,
        onTap: () => Navigator.pushNamed(context, '/todo'),
        customColor: Color(0xFF1565C0), // インディゴ（タスク管理）
      ),
    ];
  }

  /// 功績と成長カードを構築
  List<HomeFeatureCard> _buildGrowthFeatures() {
    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'グループ情報',
        icon: Icons.group_work,
        onTap: () => Navigator.pushNamed(context, '/group_info'),
        customColor: Color(0xFFFF9800), // オレンジ（コミュニティ）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: 'バッジ一覧',
        icon: Icons.emoji_events,
        onTap: () => Navigator.pushNamed(context, '/badges'),
        customColor: Color(0xFFFFD700), // ゴールド（達成・栄誉）
      ),
    ];
  }

  /// サポート・設定カードを構築
  List<HomeFeatureCard> _buildSupportFeatures() {
    return [
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '使い方ガイド',
        icon: Icons.help_outline,
        onTap: () => Navigator.pushNamed(context, '/help'),
        customColor: Color(0xFF9C27B0), // パープル（学習・サポート）
      ),
      HomeFeatureCard(
        themeSettings: widget.themeSettings,
        title: '設定',
        icon: Icons.settings,
        onTap: () => Navigator.pushNamed(context, '/settings'),
        customColor: Color(0xFF607D8B), // ブルーグレー（設定・調整）
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
