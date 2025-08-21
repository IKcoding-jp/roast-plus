import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/group_gamification_provider.dart';
import '../../widgets/lottie_animation_widget.dart';
import '../../utils/web_ui_utils.dart';
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
        // グループ削除フラグをチェック（削除/脱退後は参加・招待画面へ遷移）
        if (groupProvider.showGroupDeletedPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            groupProvider.resetGroupDeletedPageFlag();
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/group_required', (route) => false);
          });
          // 一時的にローディング状態を表示
          return Scaffold(
            backgroundColor: themeSettings.backgroundColor,
            appBar: WebUIUtils.isWeb
                ? null
                : AppBar(
                    title: Text('ホーム'),
                    backgroundColor: themeSettings.appBarColor,
                    foregroundColor: themeSettings.appBarTextColor,
                  ),
            body: const LoadingAnimationWidget(),
          );
        }

        // データ読み込み中の場合
        if (groupProvider.loading) {
          return Scaffold(
            backgroundColor: themeSettings.backgroundColor,
            appBar: WebUIUtils.isWeb
                ? null
                : AppBar(
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
            appBar: WebUIUtils.isWeb
                ? null
                : AppBar(
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
          appBar: WebUIUtils.isWeb
              ? null
              : AppBar(
                  title: Text(
                    'ホーム',
                    style: TextStyle(
                      color: themeSettings.appBarTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: themeSettings.appBarColor,
                  iconTheme: IconThemeData(
                    color: themeSettings.appBarTextColor,
                  ),
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
      developer.log('グループ作成後のバッジ獲得演出を開始', name: 'HomePage');

      // フラグをリセット
      groupProvider.resetGroupCreationCelebration();
    }
  }

  /// グループ作成後のバッジ獲得演出を表示
}
