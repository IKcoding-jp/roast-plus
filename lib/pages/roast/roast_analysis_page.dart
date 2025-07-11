import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:bysnapp/pages/roast/roast_record_page.dart';
import 'package:bysnapp/pages/roast/roast_advisor_page.dart';
import 'package:bysnapp/pages/roast/roast_timer_page.dart';

class RoastAnalysisPage extends StatefulWidget {
  const RoastAnalysisPage({super.key});

  @override
  State<RoastAnalysisPage> createState() => _RoastAnalysisPageState();
}

class _RoastAnalysisPageState extends State<RoastAnalysisPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _records = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('roastRecords');

    if (savedData != null) {
      try {
        final List<dynamic> jsonList = json.decode(savedData);
        final parsed = jsonList.map<Map<String, dynamic>>((e) {
          final map = Map<String, dynamic>.from(e);
          final timeStr = map['time']?.toString() ?? '';
          final duration = _parseDuration(timeStr);
          map['seconds'] = duration.inSeconds;
          return map;
        }).toList();

        setState(() {
          _records = parsed;
        });
      } catch (e) {
        print('読み込みエラー: $e');
        setState(() {
          _records = [];
        });
      }
    }
  }

  Duration _parseDuration(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return Duration.zero;
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return Duration(minutes: minutes, seconds: seconds);
  }

  Map<String, double> _groupByAndAverage(
    List<Map<String, dynamic>> records,
    String key,
  ) {
    final Map<String, List<int>> groups = {};

    for (var r in records) {
      final groupKey = r[key] ?? '';
      final duration = r['seconds'];
      if (groupKey != null && duration != null) {
        groups.putIfAbsent(groupKey, () => []).add(duration);
      }
    }

    return groups.map((k, v) {
      final avg = v.reduce((a, b) => a + b) / v.length;
      return MapEntry(k, avg);
    });
  }

  String _formatSeconds(double seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toStringAsFixed(0).padLeft(2, '0')}';
  }

  // 豆の色分けマップ
  Color _getBeanColor(String beanName) {
    final name = beanName.toLowerCase();
    if (name.contains('ブラジル')) return Colors.yellow[700]!;
    if (name.contains('コロンビア')) return Colors.green[600]!;
    if (name.contains('エチオピア')) return Colors.blue[600]!;
    if (name.contains('ペルー')) return Colors.red[600]!;
    return Colors.grey[400]!; // デフォルト
  }

  // 豆の順序マップ
  int _getBeanOrder(String beanName) {
    final name = beanName.toLowerCase();
    if (name.contains('ブラジル')) return 1;
    if (name.contains('コロンビア')) return 2;
    if (name.contains('エチオピア')) return 3;
    if (name.contains('ペルー')) return 4;
    if (name.contains('グアテマラ')) return 5;
    return 999; // その他は最後
  }

  Widget _buildAnalysisSection(
    String title,
    Map<String, double> data,
    IconData icon,
    Color color,
  ) {
    final entries = data.entries.toList()
      ..sort((a, b) {
        // 豆の種類の場合のみ順序でソート
        if (title.contains('豆の種類')) {
          return _getBeanOrder(a.key).compareTo(_getBeanOrder(b.key));
        }
        return a.key.compareTo(b.key);
      });
    return Card(
      elevation: 6,
      margin: EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: color.withOpacity(0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, color: color.withOpacity(0.5), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          // 豆の種類の場合のみ色シールを表示
                          if (title.contains('豆の種類')) ...[
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getBeanColor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
                          Text(
                            title.contains('重さ') ? '${e.key}g' : e.key,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C1D17),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatSeconds(e.value),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 棒グラフウィジェット
  Widget _buildBarChart(String title, Map<String, double> data, Color color) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // 値の大きい順

    if (entries.isEmpty) return SizedBox.shrink();

    return Card(
      elevation: 6,
      margin: EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: color.withOpacity(0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      entries
                          .map((e) => e.value)
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= entries.length) return Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              entries[value.toInt()].key,
                              style: TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatSeconds(value),
                            style: TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data.value,
                          color: color,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 円グラフウィジェット
  Widget _buildPieChart(String title, Map<String, double> data, Color color) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // 値の大きい順

    if (entries.isEmpty) return SizedBox.shrink();

    final total = entries.fold(0.0, (sum, entry) => sum + entry.value);

    return Card(
      elevation: 6,
      margin: EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: color.withOpacity(0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: entries.asMap().entries.map((entry) {
                          final index = entry.key;
                          final data = entry.value.value;
                          final percentage = (data / total * 100)
                              .toStringAsFixed(1);

                          // 色のグラデーション
                          final colors = [
                            color,
                            color.withOpacity(0.8),
                            color.withOpacity(0.6),
                            color.withOpacity(0.4),
                          ];

                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: data,
                            title: '$percentage%',
                            radius: 80,
                            titleStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.map((entry) {
                      final percentage = (entry.value / total * 100)
                          .toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${entry.key}\n$percentage%',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final beanAvg = _groupByAndAverage(_records, 'bean');
    final weightAvg = _groupByAndAverage(_records, 'weight');
    final roastAvg = _groupByAndAverage(_records, 'roast');
    final beanCount = _countByCategory(_records, 'bean');
    final roastCount = _countByCategory(_records, 'roast');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Color(0xFF795548)),
            SizedBox(width: 8),
            Text('焙煎分析'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8E1), Color(0xFFFFF8E1)],
          ),
        ),
        child: _records.isEmpty
            ? Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Color(0xFFFFF8E1),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.analytics,
                          size: 64,
                          color: Color(0xFF795548),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '記録がありません',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C1D17),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '焙煎記録を入力してから分析をご利用ください',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAnalysisCard(
                      '豆の種類ごとの平均焙煎時間',
                      _groupByAndAverage(_records, 'bean'),
                      Icons.coffee,
                    ),
                    SizedBox(height: 16),
                    _buildAnalysisCard(
                      '重さごとの平均焙煎時間',
                      _groupByAndAverage(_records, 'weight'),
                      Icons.scale,
                    ),
                    SizedBox(height: 16),
                    _buildAnalysisCard(
                      '煎り度ごとの平均焙煎時間',
                      _groupByAndAverage(_records, 'roast'),
                      Icons.local_fire_department,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAnalysisCard(
    String title,
    Map<String, double> data,
    IconData icon,
  ) {
    List<MapEntry<String, double>> entries = data.entries.toList();
    if (title.contains('豆の種類')) {
      // 指定順で並べ替え
      final order = ['ブラジル', 'コロンビア', 'エチオピア', 'ペルー', 'グアテマラ'];
      entries.sort((a, b) {
        int ia = order.indexWhere((k) => a.key.contains(k));
        int ib = order.indexWhere((k) => b.key.contains(k));
        ia = ia == -1 ? 999 : ia;
        ib = ib == -1 ? 999 : ib;
        if (ia != ib) return ia.compareTo(ib);
        return a.key.compareTo(b.key);
      });
    }
    if (title.contains('重さ')) {
      // 200,300,500,その他の順
      final order = ['200', '300', '500'];
      entries.sort((a, b) {
        int ia = order.indexOf(a.key);
        int ib = order.indexOf(b.key);
        ia = ia == -1 ? 999 : ia;
        ib = ib == -1 ? 999 : ib;
        if (ia != ib) return ia.compareTo(ib);
        // 数値として比較（その他同士は昇順）
        int na = int.tryParse(a.key) ?? 10000;
        int nb = int.tryParse(b.key) ?? 10000;
        return na.compareTo(nb);
      });
    }
    if (title.contains('煎り度')) {
      // 浅煎り、中煎り、中深煎り、深煎り、その他の順
      final order = ['浅煎り', '中煎り', '中深煎り', '深煎り'];
      entries.sort((a, b) {
        int ia = order.indexOf(a.key);
        int ib = order.indexOf(b.key);
        ia = ia == -1 ? 999 : ia;
        ib = ib == -1 ? 999 : ib;
        if (ia != ib) return ia.compareTo(ib);
        return a.key.compareTo(b.key);
      });
    }
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF795548),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C1D17),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (data.isEmpty)
              Text('データがありません', style: TextStyle(color: Colors.grey[600]))
            else
              ...entries.map((entry) {
                final minutes = (entry.value / 60).floor();
                final seconds = (entry.value % 60).round();
                // 丸シール色定義
                Color? rightCircleColor;
                if (title.contains('豆の種類')) {
                  if (entry.key.contains('ブラジル')) {
                    rightCircleColor = Colors.yellow[700];
                  } else if (entry.key.contains('コロンビア'))
                    rightCircleColor = Colors.green[600];
                  else if (entry.key.contains('エチオピア'))
                    rightCircleColor = Colors.blue[600];
                  else if (entry.key.contains('ペルー'))
                    rightCircleColor = Colors.red[600];
                  // グアテマラやその他はnull
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // 左側に丸シール
                            if (rightCircleColor != null) ...[
                              Container(
                                width: 16,
                                height: 16,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: rightCircleColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Text(
                              title.contains('重さ')
                                  ? '${entry.key}g'
                                  : entry.key,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C1D17),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF795548).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF795548),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // カテゴリ別カウント関数
  Map<String, double> _countByCategory(
    List<Map<String, dynamic>> records,
    String key,
  ) {
    final Map<String, int> counts = {};

    for (var record in records) {
      final category = record[key]?.toString() ?? '';
      if (category.isNotEmpty) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }

    return counts.map((k, v) => MapEntry(k, v.toDouble()));
  }
}
