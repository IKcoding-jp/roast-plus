import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/roast_break_time.dart';
import '../../services/roast_break_time_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class RoastBreakTimeEditPage extends StatefulWidget {
  final List<RoastBreakTime> breakTimes;
  final void Function(List<RoastBreakTime>) onBreakTimesChanged;
  const RoastBreakTimeEditPage({
    super.key,
    required this.breakTimes,
    required this.onBreakTimesChanged,
  });

  @override
  State<RoastBreakTimeEditPage> createState() => _RoastBreakTimeEditPageState();
}

class _RoastBreakTimeEditPageState extends State<RoastBreakTimeEditPage> {
  late List<RoastBreakTime> _breakTimes;
  final _startHourController = TextEditingController();
  final _startMinuteController = TextEditingController();
  final _endHourController = TextEditingController();
  final _endMinuteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _breakTimes = List.from(widget.breakTimes);
    _loadBreakTimesFromFirestore();
    _startBreakTimesListener();
  }

  Future<void> _loadBreakTimesFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('roastBreakTimes')
        .doc('settings')
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['breakTimes'] != null) {
        setState(() {
          _breakTimes = List<Map<String, dynamic>>.from(
            data['breakTimes'],
          ).map((e) => RoastBreakTime.fromJson(e)).toList();
        });
      }
    }
  }

  StreamSubscription? _breakTimesSubscription;
  void _startBreakTimesListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _breakTimesSubscription?.cancel();
    _breakTimesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('roastBreakTimes')
        .doc('settings')
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (data['breakTimes'] != null) {
              setState(() {
                _breakTimes = List<Map<String, dynamic>>.from(
                  data['breakTimes'],
                ).map((e) => RoastBreakTime.fromJson(e)).toList();
              });
            }
          }
        });
  }

  @override
  void dispose() {
    _startHourController.dispose();
    _startMinuteController.dispose();
    _endHourController.dispose();
    _endMinuteController.dispose();
    _breakTimesSubscription?.cancel();
    super.dispose();
  }

  void _addBreakTime() {
    final startHour = int.tryParse(_startHourController.text) ?? 0;
    final startMinute = int.tryParse(_startMinuteController.text) ?? 0;
    final endHour = int.tryParse(_endHourController.text) ?? 0;
    final endMinute = int.tryParse(_endMinuteController.text) ?? 0;

    final start = TimeOfDay(hour: startHour, minute: startMinute);
    final end = TimeOfDay(hour: endHour, minute: endMinute);

    // 開始時刻が終了時刻より前であることを確認
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    if (startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('開始時刻は終了時刻より前である必要があります'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newBreakTime = RoastBreakTime(start: start, end: end);

    // 重複チェック
    if (_breakTimes.any(
      (bt) =>
          (bt.start.hour == start.hour && bt.start.minute == start.minute) ||
          (bt.end.hour == end.hour && bt.end.minute == end.minute),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同じ時刻の休憩時間が既に存在します'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _breakTimes.add(newBreakTime);
      _sortBreakTimes();
      _startHourController.clear();
      _startMinuteController.clear();
      _endHourController.clear();
      _endMinuteController.clear();
    });
  }

  void _sortBreakTimes() {
    _breakTimes.sort((a, b) {
      final aMinutes = a.start.hour * 60 + a.start.minute;
      final bMinutes = b.start.hour * 60 + b.start.minute;
      return aMinutes.compareTo(bMinutes);
    });
  }

  void _editBreakTime(int index) {
    final breakTime = _breakTimes[index];
    _startHourController.text = breakTime.start.hour.toString();
    _startMinuteController.text = breakTime.start.minute.toString().padLeft(
      2,
      '0',
    );
    _endHourController.text = breakTime.end.hour.toString();
    _endMinuteController.text = breakTime.end.minute.toString().padLeft(2, '0');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '休憩時間を編集',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startHourController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: false,
                      signed: false,
                    ),
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    decoration: InputDecoration(
                      labelText: '開始時',
                      labelStyle: TextStyle(
                        color: Provider.of<ThemeSettings>(context).fontColor1,
                      ),
                      counterText: '',
                    ),
                    maxLength: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  ':',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _startMinuteController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: false,
                      signed: false,
                    ),
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    decoration: InputDecoration(
                      labelText: '開始分',
                      labelStyle: TextStyle(
                        color: Provider.of<ThemeSettings>(context).fontColor1,
                      ),
                      counterText: '',
                    ),
                    maxLength: 2,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _endHourController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: false,
                      signed: false,
                    ),
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    decoration: InputDecoration(
                      labelText: '終了時',
                      labelStyle: TextStyle(
                        color: Provider.of<ThemeSettings>(context).fontColor1,
                      ),
                      counterText: '',
                    ),
                    maxLength: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  ':',
                  style: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _endMinuteController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: false,
                      signed: false,
                    ),
                    style: TextStyle(
                      color: Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                    decoration: InputDecoration(
                      labelText: '終了分',
                      labelStyle: TextStyle(
                        color: Provider.of<ThemeSettings>(context).fontColor1,
                      ),
                      counterText: '',
                    ),
                    maxLength: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final startHour = int.tryParse(_startHourController.text) ?? 0;
              final startMinute =
                  int.tryParse(_startMinuteController.text) ?? 0;
              final endHour = int.tryParse(_endHourController.text) ?? 0;
              final endMinute = int.tryParse(_endMinuteController.text) ?? 0;

              final start = TimeOfDay(hour: startHour, minute: startMinute);
              final end = TimeOfDay(hour: endHour, minute: endMinute);

              // 開始時刻が終了時刻より前であることを確認
              final startMinutes = startHour * 60 + startMinute;
              final endMinutes = endHour * 60 + endMinute;

              if (startMinutes >= endMinutes) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('開始時刻は終了時刻より前である必要があります'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setState(() {
                _breakTimes[index] = RoastBreakTime(start: start, end: end);
                _sortBreakTimes();
                _startHourController.clear();
                _startMinuteController.clear();
                _endHourController.clear();
                _endMinuteController.clear();
              });
              Navigator.pop(context);
            },
            child: Text(
              '保存',
              style: TextStyle(
                color: Provider.of<ThemeSettings>(context).fontColor2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteBreakTime(int index) {
    setState(() {
      _breakTimes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.free_breakfast,
              color: Provider.of<ThemeSettings>(context).iconColor,
            ),
            SizedBox(width: 8),
            Text(
              '休憩時間編集',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              widget.onBreakTimesChanged(_breakTimes);
              final navigator = Navigator.of(context);
              try {
                await RoastBreakTimeFirestoreService.saveBreakTimes(
                  _breakTimes,
                );
              } catch (_) {}
              if (!mounted) return;
              navigator.pop();
            },
          ),
        ],
        backgroundColor: Provider.of<ThemeSettings>(context).appBarColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // 入力カード
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Provider.of<ThemeSettings>(context).cardBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeInputField(
                              label: '開始時刻',
                              hourController: _startHourController,
                              minuteController: _startMinuteController,
                              icon: Icons.access_time,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildTimeInputField(
                              label: '終了時刻',
                              hourController: _endHourController,
                              minuteController: _endMinuteController,
                              icon: Icons.access_time_filled,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            '休憩時間を追加',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
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
                            padding: EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _addBreakTime,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // 休憩時間リスト
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _breakTimes.length,
                itemBuilder: (context, i) => Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Provider.of<ThemeSettings>(
                    context,
                  ).cardBackgroundColor,
                  margin: EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Provider.of<ThemeSettings>(
                          context,
                        ).iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.free_breakfast,
                        color: Provider.of<ThemeSettings>(context).iconColor,
                      ),
                    ),
                    title: Text(
                      '${_breakTimes[i].start.format(context)} - ${_breakTimes[i].end.format(context)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Provider.of<ThemeSettings>(context).fontColor1,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).iconColor,
                          ),
                          onPressed: () => _editBreakTime(i),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteBreakTime(i),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInputField({
    required String label,
    required TextEditingController hourController,
    required TextEditingController minuteController,
    required IconData icon,
    double fontSize = 17,
    double iconSize = 22,
    double labelFontSize = 16,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Provider.of<ThemeSettings>(context).iconColor,
              size: iconSize,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: labelFontSize,
                color: Provider.of<ThemeSettings>(context).fontColor1,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: hourController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: false,
                  signed: false,
                ),
                style: TextStyle(
                  fontSize: fontSize,
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Provider.of<ThemeSettings>(
                    context,
                  ).inputBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: contentPadding,
                  hintText: '時',
                  hintStyle: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                    fontSize: fontSize,
                  ),
                  counterText: '',
                ),
                maxLength: 2,
              ),
            ),
            SizedBox(width: 8),
            Text(
              ':',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: minuteController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: false,
                  signed: false,
                ),
                style: TextStyle(
                  fontSize: fontSize,
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Provider.of<ThemeSettings>(
                    context,
                  ).inputBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: contentPadding,
                  hintText: '分',
                  hintStyle: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                    fontSize: fontSize,
                  ),
                  counterText: '',
                ),
                maxLength: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
