import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class CreatorMessagePage extends StatelessWidget {
  const CreatorMessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('制作者からのメッセージ'),
        backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 600, // Web版での最大幅を制限
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Provider.of<ThemeSettings>(
                        context,
                      ).cardBackgroundColor,
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      0xFFFF8225,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.coffee,
                                    color: Color(0xFFFF8225),
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'ローストプラスについて',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Text(
                              'はじめまして！このアプリを作ったIKです☕\n\n'
                              '僕は、BYSNで実際に働いている従業員の一人です。\n'
                              '日々の業務の中で、「この作業、もっとラクにできたらいいのに」'
                              '「こういうの記録できたら便利だな」って思ったことを、'
                              '少しずつ形にしたいと思いこのアプリを作りました。\n\n'
                              '同じようにBYSNでがんばってる仲間のみなさんにとっても、'
                              '使いやすくて役立つアプリになってくれたらうれしいです！\n\n'
                              'なるべくシンプルでスッキリした画面にこだわってます。\n\n'
                              'まだまだ改善の余地はたくさんありますが、'
                              'これからもどんどんアップデートしていく予定です。\n\n'
                              '「こんな機能あったらいいな」「ここ直してほしい」って声があれば、'
                              'フィードバックから気軽に教えてもらえたらうれしいです！\n\n'
                              '最後まで読んでくれて、ありがとうございます。',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.6,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                            SizedBox(height: 24),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Color(0xFFFF8225).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(
                                    0xFFFF8225,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    color: Color(0xFFFF8225),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '一緒にお仕事がんばりましょう！',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF8225),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
