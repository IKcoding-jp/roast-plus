import 'package:flutter/material.dart';
import 'group_gamification_models.dart';

import '../widgets/badge_celebration_widget.dart';
import 'dart:developer' as developer;

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
      developer.log(
        'ゲーミフィケーションプロバイダー初期化完了（グループレベルシステム）',
        name: 'GamificationProvider',
      );
    } catch (e) {
      developer.log('ゲーミフィケーション初期化エラー: $e', name: 'GamificationProvider');
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
      developer.log(
        'recordRoasting: 焙煎時間 $minutes 分分の経験値を加算',
        name: 'GamificationProvider',
      );
    } catch (e) {
      developer.log('recordRoastingエラー: $e', name: 'GamificationProvider');
    }
  }

  /// ログアウト時にプロバイダー情報をクリア
  void clearOnLogout() {
    developer.log(
      'GamificationProvider: ログアウト時のクリア開始',
      name: 'GamificationProvider',
    );

    _isLoading = false;
    _isInitialized = false;

    developer.log(
      'GamificationProvider: ログアウト時のクリア完了',
      name: 'GamificationProvider',
    );
    notifyListeners();
  }
}
