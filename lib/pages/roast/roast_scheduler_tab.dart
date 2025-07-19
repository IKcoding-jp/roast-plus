import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:bysnapp/models/roast_schedule_models.dart';
import 'package:bysnapp/models/roast_break_time.dart';
import 'package:provider/provider.dart';
import '../../models/roast_schedule_form_provider.dart';
import '../../models/theme_settings.dart';
import '../../widgets/bean_name_with_sticker.dart';
import '../../models/group_provider.dart';
import '../../services/group_data_sync_service.dart';

class RoastSchedulerTab extends StatefulWidget {
  final List<RoastBreakTime> breakTimes;
  const RoastSchedulerTab({super.key, this.breakTimes = const []});

  @override
  State<RoastSchedulerTab> createState() => RoastSchedulerTabState();
}

class RoastSchedulerTabState extends State<RoastSchedulerTab>
    with AutomaticKeepAliveClientMixin {
  // 修正: 存在しない型 _RoastBeanInput を仮の Map で代用
  // 存在しない型を修正し、仮のMap型で統一
  // var _beans = <RoastBeanInput>[RoastBeanInput()];
  TimeOfDay? _amStart;
  TimeOfDay? _pmStart;
  final List<RoastScheduleResult> _result = [];
  final List<List<int>> _combResults = [];
  String _overflowMsg = '';
  String _inputErrorMsg = ''; // 入力エラー用

  // スケジュール生成結果をFutureで管理
  Future<RoastScheduleData>? _futureResult;
  // ダイアログ表示フラグ
  bool _dialogShown = false;

  // 焙煎度合いアイコンマップ
  final Map<String, String> _roastIcons = {
    '浅煎り': '🌱',
    '中煎り': '🍃',
    '中深煎り': '☕',
    '深煎り': '🔥',
  };

  // 24時間表記で時間をフォーマット
  String _formatTime24Hour(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // --- 追加: コントローラーリスト ---
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _weightControllers = [];
  final List<TextEditingController> _bagsControllers = [];

  @override
  void dispose() {
    // コントローラーの破棄を最適化
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _weightControllers) {
      c.dispose();
    }
    for (final c in _bagsControllers) {
      c.dispose();
    }
    _nameControllers.clear();
    _weightControllers.clear();
    _bagsControllers.clear();
    super.dispose();
  }

  void _syncControllersWithBeans(List<RoastScheduleBean> beans) {
    // 名前
    while (_nameControllers.length < beans.length) {
      _nameControllers.add(TextEditingController());
    }
    while (_nameControllers.length > beans.length) {
      final controller = _nameControllers.removeLast();
      controller.dispose();
    }
    for (int i = 0; i < beans.length; i++) {
      if (_nameControllers[i].text != beans[i].name) {
        _nameControllers[i].text = beans[i].name;
      }
    }
    // 重量
    while (_weightControllers.length < beans.length) {
      _weightControllers.add(TextEditingController());
    }
    while (_weightControllers.length > beans.length) {
      final controller = _weightControllers.removeLast();
      controller.dispose();
    }
    for (int i = 0; i < beans.length; i++) {
      final w = beans[i].weight > 0 ? beans[i].weight.toString() : '';
      if (_weightControllers[i].text != w) {
        _weightControllers[i].text = w;
      }
    }
    // 袋数
    while (_bagsControllers.length < beans.length) {
      _bagsControllers.add(TextEditingController());
    }
    while (_bagsControllers.length > beans.length) {
      final controller = _bagsControllers.removeLast();
      controller.dispose();
    }
    for (int i = 0; i < beans.length; i++) {
      final b = beans[i].bags?.toString() ?? '';
      if (_bagsControllers[i].text != b) {
        _bagsControllers[i].text = b;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _restoreInputState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        _loadGroupRoastSchedule();
      } else {
        _restoreInputState();
      }
      groupProvider.addListener(() {
        if (groupProvider.groups.isNotEmpty) {
          _loadGroupRoastSchedule();
        } else {
          _restoreInputState();
        }
      });
    });
  }

  void _addBean() {
    final provider = Provider.of<RoastScheduleFormProvider>(
      context,
      listen: false,
    );
    provider.addBean(RoastScheduleBean(name: '', weight: 0));
    _saveInputState(); // 追加時に保存
  }

  void _removeBean(int index) {
    final provider = Provider.of<RoastScheduleFormProvider>(
      context,
      listen: false,
    );
    provider.removeBean(index);
    _saveInputState(); // 削除時に保存
  }

  void _moveBean(int oldIndex, int newIndex) {
    setState(() {
      final provider = Provider.of<RoastScheduleFormProvider>(
        context,
        listen: false,
      );
      final beansCopy = List<RoastScheduleBean>.from(provider.beans);
      final item = beansCopy.removeAt(oldIndex);
      beansCopy.insert(newIndex, item);
      provider.setBeans(beansCopy);
    });
    _saveInputState();
  }

  Future<void> _pickTime(bool isAm) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: isAm ? 10 : 13, minute: 30),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isAm) {
          _amStart = picked;
        } else {
          _pmStart = picked;
        }
      });
      _saveInputState();
    }
  }

  Future<void> _generateSchedule() async {
    setState(() {
      _overflowMsg = '';
      _inputErrorMsg = '';
      _futureResult = null;
      _dialogShown = false;
    });

    // 入力チェック
    final provider = Provider.of<RoastScheduleFormProvider>(
      context,
      listen: false,
    );
    final beans = provider.beans
        .where(
          (b) =>
              b.name.trim().isNotEmpty &&
              b.weight > 0 &&
              b.bags != null &&
              b.bags! > 0 &&
              b.roastLevel != null &&
              b.roastLevel!.isNotEmpty,
        )
        .toList();
    if (beans.isEmpty || beans.length != provider.beans.length) {
      setState(() {
        _inputErrorMsg = 'すべての項目（豆の種類・重さ・袋数・焙煎度合い）を正しく入力してください。';
        _futureResult = null;
      });
      return;
    }
    if (_amStart == null && _pmStart == null) {
      setState(() {
        _inputErrorMsg = '午前または午後の焙煎開始時刻を選択してください。';
        _futureResult = null;
      });
      return;
    }

    int totalRoastCount = beans.fold(0, (sum, b) => sum + (b.bags ?? 0));
    const int amMax = 3;
    if (_amStart != null && (_pmStart == null || totalRoastCount <= amMax)) {
      setState(() {
        _futureResult = _calcSchedule(beans, _amStart!, null);
      });
      _futureResult!.then((data) async {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('roastSchedule_autoGenerated', true);
      });
      return;
    }
    if (_pmStart != null && _amStart == null) {
      setState(() {
        _futureResult = _calcSchedule(beans, _pmStart!, _pmStart);
      });
      _futureResult!.then((data) async {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('roastSchedule_autoGenerated', true);
      });
      return;
    }
    if (_amStart != null && _pmStart != null) {
      setState(() {
        _futureResult = _calcSchedule(beans, _amStart!, _pmStart);
      });
      _futureResult!.then((data) async {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool('roastSchedule_autoGenerated', true);
      });
      return;
    }
  }

  /// 午後の開始時刻がnullなら午前分だけ生成
  Future<RoastScheduleData> _calcSchedule(
    List<RoastScheduleBean> beans,
    TimeOfDay amStart,
    TimeOfDay? pmStart,
  ) async {
    // 1. 「豆＋焙煎度合い」でグループ化
    Map<String, List<RoastScheduleBean>> grouped = {};
    for (final b in beans) {
      final key = '${b.name}__${b.roastLevel}';
      grouped.putIfAbsent(key, () => []).add(b);
    }

    // 2. 各グループで重さごとに袋を展開
    List<RoastTask> tasks = [];
    for (final group in grouped.values) {
      List<int> allWeights = [];
      for (final b in group) {
        for (int i = 0; i < (b.bags ?? 0); i++) {
          allWeights.add(b.weight ?? 0);
        }
      }
      // 2袋ずつペアにして1枠に詰める
      int idx = 0;
      while (idx < allWeights.length) {
        List<int> pair = [];
        pair.add(allWeights[idx]);
        if (idx + 1 < allWeights.length) {
          pair.add(allWeights[idx + 1]);
        }
        tasks.add(
          RoastTask(
            type: group.first.name,
            roastLevel: group.first.roastLevel ?? '',
            weights: List.from(pair),
          ),
        );
        idx += 2;
      }
    }

    // 3. 最大6枠・12袋まで
    int totalBags = tasks.fold(0, (sum, t) => sum + t.weights.length);
    String overflowMsg = '';
    if (tasks.length > 6 || totalBags > 12) {
      overflowMsg = '1日最大12袋（6枠）までです。本日中に焙煎できない豆があります。';
      // 超過分はカット
      int allowed = 12;
      List<RoastTask> limited = [];
      for (final t in tasks) {
        if (allowed <= 0) break;
        int c = t.weights.length;
        if (c > allowed) c = allowed;
        limited.add(
          RoastTask(
            type: t.type,
            roastLevel: t.roastLevel,
            weights: t.weights.sublist(0, c),
          ),
        );
        allowed -= c;
      }
      tasks = limited;
    }

    // 4. 午前・午後分割をやめ、時系列で割り当て
    List<RoastScheduleResult> amResult = [];
    List<RoastScheduleResult> pmResult = [];
    TimeOfDay? t = amStart != null ? _addMinutes(amStart, 30) : null;
    bool switchedToPm = false;
    for (int i = 0; i < tasks.length; i++) {
      if (t == null) continue;
      // 休憩時間帯に重なる限りtを休憩終了時刻に進める
      while (true) {
        final breakInfo = _findBreak(t!);
        if (breakInfo == null) break;
        t = breakInfo.end;
      }
      // 13:00以降は必ず午後枠にする
      bool isPm = false;
      final tMinutes = t.hour * 60 + t.minute;
      if (pmStart != null) {
        final pmStartMinutes = pmStart.hour * 60 + pmStart.minute;
        if (tMinutes >= pmStartMinutes) {
          isPm = true;
          switchedToPm = true;
          t = tMinutes == pmStartMinutes ? pmStart : t;
        }
      }
      // 12:00以降は必ず午後枠にする
      final noonMinutes = 12 * 60;
      if (!isPm && tMinutes >= noonMinutes) {
        isPm = true;
        switchedToPm = true;
        if (pmStart != null) {
          t = tMinutes < pmStart.hour * 60 + pmStart.minute ? pmStart : t;
        }
      }
      // 13:00以降は必ず午後枠にする（厳密に13:00未満のみamResultに追加）
      final onePmMinutes = 13 * 60;
      if (!isPm && tMinutes >= onePmMinutes) {
        isPm = true;
        switchedToPm = true;
        if (pmStart != null) {
          t = tMinutes < pmStart.hour * 60 + pmStart.minute ? pmStart : t;
        }
      }
      // 休憩時間帯に入っているか
      final breakInfo = _findBreak(t);
      if (!isPm && breakInfo != null) {
        // 休憩明けにtを進めて午前枠のまま続行
        t = breakInfo.end;
        // もしpmStart以降になったら午後枠に切り替え
        if (pmStart != null) {
          final tMinutes = t.hour * 60 + t.minute;
          final pmStartMinutes = pmStart.hour * 60 + pmStart.minute;
          if (tMinutes >= pmStartMinutes) {
            isPm = true;
            switchedToPm = true;
            t = pmStart;
          }
        }
      }
      if (isPm) {
        // 午後枠
        if (pmStart != null) {
          final tMinutes = t.hour * 60 + t.minute;
          final pmStartMinutes = pmStart.hour * 60 + pmStart.minute;
          if (tMinutes < pmStartMinutes + 30) {
            t = _addMinutes(pmStart, 30);
          }
        }
        bool pmInBreak = widget.breakTimes.any((b) {
          final tMinutes = t!.hour * 60 + t.minute;
          final breakStart = b.start.hour * 60 + b.start.minute;
          return tMinutes >= (breakStart - 10) &&
              tMinutes < b.end.hour * 60 + b.end.minute;
        });
        while (pmInBreak) {
          if (t == null) break;
          t = _addMinutes(t, 20);
          pmInBreak = widget.breakTimes.any((b) {
            final tMinutes = t!.hour * 60 + t.minute;
            final breakStart = b.start.hour * 60 + b.start.minute;
            return tMinutes >= (breakStart - 10) &&
                tMinutes < b.end.hour * 60 + b.end.minute;
          });
        }
        pmResult.add(RoastScheduleResult(task: tasks[i], time: t));
        // 2回目以降は常に20分間隔
        t = _addMinutes(t!, 20);
      } else {
        // 午前枠
        amResult.add(RoastScheduleResult(task: tasks[i], time: t));
        // 常に20分間隔
        t = _addMinutes(t, 20);
      }
    }
    // 午前・午後両方の最後に必ずアフターパージを追加
    if (amResult.isEmpty || !amResult.last.afterPurge) {
      amResult.add(
        RoastScheduleResult(task: null, time: null, afterPurge: true),
      );
    }
    if (pmResult.isEmpty || !pmResult.last.afterPurge) {
      pmResult.add(
        RoastScheduleResult(task: null, time: null, afterPurge: true),
      );
    }

    // 6. 余り豆組み合わせ案（省略：現状通り）

    return RoastScheduleData(amResult, pmResult, [], overflowMsg);
  }

  TimeOfDay _addMinutes(TimeOfDay t, int min) {
    final dt = DateTime(
      2020,
      1,
      1,
      t.hour,
      t.minute,
    ).add(Duration(minutes: min));
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  // 最大深度制限付き組み合わせ
  List<List<int>> _findCombinations(int total, List<int> sizes, int maxDepth) {
    List<List<int>> results = [];
    void search(int remain, List<int> current) {
      if (current.length > maxDepth) return;
      if (remain == 0) {
        results.add(List.from(current));
        return;
      }
      for (final s in sizes) {
        if (remain >= s) {
          current.add(s);
          search(remain - s, current);
          current.removeLast();
        }
      }
    }

    search(total, []);
    results.sort((a, b) => a.length.compareTo(b.length));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = Provider.of<RoastScheduleFormProvider>(context);
    final beans = provider.beans;
    final beige = const Color(0xFFFFF8E1);
    final brown = const Color(0xFF795548);
    _syncControllersWithBeans(beans); // ←ここで同期
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ★ ここから追加: スケジュール自動作成用入力フォーム
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit,
                          color: Provider.of<ThemeSettings>(context).iconColor,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'スケジュール自動作成用入力フォーム',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: beans.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final bean = beans[i];
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 豆名
                                Expanded(
                                  child: TextField(
                                    controller: _nameControllers[i],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                      labelText: '豆名',
                                    ),
                                    onChanged: (val) {
                                      provider.updateBean(
                                        i,
                                        RoastScheduleBean(
                                          name: val,
                                          weight: bean.weight,
                                          bags: bean.bags,
                                          roastLevel: bean.roastLevel,
                                        ),
                                      );
                                      _saveInputState();
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                // 削除ボタン
                                IconButton(
                                  icon: Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                  onPressed: () => _removeBean(i),
                                  iconSize: 28,
                                  padding: EdgeInsets.all(8),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                // 重さ
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: _weightControllers[i],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                      labelText: '重さ',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      final weight = int.tryParse(val) ?? 0;
                                      provider.updateBean(
                                        i,
                                        RoastScheduleBean(
                                          name: bean.name,
                                          weight: weight,
                                          bags: bean.bags,
                                          roastLevel: bean.roastLevel,
                                        ),
                                      );
                                      _saveInputState();
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                // 袋数
                                SizedBox(
                                  width: 70,
                                  child: TextField(
                                    controller: _bagsControllers[i],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                      labelText: '袋数',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      final bags = int.tryParse(val);
                                      provider.updateBean(
                                        i,
                                        RoastScheduleBean(
                                          name: bean.name,
                                          weight: bean.weight,
                                          bags: bags,
                                          roastLevel: bean.roastLevel,
                                        ),
                                      );
                                      _saveInputState();
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                // 焙煎度合い
                                Flexible(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: bean.roastLevel,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                      labelText: '焙煎度合い',
                                    ),
                                    items: ['浅煎り', '中煎り', '中深煎り', '深煎り']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      provider.updateBean(
                                        i,
                                        RoastScheduleBean(
                                          name: bean.name,
                                          weight: bean.weight,
                                          bags: bean.bags,
                                          roastLevel: val,
                                        ),
                                      );
                                      _saveInputState();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('リストを追加'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context)
                                  .elevatedButtonTheme
                                  .style
                                  ?.backgroundColor
                                  ?.resolve({}) ??
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context)
                                  .elevatedButtonTheme
                                  .style
                                  ?.foregroundColor
                                  ?.resolve({}) ??
                              Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          textStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          elevation: 4,
                        ),
                        onPressed: _addBean,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            // ★ ここまで追加
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Provider.of<ThemeSettings>(context).iconColor,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '焙煎開始時刻',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // --- 焙煎開始時刻エリア ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '午前',
                                style: TextStyle(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _pickTime(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context)
                                          .elevatedButtonTheme
                                          .style
                                          ?.backgroundColor
                                          ?.resolve({}) ??
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context)
                                          .elevatedButtonTheme
                                          .style
                                          ?.foregroundColor
                                          ?.resolve({}) ??
                                      Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  _amStart == null
                                      ? '時刻を選択'
                                      : _formatTime24Hour(_amStart!),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '午後',
                                style: TextStyle(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _pickTime(false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context)
                                          .elevatedButtonTheme
                                          .style
                                          ?.backgroundColor
                                          ?.resolve({}) ??
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context)
                                          .elevatedButtonTheme
                                          .style
                                          ?.foregroundColor
                                          ?.resolve({}) ??
                                      Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  _pmStart == null
                                      ? '時刻を選択'
                                      : _formatTime24Hour(_pmStart!),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _generateSchedule,
                icon: Icon(Icons.auto_awesome),
                label: Text('スケジュール自動作成'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF8225),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  elevation: 4,
                ),
              ),
            ),
            if (_inputErrorMsg.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  _inputErrorMsg,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (_overflowMsg.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(_overflowMsg, style: TextStyle(color: Colors.red)),
              ),
            SizedBox(height: 20),
            if (_inputErrorMsg.isEmpty) ...[
              if (_futureResult != null)
                FutureBuilder<RoastScheduleData>(
                  future: _futureResult,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'スケジュール生成中にエラーが発生しました。',
                        style: TextStyle(color: Colors.red),
                      );
                    }
                    if (!snapshot.hasData) return SizedBox();
                    final data = snapshot.data!;
                    // スケジュール生成完了後、一度だけダイアログを表示
                    if (!_dialogShown) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showScheduleDialog(
                          context,
                          data.amResult,
                          data.pmResult,
                          data.overflowMsg,
                        );
                        setState(() {
                          _dialogShown = true;
                        });
                      });
                    }
                    return SizedBox();
                  },
                )
              else
                SizedBox(),
            ],
          ],
        ),
      ),
    );
  }

  // --- スケジュール表示ウィジェット ---
  Widget _buildScheduleWidgets(
    BuildContext context,
    List<RoastScheduleResult> amResult,
    List<RoastScheduleResult> pmResult,
    String overflowMsg,
    Color brown,
  ) {
    final scheduleWidgets = <Widget>[];
    int totalWeight = 0;
    // 合計グラム数を計算
    for (final r in [...amResult, ...pmResult]) {
      if (r.task != null && r.task!.weights.isNotEmpty) {
        totalWeight += r.task!.weights.reduce((a, b) => a + b);
      }
    }
    // 200g, 300g, 500gで割った余りを計算し、最小余りを端数とする
    final List<int> candidateUnits = [200, 300, 500];
    int minRemainder = totalWeight;
    int bestUnit = 200;
    for (final u in candidateUnits) {
      final rem = totalWeight % u;
      if (rem < minRemainder) {
        minRemainder = rem;
        bestUnit = u;
      }
    }
    final int remainder = minRemainder;
    final int unit = bestUnit;

    // 午前セクション
    if (_amStart != null && amResult.isNotEmpty) {
      scheduleWidgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: 56, // 高さを完全固定
          width: double.infinity, // 横幅を揃える
          decoration: BoxDecoration(
            color: Color(0xFFFF5722).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFFF5722).withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                color: Color(0xFFFF5722),
                size: 24,
              ),
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFFF5722).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatTime24Hour(_amStart!),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5722),
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                '予熱開始',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );

      for (final r in amResult) {
        if (r.afterPurge) {
          scheduleWidgets.add(
            Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 統一
              height: 56, // 高さを完全固定
              width: double.infinity, // 横幅を揃える
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1), // 青系統
                borderRadius: BorderRadius.circular(8), // 統一
                border: Border.all(
                  color: Color(0xFF2196F3).withOpacity(0.3),
                ), // 統一
              ),
              child: Row(
                children: [
                  Icon(Icons.ac_unit, color: Color(0xFF2196F3), size: 24), // 統一
                  SizedBox(width: 10),
                  Text(
                    'アフターパージ',
                    style: TextStyle(
                      color: Colors.black, // 統一
                      fontWeight: FontWeight.bold, // 統一
                      fontSize: 15, // 統一
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // ★予熱開始・アフターパージと同じデザイン・レイアウトで焙煎項目を表示（1行横並び、はみ出し防止）
          scheduleWidgets.add(
            Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              height: 56, // 高さを完全固定
              width: double.infinity, // 横幅を揃える
              decoration: BoxDecoration(
                color: Color(0xFF795548).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // コーヒーカップアイコン削除
                    if (r.time != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF795548).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatTime24Hour(r.time!),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF795548),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    SizedBox(width: 10),
                    if (r.task != null)
                      BeanNameWithSticker(
                        beanName: r.task!.type,
                        textStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                        stickerSize: 18,
                      ),
                    SizedBox(width: 10),
                    if (r.task != null)
                      Text(
                        r.task!.weights.map((w) => '${w}g').join('・'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(width: 10),
                    if (r.task != null && r.task!.roastLevel.isNotEmpty)
                      Text(
                        r.task!.roastLevel,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }
    // 午後セクション
    if (_pmStart != null && pmResult.isNotEmpty) {
      scheduleWidgets.add(
        Container(
          margin: EdgeInsets.only(top: 16, bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: 56, // 高さを完全固定
          width: double.infinity, // 横幅を揃える
          decoration: BoxDecoration(
            color: Color(0xFFFF5722).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFFF5722).withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                color: Color(0xFFFF5722),
                size: 24,
              ),
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFFF5722).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatTime24Hour(_pmStart!),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5722),
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                '予熱開始',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
      for (final r in pmResult) {
        if (r.afterPurge) {
          scheduleWidgets.add(
            Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 統一
              height: 56, // 高さを完全固定
              width: double.infinity, // 横幅を揃える
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withOpacity(0.1), // 青系統
                borderRadius: BorderRadius.circular(8), // 統一
                border: Border.all(
                  color: Color(0xFF2196F3).withOpacity(0.3),
                ), // 統一
              ),
              child: Row(
                children: [
                  Icon(Icons.ac_unit, color: Color(0xFF2196F3), size: 24), // 統一
                  SizedBox(width: 10),
                  Text(
                    'アフターパージ',
                    style: TextStyle(
                      color: Colors.black, // 統一
                      fontWeight: FontWeight.bold, // 統一
                      fontSize: 15, // 統一
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // ★予熱開始・アフターパージと同じデザイン・レイアウトで焙煎項目を表示（1行横並び、はみ出し防止）
          scheduleWidgets.add(
            Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              height: 56, // 高さを完全固定
              width: double.infinity, // 横幅を揃える
              decoration: BoxDecoration(
                color: Color(0xFF795548).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF795548).withOpacity(0.3)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // コーヒーカップアイコン削除
                    if (r.time != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF795548).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatTime24Hour(r.time!),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF795548),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    SizedBox(width: 10),
                    if (r.task != null)
                      Text(
                        r.task!.type,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(width: 10),
                    if (r.task != null)
                      Text(
                        r.task!.weights.map((w) => '${w}g').join('・'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(width: 10),
                    if (r.task != null && r.task!.roastLevel.isNotEmpty)
                      Text(
                        r.task!.roastLevel,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }
    if (overflowMsg.isNotEmpty) {
      scheduleWidgets.add(
        Container(
          margin: EdgeInsets.only(top: 8),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  overflowMsg,
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: scheduleWidgets,
    );
  }

  // --- 入力内容の保存・復元 ---
  Future<void> _saveInputState() async {
    final provider = Provider.of<RoastScheduleFormProvider>(
      context,
      listen: false,
    );
    final beans = provider.beans;
    final prefs = await SharedPreferences.getInstance();
    final beansJson = json.encode(beans.map((b) => b.toJson()).toList());
    await prefs.setString('roastSchedule_beans', beansJson);
    if (_amStart != null) {
      await prefs.setString('roastSchedule_amStart', _amStart!.format(context));
    }
    if (_pmStart != null) {
      await prefs.setString('roastSchedule_pmStart', _pmStart!.format(context));
    }
    final groupProvider = context.read<GroupProvider>();
    if (groupProvider.groups.isNotEmpty) {
      final group = groupProvider.groups.first;
      // グループ用のローストスケジュール保存・取得APIはsyncSchedule/getGroupScheduleを利用
      await GroupDataSyncService.syncSchedule(group.id, {
        'beans': beans.map((b) => b.toJson()).toList(),
        'amStart': _amStart?.format(context),
        'pmStart': _pmStart?.format(context),
      });
    }
  }

  Future<void> _restoreInputState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final provider = Provider.of<RoastScheduleFormProvider>(
        context,
        listen: false,
      );
      final beansJson = prefs.getString('roastInput_beans');
      if (beansJson != null) {
        final List<dynamic> beansList = json.decode(beansJson);
        setState(() {
          provider.beans = beansList
              .map<RoastScheduleBean>((e) => RoastScheduleBean.fromJson(e))
              .toList();
          if (provider.beans.isEmpty) {
            provider.beans = [];
          }
        });
      } else {
        setState(() {
          provider.beans = [];
        });
      }
      final amStr = prefs.getString('roastInput_am');
      if (amStr != null && amStr.isNotEmpty) {
        final parts = amStr.split(':');
        if (parts.length == 2) {
          setState(() {
            _amStart = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          });
        }
      }
      final pmStr = prefs.getString('roastInput_pm');
      if (pmStr != null && pmStr.isNotEmpty) {
        final parts = pmStr.split(':');
        if (parts.length == 2) {
          setState(() {
            _pmStart = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadGroupRoastSchedule() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        final data = await GroupDataSyncService.getGroupSchedule(group.id);
        if (data != null) {
          // ここでdataからbeansや時刻などをセットする処理を追加
          // 例: setState(() { ... });
        }
      }
    } catch (e) {
      print('グループ焙煎スケジュール取得エラー: $e');
    }
  }

  Widget _buildBeanInputRow(RoastScheduleBean bean, int index) {
    final provider = Provider.of<RoastScheduleFormProvider>(
      context,
      listen: false,
    );
    final brown = const Color(0xFF795548);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color:
          Provider.of<ThemeSettings>(context).backgroundColor2 ?? Colors.white,
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1行目：豆の名前・重量
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.coffee,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '豆の名前',
                        style: TextStyle(
                          color: Provider.of<ThemeSettings>(context).fontColor1,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 6),
                      TextFormField(
                        initialValue: bean.name,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).buttonColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Provider.of<ThemeSettings>(
                            context,
                          ).inputBackgroundColor,
                        ),
                        onChanged: (val) {
                          provider.updateBean(
                            index,
                            RoastScheduleBean(
                              name: val,
                              weight: bean.weight,
                              bags: bean.bags,
                              roastLevel: bean.roastLevel,
                            ),
                          );
                          _saveInputState(); // 変更時に保存
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                Icon(
                  Icons.scale,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '重量',
                        style: TextStyle(
                          color: Provider.of<ThemeSettings>(context).fontColor1,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 6),
                      TextFormField(
                        initialValue: bean.weight.toString(),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: brown, width: 2),
                          ),
                          filled: true,
                          fillColor: Provider.of<ThemeSettings>(
                            context,
                          ).inputBackgroundColor,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          final weight = int.tryParse(val) ?? 0;
                          provider.updateBean(
                            index,
                            RoastScheduleBean(
                              name: bean.name,
                              weight: weight,
                              bags: bean.bags,
                              roastLevel: bean.roastLevel,
                            ),
                          );
                          _saveInputState(); // 変更時に保存
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // 2行目：袋数・焙煎度合い・削除ボタン
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag,
                      color: Provider.of<ThemeSettings>(context).iconColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '袋数',
                            style: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 6),
                          TextFormField(
                            initialValue: bean.bags?.toString() ?? '',
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: brown, width: 2),
                              ),
                              filled: true,
                              fillColor: Provider.of<ThemeSettings>(
                                context,
                              ).inputBackgroundColor,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final bags = int.tryParse(val);
                              provider.updateBean(
                                index,
                                RoastScheduleBean(
                                  name: bean.name,
                                  weight: bean.weight,
                                  bags: bags,
                                  roastLevel: bean.roastLevel,
                                ),
                              );
                              _saveInputState(); // 変更時に保存
                            },
                          ),
                        ],
                      ),
                    ),
                    ...[
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                          size: 28,
                        ),
                        onPressed: () => _removeBean(index),
                        iconSize: 28,
                        padding: EdgeInsets.all(8),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Provider.of<ThemeSettings>(context).iconColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '焙煎度合い',
                            style: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: bean.roastLevel,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: brown, width: 2),
                              ),
                              filled: true,
                              fillColor: Provider.of<ThemeSettings>(
                                context,
                              ).inputBackgroundColor,
                            ),
                            items: ['浅煎り', '中煎り', '中深煎り', '深煎り']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              provider.updateBean(
                                index,
                                RoastScheduleBean(
                                  name: bean.name,
                                  weight: bean.weight,
                                  bags: bean.bags,
                                  roastLevel: val,
                                ),
                              );
                              _saveInputState(); // 変更時に保存
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  RoastBreakTime? _findBreak(TimeOfDay t) {
    for (final b in widget.breakTimes) {
      final tMinutes = t.hour * 60 + t.minute;
      final breakStart = b.start.hour * 60 + b.start.minute;
      if (tMinutes >= (breakStart - 10) &&
          tMinutes < b.end.hour * 60 + b.end.minute) {
        return b;
      }
    }
    return null;
  }

  // スケジュールダイアログ表示メソッド
  void _showScheduleDialog(
    BuildContext context,
    List<RoastScheduleResult> amResult,
    List<RoastScheduleResult> pmResult,
    String overflowMsg,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Provider.of<ThemeSettings>(
            context,
          ).dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Provider.of<ThemeSettings>(context).appBarColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Provider.of<ThemeSettings>(
                          context,
                        ).appBarTextColor,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ローストスケジュール',
                          style: TextStyle(
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).appBarTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Provider.of<ThemeSettings>(
                            context,
                          ).appBarTextColor,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // スケジュール内容
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: _buildScheduleWidgets(
                      context,
                      amResult,
                      pmResult,
                      overflowMsg,
                      Color(0xFF795548),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
