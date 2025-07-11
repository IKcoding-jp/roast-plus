import 'package:bysnapp/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:bysnapp/pages/members/member_edit_page.dart';
import 'package:bysnapp/pages/labels/label_edit_page.dart';
import 'package:bysnapp/pages/history/assignment_history_page.dart';
import 'dart:math';
import '../../services/assignment_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class AssignmentBoard extends StatefulWidget {
  const AssignmentBoard({super.key});

  @override
  State<AssignmentBoard> createState() => AssignmentBoardState();
}

class AssignmentBoardState extends State<AssignmentBoard> {
  late SharedPreferences prefs;
  bool _isLoading = true;

  List<String> aOriginal = [];
  List<String> bOriginal = [];
  List<String> aMembers = [];
  List<String> bMembers = [];
  List<String> leftLabels = [];
  List<String> rightLabels = [];

  bool isShuffling = false;
  bool isAssignedToday = false;
  Timer? shuffleTimer;

  // Firestore同期用setter
  void setAssignmentMembersFromFirestore(Map<String, dynamic> members) {
    setState(() {
      aOriginal = List<String>.from(members['aMembers'] ?? []);
      bOriginal = List<String>.from(members['bMembers'] ?? []);
      // ラベルはnullや空リストなら上書きしない
      if (members['leftLabels'] != null &&
          (members['leftLabels'] as List).isNotEmpty) {
        leftLabels = List<String>.from(members['leftLabels']);
      }
      if (members['rightLabels'] != null &&
          (members['rightLabels'] as List).isNotEmpty) {
        rightLabels = List<String>.from(members['rightLabels']);
      }
      aMembers = List<String>.from(members['aMembers'] ?? []);
      bMembers = List<String>.from(members['bMembers'] ?? []);
    });
  }

