import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/group_level_utils.dart';
import '../../widgets/group_level_display_widget.dart';
import '../../models/group_gamification_models.dart';

/// グループレベルシステムのテスト用ページ
class GroupLevelTestPage extends StatefulWidget {
  const GroupLevelTestPage({super.key});

  @override
  State<GroupLevelTestPage> createState() => _GroupLevelTestPageState();
}

class _GroupLevelTestPageState extends State<GroupLevelTestPage> {
  int _testLevel = 1;
  int _testXp = 0;
  List<Map<String, dynamic>> _simulationResults = [];

  @override
  void initState() {
    super.initState();
    _calculateTestXp();
    _runSimulation();
  }

  void _calculateTestXp() {
    _testXp = GroupLevelUtils.calculateTotalRequiredXp(_testLevel);
  }

  void _runSimulation() {
    _simulationResults = GroupLevelUtils.simulate3YearProgress();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'グループレベルシステム テスト',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 18 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // テスト用レベル表示
            _buildTestLevelDisplay(),
            const SizedBox(height: 24),

            // レベル調整
            _buildLevelAdjuster(),
            const SizedBox(height: 24),

            // システム情報
            _buildSystemInfo(),
            const SizedBox(height: 24),

            // 3年間シミュレーション結果
            _buildSimulationResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestLevelDisplay() {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final testProfile = GroupGamificationProfile.initial('test');
    final modifiedProfile = testProfile.copyWith(
      level: _testLevel,
      experiencePoints: _testXp,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'テスト用レベル表示',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            const SizedBox(height: 16),
            GroupLevelDisplayWidget(
              profile: modifiedProfile,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelAdjuster() {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'レベル調整',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'レベル: $_testLevel',
                    style: TextStyle(
                      fontSize: 16,
                      color: themeSettings.fontColor1,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _testLevel.toDouble(),
                    min: 1,
                    max: 9999,
                    divisions: 9998,
                    onChanged: (value) {
                      setState(() {
                        _testLevel = value.round();
                        _calculateTestXp();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '必要経験値: $_testXp XP',
              style: TextStyle(fontSize: 14, color: themeSettings.fontColor2),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _testLevel = 1;
                      _calculateTestXp();
                    });
                  },
                  child: Text('Lv.1'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _testLevel = 100;
                      _calculateTestXp();
                    });
                  },
                  child: Text('Lv.100'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _testLevel = 1000;
                      _calculateTestXp();
                    });
                  },
                  child: Text('Lv.1000'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _testLevel = 9999;
                      _calculateTestXp();
                    });
                  },
                  child: Text('Lv.9999'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfo() {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final dailyXp = GroupLevelUtils.calculateDailyXpForMaxLevel();
    final totalXpForMax = GroupLevelUtils.calculateTotalRequiredXp(9999);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'システム情報',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('3年間でLv.9999到達に必要な1日あたりXP', '$dailyXp XP'),
            _buildInfoRow('Lv.9999までの総必要経験値', '$totalXpForMax XP'),
            _buildInfoRow('3年間の総日数', '1,095日'),
            _buildInfoRow(
              'レベルバッジ数',
              '${GroupLevelUtils.getLevelBadgeThresholds().length}個',
            ),
            const SizedBox(height: 16),
            Text(
              'レベルバッジ一覧:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: GroupLevelUtils.getLevelBadgeThresholds().map((level) {
                return Chip(
                  label: Text('Lv.$level'),
                  backgroundColor: _getBadgeColor(level),
                  labelStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationResults() {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3年間シミュレーション結果',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _simulationResults.length,
                itemBuilder: (context, index) {
                  final result = _simulationResults[index];
                  final isYearly = result.containsKey('year');

                  return ListTile(
                    leading: Icon(
                      isYearly ? Icons.calendar_today : Icons.calendar_month,
                      color: isYearly ? Colors.blue : Colors.green,
                    ),
                    title: Text(
                      isYearly
                          ? '${result['year']}年目 (${result['day']}日目)'
                          : '${result['month']}ヶ月目 (${result['day']}日目)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeSettings.fontColor1,
                      ),
                    ),
                    subtitle: Text(
                      'Lv.${result['level']} (${result['totalXp']} XP)',
                      style: TextStyle(color: themeSettings.fontColor2),
                    ),
                    trailing: Text(
                      'バッジ: ${result['earnedBadges'].length}個',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: themeSettings.fontColor1),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: themeSettings.fontColor2,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(int level) {
    if (level >= 9999) return Colors.amber.shade700;
    if (level >= 1000) return Colors.purple.shade600;
    if (level >= 500) return Colors.red.shade600;
    if (level >= 200) return Colors.orange.shade600;
    if (level >= 100) return Colors.blue.shade600;
    if (level >= 50) return Colors.green.shade600;
    if (level >= 20) return Colors.teal.shade600;
    if (level >= 10) return Colors.indigo.shade400;
    if (level >= 5) return Colors.brown.shade400;
    return Colors.grey.shade600;
  }
}
