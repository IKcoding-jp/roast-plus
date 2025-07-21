import 'package:flutter/material.dart';
import '../../services/group_data_sync_service.dart';
import '../../models/group_provider.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/schedule_firestore_service.dart' as ScheduleService;

class ScheduleTimeLabelEditPage extends StatefulWidget {
  final List<String> labels;
  final Future<void> Function(List<String>) onLabelsChanged;
  const ScheduleTimeLabelEditPage({
    super.key,
    required this.labels,
    required this.onLabelsChanged,
  });

  @override
  State<ScheduleTimeLabelEditPage> createState() =>
      _ScheduleTimeLabelEditPageState();
}

class _ScheduleTimeLabelEditPageState extends State<ScheduleTimeLabelEditPage> {
  late List<String> _labels;
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _labels = List.from(widget.labels);
    print('ScheduleTimeLabelEditPage: initState - 初期ラベル: $_labels');
    print(
      'ScheduleTimeLabelEditPage: onLabelsChangedコールバック存在: ${widget.onLabelsChanged != null}',
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ページを閉じる際に最終保存を実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _autoSave();
      }
    });
  }

  void _sortLabels() {
    _labels.sort((a, b) {
      final aParts = a.split(':');
      final bParts = b.split(':');
      final aMinutes =
          (int.tryParse(aParts[0]) ?? 0) * 60 + (int.tryParse(aParts[1]) ?? 0);
      final bMinutes =
          (int.tryParse(bParts[0]) ?? 0) * 60 + (int.tryParse(bParts[1]) ?? 0);
      return aMinutes.compareTo(bMinutes);
    });
  }

  void _addLabel() async {
    final hour = int.tryParse(_hourController.text) ?? 0;
    final minute = int.tryParse(_minuteController.text) ?? 0;
    final label =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    print(
      'ScheduleTimeLabelEditPage: 時間ラベル追加試行 - 入力: ${_hourController.text}:${_minuteController.text}',
    );
    print('ScheduleTimeLabelEditPage: 生成されたラベル: $label');
    print('ScheduleTimeLabelEditPage: 現在のラベル数: ${_labels.length}');
    print('ScheduleTimeLabelEditPage: 既存のラベル: $_labels');

    if (_labels.contains(label)) {
      print('ScheduleTimeLabelEditPage: ラベルが既に存在するため追加をスキップ');
      return;
    }

    setState(() {
      _labels.add(label);
      _sortLabels();
      _hourController.clear();
      _minuteController.clear();
    });

    print('ScheduleTimeLabelEditPage: ラベル追加完了 - 新しいラベル数: ${_labels.length}');
    print('ScheduleTimeLabelEditPage: 更新後のラベル: $_labels');

    // 自動保存
    await _autoSave();
  }

  void _editLabel(int index) {
    final parts = _labels[index].split(':');
    _hourController.text = parts[0];
    _minuteController.text = parts.length > 1 ? parts[1] : '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '時間ラベルを編集',
          style: TextStyle(
            color: Provider.of<ThemeSettings>(context).fontColor1,
          ),
        ),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hourController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: false,
                  signed: false,
                ),
                style: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
                decoration: InputDecoration(
                  labelText: '時',
                  labelStyle: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                  counterText: '',
                ),
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
                controller: _minuteController,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: false,
                  signed: false,
                ),
                style: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                ),
                decoration: InputDecoration(
                  labelText: '分',
                  labelStyle: TextStyle(
                    color: Provider.of<ThemeSettings>(context).fontColor1,
                  ),
                  counterText: '',
                ),
              ),
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
            onPressed: () async {
              final hour = int.tryParse(_hourController.text) ?? 0;
              final minute = int.tryParse(_minuteController.text) ?? 0;
              final newLabel =
                  '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
              if (newLabel.isNotEmpty && !_labels.contains(newLabel)) {
                setState(() {
                  _labels[index] = newLabel;
                  _sortLabels();
                  _hourController.clear();
                  _minuteController.clear();
                });

                // 自動保存
                await _autoSave();
              }
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

  void _deleteLabel(int index) async {
    setState(() {
      _labels.removeAt(index);
      _sortLabels();
    });

    // 自動保存
    await _autoSave();
  }

  // 自動保存メソッド
  Future<void> _autoSave() async {
    if (widget.onLabelsChanged != null) {
      try {
        print('ScheduleTimeLabelEditPage: 自動保存開始 - ラベル数: ${_labels.length}');
        await widget.onLabelsChanged(_labels);
        print('ScheduleTimeLabelEditPage: 自動保存完了');
      } catch (e) {
        print('ScheduleTimeLabelEditPage: 自動保存エラー: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.access_time,
              color: Provider.of<ThemeSettings>(context).iconColor,
            ),
            SizedBox(width: 8),
            Text(
              '時間ラベル編集',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            // グループ状態バッジを追加
            Consumer<GroupProvider>(
              builder: (context, groupProvider, _) {
                if (groupProvider.groups.isNotEmpty) {
                  return Container(
                    margin: EdgeInsets.only(left: 12),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade400),
                    ),
                    child: Icon(
                      Icons.groups,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ],
        ),
        actions: [],
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
                color:
                    Provider.of<ThemeSettings>(context).backgroundColor2 ??
                    Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hourController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: false,
                            signed: false,
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.access_time,
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).iconColor,
                            ),
                            labelText: '時',
                            labelStyle: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                            ),
                            filled: true,
                            fillColor: Provider.of<ThemeSettings>(
                              context,
                            ).inputBackgroundColor,
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
                              borderSide: BorderSide(
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).buttonColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
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
                          controller: _minuteController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: false,
                            signed: false,
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                          decoration: InputDecoration(
                            labelText: '分',
                            labelStyle: TextStyle(
                              color: Provider.of<ThemeSettings>(
                                context,
                              ).fontColor1,
                            ),
                            filled: true,
                            fillColor: Provider.of<ThemeSettings>(
                              context,
                            ).inputBackgroundColor,
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
                              borderSide: BorderSide(
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).buttonColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            counterText: '',
                          ),
                          maxLength: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addLabel,
                        icon: Icon(Icons.add, size: 20),
                        label: Text(
                          '追加',
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
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // ラベルリスト
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _labels.length,
                itemBuilder: (context, i) => Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color:
                      Provider.of<ThemeSettings>(context).backgroundColor2 ??
                      Colors.white,
                  margin: EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Provider.of<ThemeSettings>(
                          context,
                        ).iconColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.access_time,
                        color: Provider.of<ThemeSettings>(context).iconColor,
                      ),
                    ),
                    title: Text(
                      _labels[i],
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
                          onPressed: () => _editLabel(i),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteLabel(i),
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
}
