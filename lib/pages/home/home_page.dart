import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_gamification_provider.dart';
import '../../models/group_gamification_models.dart';
import '../../widgets/group_celebration_helper.dart';
import '../group/group_deleted_page.dart';
import '../../widgets/lottie_animation_widget.dart';
import 'home_body.dart';

/// ホーム画面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  GroupProvider? _groupProvider;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 安全にプロバイダーの参照を保存
    try {
      _groupProvider = Provider.of<GroupProvider>(context, listen: false);

      // 初回読み込み（一度だけ）
      if (_isLoading && _groupProvider?.hasGroup == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _isLoading = false;
          });
        });
      }

      // グループ作成後のバッジ獲得演出をチェック
      _checkGroupCreationCelebration();
    } catch (e) {
      // プロバイダー取得エラー: $e
    }
  }

  @override
  void dispose() {
    // dispose時にプロバイダーへの参照をクリア
    _groupProvider = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Consumer2<GroupProvider, GroupGamificationProvider>(
      builder: (context, groupProvider, gamificationProvider, child) {
        // グループ削除フラグをチェック
        if (groupProvider.showGroupDeletedPage) {
          // フラグをリセット
          WidgetsBinding.instance.addPostFrameCallback((_) {
            groupProvider.resetGroupDeletedPageFlag();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const GroupDeletedPage()),
            );
          });
        }

        // データ読み込み中の場合
        if (groupProvider.loading) {
          return Scaffold(
            backgroundColor: themeSettings.backgroundColor,
            appBar: AppBar(
              title: Text('ホーム'),
              backgroundColor: themeSettings.appBarColor,
              foregroundColor: themeSettings.appBarTextColor,
            ),
            body: const LoadingAnimationWidget(),
          );
        }

        // グループに参加していない場合
        if (!groupProvider.hasGroup) {
          return Scaffold(
            appBar: AppBar(
              title: Text('ホーム'),
              backgroundColor: themeSettings.appBarColor,
              foregroundColor: themeSettings.appBarTextColor,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'グループに参加すると\nホーム画面が表示されます',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/group_list');
                    },
                    child: Text('グループ一覧へ'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: themeSettings.backgroundColor,
          appBar: AppBar(
            title: Text(
              'ホーム',
              style: TextStyle(
                color: themeSettings.appBarTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: themeSettings.appBarColor,
            iconTheme: IconThemeData(color: themeSettings.appBarTextColor),
          ),
          body: _isLoading
              ? const LoadingAnimationWidget()
              : Padding(
                  padding: EdgeInsets.all(16),
                  child: HomeBody(themeSettings: themeSettings),
                ),
        );
      },
    );
  }

  /// グループ作成後のバッジ獲得演出をチェック
  void _checkGroupCreationCelebration() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);

    if (groupProvider.showGroupCreationCelebration &&
        groupProvider.newlyCreatedGroupId != null) {
      print('HomePage: グループ作成後のバッジ獲得演出を開始');

      // 少し待ってから演出を表示
      Future.delayed(Duration(milliseconds: 1000), () async {
        if (mounted) {
          await _showGroupCreationBadgeCelebration(
            groupProvider.newlyCreatedGroupId!,
          );
          // フラグをリセット
          groupProvider.resetGroupCreationCelebration();
        }
      });
    }
  }

  /// グループ作成後のバッジ獲得演出を表示
  Future<void> _showGroupCreationBadgeCelebration(String groupId) async {
    try {
      print('HomePage: グループ作成後のバッジ獲得演出の表示開始');

      // Lv.1達成バッジの条件を取得
      final level1Condition = GroupBadgeConditions.conditions
          .where((condition) => condition.badgeId == 'group_level_1')
          .firstOrNull;

      if (level1Condition != null && mounted) {
        // バッジを作成
        final level1Badge = level1Condition.createBadge(
          'group_creator',
          'グループ作成者',
        );

        // バッジ獲得演出を表示
        await GroupCelebrationHelper.showUnifiedBadgeCelebration(context, [
          level1Badge,
        ]);

        print('HomePage: グループ作成後のバッジ獲得演出の表示完了');
        print('HomePage: バッジ名: ${level1Badge.name}');
        print('HomePage: バッジID: ${level1Badge.id}');
      } else {
        print('HomePage: Lv.1達成バッジの条件が見つからないか、コンテキストが無効です');
      }
    } catch (e) {
      print('HomePage: グループ作成後のバッジ獲得演出の表示エラー: $e');
    }
  }
}
