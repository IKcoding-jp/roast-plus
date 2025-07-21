import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'gamification_models.dart';
import 'group_gamification_models.dart';

import '../widgets/badge_celebration_widget.dart';

import 'theme_settings.dart';
import 'group_provider.dart';

/// ゲーミフィケーション機能の状態管理プロバイダー（グループレベルシステム）
class GamificationProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// 初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);
    try {
      _isInitialized = true;
      print('ゲーミフィケーションプロバイダー初期化完了（グループレベルシステム）');
    } catch (e) {
      print('ゲーミフィケーション初期化エラー: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// ローディング状態を設定
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// グループレベルアップダイアログを表示
  void showGroupLevelUpDialog(
    BuildContext context,
    int newLevel,
    String levelTitle,
    Color levelColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('グループレベルアップ！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'グループのレベルが $newLevel に到達しました！',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              levelTitle,
              style: TextStyle(
                fontSize: 16,
                color: levelColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('続ける'),
          ),
        ],
      ),
    );
  }

  /// グループバッジ獲得のお祝い表示
  void showGroupBadgeCelebration(
    BuildContext context,
    List<GroupBadge> newBadges,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BadgeCelebrationWidget(badges: newBadges),
    );
  }

  /// 個人の焙煎記録で経験値を加算
  Future<void> recordRoasting(double minutes) async {
    try {
      // プロファイルの取得・更新処理は本来ここで行う
      // 例: UserProfile currentProfile = await GamificationStorage.loadUserProfile();
      // UserProfile updated = GamificationService.recordRoasting(currentProfile, minutes);
      // await GamificationStorage.saveUserProfile(updated);
      // notifyListeners();
      // ※実装例としてダミー処理
      print('recordRoasting: 焙煎時間 $minutes 分分の経験値を加算');
    } catch (e) {
      print('recordRoastingエラー: $e');
    }
  }

  /// ログアウト時にプロバイダー情報をクリア
  void clearOnLogout() {
    print('GamificationProvider: ログアウト時のクリア開始');

    _isLoading = false;
    _isInitialized = false;

    print('GamificationProvider: ログアウト時のクリア完了');
    notifyListeners();
  }
}