  void setAssignmentHistoryFromFirestore(List<String> history) {
    setState(() {
      if (history.length == leftLabels.length) {
        aMembers = history.map((e) => e.split('-')[0]).toList();
        bMembers = history.map((e) => e.split('-')[1]).toList();
        isAssignedToday = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    prefs = await SharedPreferences.getInstance();

    final loadedA = prefs.getStringList('a班') ?? [];
    final loadedB = prefs.getStringList('b班') ?? [];
    final loadedLeft = prefs.getStringList('leftLabels') ?? [];
    final loadedRight = prefs.getStringList('rightLabels') ?? [];

    final today = _todayKey();
    final savedDate = prefs.getString('assignedDate');
    final wasAssigned = savedDate == today;
    final assignedPairs = wasAssigned
        ? prefs.getStringList('assignment_$today')
        : null;

    List<String> newA = List.from(loadedA);
    List<String> newB = List.from(loadedB);

    if (assignedPairs != null && assignedPairs.length == loadedLeft.length) {
      newA = assignedPairs.map((e) => e.split('-')[0]).toList();
      newB = assignedPairs.map((e) => e.split('-')[1]).toList();
    }

    setState(() {
      aOriginal = loadedA;
      bOriginal = loadedB;
      leftLabels = loadedLeft;
      rightLabels = loadedRight;
      aMembers = newA;
      bMembers = newB;
      isAssignedToday = wasAssigned && !_isWeekend();
      _isLoading = false;
    });
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String _dayKeyAgo(int d) => DateFormat(
    'yyyy-MM-dd',
  ).format(DateTime.now().subtract(Duration(days: d)));

  bool _isWeekend() {
    final wd = DateTime.now().weekday;
    final devMode = prefs.getBool('developerMode') ?? false;
    if (devMode) return false;
    return wd == DateTime.saturday || wd == DateTime.sunday;
  }

  List<String> _makePairs() {
    final count = leftLabels.length;
    return List.generate(count, (i) => '${aMembers[i]}-${bMembers[i]}');
  }

  bool _isDuplicate(List<String> newPairs, List<String>? old) {
    if (old == null) return false;
    return newPairs.any(old.contains);
  }

  void _shuffleAssignments() {
    final count = leftLabels.length;
    if (aMembers.length < count || bMembers.length < count) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('エラー'),
          content: Text('メンバー数が担当数に足りません。編集画面で調整してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => isShuffling = true);
    int cnt = 0;
    const dur = Duration(milliseconds: 100);
    shuffleTimer = Timer.periodic(dur, (_) async {
      aMembers.shuffle(Random());
      bMembers.shuffle(Random());
      setState(() {});
      if (++cnt >= 50) {
        shuffleTimer?.cancel();

        final today = _todayKey();
        final y1 = _dayKeyAgo(1), y2 = _dayKeyAgo(2);
        final pairs = _makePairs();
        final p1 = prefs.getStringList('assignment_$y1');
        final p2 = prefs.getStringList('assignment_$y2');

        int retry = 0;
        while ((_isDuplicate(pairs, p1) || _isDuplicate(pairs, p2)) &&
            retry < 100) {
          aMembers.shuffle(Random());
          bMembers.shuffle(Random());
          retry++;
        }

        final finalPairs = _makePairs();
        final devMode = prefs.getBool('developerMode') ?? false;
        final isWeekend =
            DateTime.now().weekday == DateTime.saturday ||
            DateTime.now().weekday == DateTime.sunday;

        if (!(isWeekend && !devMode)) {
          await prefs.setString('assignedDate', today);
          await prefs.setStringList('assignment_$today', finalPairs);
          // Firestoreにも保存
          await AssignmentFirestoreService.saveAssignmentHistory(
            dateKey: today,
            assignments: finalPairs,
          );
        }

        setState(() {
          isAssignedToday = true;
          isShuffling = false;
        });
      }
    });
  }

  void _resetToday() async {
    final today = _todayKey();
    await prefs.remove('assignedDate');
    await prefs.remove('assignment_$today');
    setState(() {
      isAssignedToday = false;
      aMembers = List.from(aOriginal);
      bMembers = List.from(bOriginal);
    });
  }

  Future<void> _navigateToMemberEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemberEditPage()),
    );
    _resetToday(); // 担当決定状態をリセット
    await _loadState(); // 状態を再読み込み
  }

  Future<void> _navigateToLabelEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabelEditPage()),
    );
    await _loadState();
  }

  void _goToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssignmentHistoryPage()),
    );
  }

  void _goToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(onReset: _resetToday)),
    );
    setState(() {}); // developerMode の変更を反映
  }

  String _formatDate() =>
      DateFormat.yMMMMd('ja_JP').add_E().format(DateTime.now());

  @override
  void dispose() {
    shuffleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final count = leftLabels.length;
    final isDev = prefs.getBool('developerMode') ?? false;
    final todayIsWeekend =
        DateTime.now().weekday == DateTime.saturday ||
        DateTime.now().weekday == DateTime.sunday;
    final isButtonDisabled =
        isShuffling || isAssignedToday || (todayIsWeekend && !isDev);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.group, color: Colors.white),
            SizedBox(width: 8),
            Text('今日の担当表'),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.group), onPressed: _navigateToMemberEdit),
          IconButton(icon: Icon(Icons.label), onPressed: _navigateToLabelEdit),
          IconButton(icon: Icon(Icons.history), onPressed: _goToHistory),
          IconButton(icon: Icon(Icons.settings), onPressed: _goToSettings),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 20),
              Text(
                _formatDate(),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color:
                      Provider.of<ThemeSettings>(context).backgroundColor2 ??
                      Colors.grey[100],
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(width: 80),
                          Expanded(
                            child: Center(
                              child: Text(
                                'A班',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'B班',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 80),
                        ],
                      ),
                    ),
                    // ラベルもメンバーも空の場合のみ赤字で表示
                    if (leftLabels.isEmpty &&
                        aMembers.isEmpty &&
                        bMembers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            'メンバーとラベルを追加してください',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      // 柔軟な行数で表示（ラベル数分のみ）
                      ...List.generate(leftLabels.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  i < leftLabels.length ? leftLabels[i] : '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              MemberCard(
                                name:
                                    i < aMembers.length &&
                                        aMembers[i].isNotEmpty
                                    ? aMembers[i]
                                    : '未設定',
                              ),
                              MemberCard(
                                name:
                                    i < bMembers.length &&
                                        bMembers[i].isNotEmpty
                                    ? bMembers[i]
                                    : '未設定',
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  i < rightLabels.length ? rightLabels[i] : '',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
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
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: isButtonDisabled ? null : _shuffleAssignments,
                child: Text(() {
                  if (todayIsWeekend && !isDev) return '土日は休み';
                  if (isAssignedToday) return '今日はすでに決定済み';
                  if (isShuffling) return 'シャッフル中...';
                  return '今日の担当を決める';
                }()),
              ),
              SizedBox(height: 20), // 下部に余白を追加
            ],
          ),
        ),
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  final String name;
  const MemberCard({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final displayName = name.isEmpty ? '未設定' : name;
    final isUnset = displayName == '未設定';
    final cardColor = isUnset
        ? (Provider.of<ThemeSettings>(context).backgroundColor2 ??
              Colors.grey[300])
        : Colors.green[200];
    final textColor = isUnset ? Colors.grey[600] : Colors.black;

    return Container(
      width: 100,
      padding: EdgeInsets.symmetric(vertical: 10),
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black38),
      ),
      alignment: Alignment.center,
      child: Text(
        displayName,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
