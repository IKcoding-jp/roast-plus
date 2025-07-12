import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:bysnapp/models/roast_record.dart';
import 'package:bysnapp/services/roast_record_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class RoastAdvisorPage extends StatelessWidget {
  const RoastAdvisorPage({super.key});

  int _parseTimeToSeconds(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final min = int.tryParse(parts[0]) ?? 0;
    final sec = int.tryParse(parts[1]) ?? 0;
    return min * 60 + sec;
  }

  String _formatSeconds(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    const beige = Color(0xFFFFF8E1);
    const brown = Color(0xFF795548);
    const appbarColor = Color(0xFF2C1D17);
    final width = MediaQuery.of(context).size.width;
    // スマホならカラム幅を均等、タブレットなら少し余裕を持たせる
    final isWide = width > 600;
    final colFlex = isWide ? [2, 2, 2, 1] : [3, 3, 3, 2];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.analytics,
              color: Provider.of<ThemeSettings>(context).iconColor,
            ),
            SizedBox(width: 8),
            Text('焙煎分析'),
          ],
        ),
        backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: StreamBuilder<List<RoastRecord>>(
          stream: RoastRecordFirestoreService.getRecordsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('データ取得エラー'));
            }
            final records = snapshot.data ?? [];
            if (records.isEmpty) {
              return const Center(child: Text('記録がありません'));
            }

            // 豆の種類ごとにグループ化
            final Map<String, List<RoastRecord>> beanGroups = {};
            for (final r in records) {
              beanGroups.putIfAbsent(r.bean, () => []).add(r);
            }
            // 表示順を指定
            final List<String> preferredOrder = [
              'ブラジル',
              'コロンビア',
              'エチオピア',
              'ペルー',
            ];
            final List<String> beanNames = [];
            final List<String> others = [];
            for (final name in preferredOrder) {
              if (beanGroups.containsKey(name)) beanNames.add(name);
            }
            for (final name in beanGroups.keys) {
              if (!preferredOrder.contains(name)) others.add(name);
            }
            if (others.isNotEmpty) {
              // "その他"グループを作成
              final List<RoastRecord> otherRecords = others
                  .expand((n) => beanGroups[n]!)
                  .toList();
              beanGroups['その他'] = otherRecords;
              beanNames.add('その他');
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).iconColor.withOpacity(0.12), // テーマのアイコン色を薄く反映
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.analytics,
                          color: Provider.of<ThemeSettings>(context).iconColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '豆の種類ごとに平均焙煎時間を表示',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...beanNames.map((bean) {
                    final beanRecords = beanGroups[bean]!;
                    // (重さ,煎り度)ごとにグループ化
                    final Map<String, List<RoastRecord>> group = {};
                    for (final r in beanRecords) {
                      final key = '${r.weight}|${r.roast}';
                      group.putIfAbsent(key, () => []).add(r);
                    }
                    final rows = group.entries.map((entry) {
                      final keyParts = entry.key.split('|');
                      final weight = keyParts[0];
                      final roast = keyParts[1];
                      final times = entry.value
                          .map((r) => _parseTimeToSeconds(r.time))
                          .where((s) => s > 0)
                          .toList();
                      final avgSec = times.isNotEmpty
                          ? (times.reduce((a, b) => a + b) ~/ times.length)
                          : 0;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Text(
                              '$weight g',
                              style: TextStyle(
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Text(
                              roast,
                              style: TextStyle(
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Text(
                              times.isNotEmpty ? _formatSeconds(avgSec) : '-',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Text(
                              '${entry.value.length}',
                              style: TextStyle(
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList();

                    return Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color:
                          Provider.of<ThemeSettings>(
                            context,
                          ).backgroundColor2 ??
                          Colors.white,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.coffee,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).iconColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  bean,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Provider.of<ThemeSettings>(
                                      context,
                                    ).fontColor1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Table(
                                  border: TableBorder.symmetric(
                                    inside: BorderSide(color: Colors.black12),
                                  ),
                                  columnWidths: {
                                    0: FlexColumnWidth(colFlex[0].toDouble()),
                                    1: FlexColumnWidth(colFlex[1].toDouble()),
                                    2: FlexColumnWidth(colFlex[2].toDouble()),
                                    3: FlexColumnWidth(colFlex[3].toDouble()),
                                  },
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: brown.withOpacity(0.08),
                                      ),
                                      children: const [
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            '重さ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: brown,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            '煎り度',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: brown,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            '平均焙煎時間',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: brown,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            '件数',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: brown,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...rows,
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  const Text(
                    '※平均は同じ条件の全記録から算出されます。',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
