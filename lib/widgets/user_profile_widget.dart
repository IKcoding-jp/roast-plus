import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/theme_settings.dart';
import '../models/gamification_provider.dart';
import '../models/gamification_models.dart';
import '../pages/gamification/badge_list_page.dart';

/// ドロワー用ユーザープロフィールウィジェット
class UserProfileWidget extends StatelessWidget {
  const UserProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.brown.shade600, Colors.brown.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user != null) ...[
              _buildUserSection(user, themeSettings),
              SizedBox(height: 16),
            ],
            _buildGamificationSection(themeSettings),
          ],
        ),
      ),
    );
  }

  /// ユーザー情報セクション（Googleアカウント）
  Widget _buildUserSection(User user, ThemeSettings themeSettings) {
    return Row(
      children: [
        // プロフィール画像
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: user.photoURL != null
                ? Image.network(
                    user.photoURL!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
          ),
        ),
        SizedBox(width: 16),
        // ユーザー名とメール
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName ?? 'ユーザー',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  fontFamily: themeSettings.fontFamily,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                user.email ?? '',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12 * themeSettings.fontSizeScale,
                  fontFamily: themeSettings.fontFamily,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// デフォルトアバター
  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.brown.shade300, Colors.brown.shade600],
        ),
      ),
      child: Icon(Icons.person, color: Colors.white, size: 30),
    );
  }

  /// ゲーミフィケーションセクション
  Widget _buildGamificationSection(ThemeSettings themeSettings) {
    return Consumer<GamificationProvider>(
      builder: (context, gamificationProvider, child) {
        final profile = gamificationProvider.userProfile;

        return Card(
          margin: EdgeInsets.zero,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white.withOpacity(0.95),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // レベルと称号
                _buildLevelSection(
                  profile,
                  gamificationProvider,
                  themeSettings,
                ),
                SizedBox(height: 12),
                // 経験値バー
                _buildExperienceBar(profile, themeSettings),
                SizedBox(height: 12),
                // 統計情報
                _buildStatsSection(profile, themeSettings),
                SizedBox(height: 12),
                // バッジ一覧ボタン
                _buildBadgeQuickAccess(
                  context,
                  gamificationProvider,
                  themeSettings,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// レベルと称号セクション
  Widget _buildLevelSection(
    UserProfile profile,
    GamificationProvider provider,
    ThemeSettings themeSettings,
  ) {
    return Row(
      children: [
        // レベルアイコン
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                provider.levelColor.withOpacity(0.7),
                provider.levelColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: provider.levelColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${profile.level}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        // レベルタイトルと称号
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lv.${profile.level}',
                style: TextStyle(
                  color: themeSettings.fontColor1,
                  fontSize: 16 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              Text(
                provider.levelTitle,
                style: TextStyle(
                  color: provider.levelColor,
                  fontSize: 14 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.w600,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              if (profile.latestBadge != null) ...[
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      profile.latestBadge!.icon,
                      size: 16,
                      color: profile.latestBadge!.color,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        profile.latestBadge!.name,
                        style: TextStyle(
                          color: profile.latestBadge!.color,
                          fontSize: 12 * themeSettings.fontSizeScale,
                          fontWeight: FontWeight.w500,
                          fontFamily: themeSettings.fontFamily,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 経験値バー
  Widget _buildExperienceBar(UserProfile profile, ThemeSettings themeSettings) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EXP',
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 12 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.w600,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            Text(
              '${profile.experiencePoints} / ${profile.experiencePoints + profile.experienceToNextLevel}',
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 12 * themeSettings.fontSizeScale,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade300,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: profile.levelProgress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          '次のレベルまで ${profile.experienceToNextLevel}XP',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10 * themeSettings.fontSizeScale,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
      ],
    );
  }

  /// 統計情報セクション
  Widget _buildStatsSection(UserProfile profile, ThemeSettings themeSettings) {
    return IntrinsicHeight(
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.work,
            label: '出勤',
            value: '${profile.stats.attendanceDays}日',
            color: Colors.blue,
            themeSettings: themeSettings,
          ),
          VerticalDivider(color: Colors.grey.shade400, thickness: 1),
          _buildStatItem(
            icon: Icons.local_fire_department,
            label: '焙煎',
            value: '${profile.stats.totalRoastTimeHours.toStringAsFixed(1)}h',
            color: Colors.red,
            themeSettings: themeSettings,
          ),
          VerticalDivider(color: Colors.grey.shade400, thickness: 1),
          _buildStatItem(
            icon: Icons.coffee,
            label: 'ドリップ',
            value: '${profile.stats.dripPackCount}個',
            color: Colors.brown,
            themeSettings: themeSettings,
          ),
        ],
      ),
    );
  }

  /// 統計項目ウィジェット
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeSettings themeSettings,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: themeSettings.fontColor1,
              fontSize: 12 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10 * themeSettings.fontSizeScale,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  /// バッジ一覧へのクイックアクセス
  Widget _buildBadgeQuickAccess(
    BuildContext context,
    GamificationProvider provider,
    ThemeSettings themeSettings,
  ) {
    final profile = provider.userProfile;
    final earnedBadges = profile.badges.length;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BadgeListPage()),
          );
        },
        icon: Icon(Icons.emoji_events, size: 18, color: Colors.white),
        label: Text(
          'バッジ $earnedBadges個獲得 - 一覧を見る',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.w600,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.brown.shade600,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}
