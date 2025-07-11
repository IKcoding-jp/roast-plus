import 'package:flutter/material.dart';
import '../../services/todayschedule_firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class ScheduleTimeLabelEditPage extends StatefulWidget {
  final List<String> labels;
  final void Function(List<String>) onLabelsChanged;
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
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
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

  void _addLabel() {
    final hour = int.tryParse(_hourController.text) ?? 0;
    final minute = int.tryParse(_minuteController.text) ?? 0;
    final label =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    if (_labels.contains(label)) return;
    setState(() {
      _labels.add(label);
      _sortLabels();
      _hourController.clear();
      _minuteController.clear();
    });
  }

  void _editLabel(int index) {
    final parts = _labels[index].split(':');
    _hourController.text = parts[0];
    _minuteController.text = parts.length > 1 ? parts[1] : '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('時間ラベルを編集'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hourController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '時', counterText: ''),
              ),
            ),
            SizedBox(width: 8),
            Text(':'),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _minuteController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '分', counterText: ''),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
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
              }
              Navigator.pop(context);
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
  }

  void _deleteLabel(int index) {
    setState(() {
      _labels.removeAt(index);
      _sortLabels();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.access_time,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            SizedBox(width: 8),
            Text(
              '時間ラベル編集',
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
              widget.onLabelsChanged(_labels);
              try {
                await ScheduleFirestoreService.saveTimeLabels(_labels);
              } catch (_) {}
              Navigator.pop(context);
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
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.access_time,
                              color: Color(0xFF795548),
                            ),
                            labelText: '時',
                            filled: true,
                            fillColor: Colors.grey.shade50,
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
                                color: Color(0xFF795548),
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
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _minuteController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: '分',
                            filled: true,
                            fillColor: Colors.grey.shade50,
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
                                color: Color(0xFF795548),
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
                        color: Color(0xFF795548).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.access_time, color: Color(0xFF795548)),
                    ),
                    title: Text(
                      _labels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C1D17),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Color(0xFF795548)),
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
