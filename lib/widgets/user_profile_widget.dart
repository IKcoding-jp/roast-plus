import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/theme_settings.dart';
import '../models/gamification_provider.dart';
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
        return Card(
          margin: EdgeInsets.zero,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white.withValues(alpha: 0.95),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
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

  /// バッジ一覧へのクイックアクセス
  Widget _buildBadgeQuickAccess(
    BuildContext context,
    GamificationProvider provider,
    ThemeSettings themeSettings,
  ) {
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
          'バッジ一覧を見る',
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
