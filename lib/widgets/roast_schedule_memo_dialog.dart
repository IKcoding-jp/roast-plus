import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:roastplus/models/roast_schedule_models.dart';
import 'package:roastplus/models/theme_settings.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class RoastScheduleMemoDialog extends StatefulWidget {
  final RoastScheduleMemo? memo;
  final Function(RoastScheduleMemo) onSave;

  const RoastScheduleMemoDialog({super.key, this.memo, required this.onSave});

  @override
  State<RoastScheduleMemoDialog> createState() =>
      _RoastScheduleMemoDialogState();
}

class _RoastScheduleMemoDialogState extends State<RoastScheduleMemoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _timeController = TextEditingController();
  final _beanNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _quantityController = TextEditingController();
  String? _selectedRoastLevel;
  bool _isAfterPurge = false;
  bool _isRoasterOn = false;

  final List<String> _roastLevels = ['浅煎り', '中煎り', '中深煎り', '深煎り'];

  @override
  void initState() {
    super.initState();
    if (widget.memo != null) {
      _timeController.text = widget.memo!.time;
      _beanNameController.text = widget.memo!.beanName ?? '';
      _weightController.text = widget.memo!.weight?.toString() ?? '';
      _quantityController.text = widget.memo!.quantity?.toString() ?? '';
      _selectedRoastLevel = widget.memo!.roastLevel;
      _isAfterPurge = widget.memo!.isAfterPurge;
      _isRoasterOn = widget.memo!.isRoasterOn;
    } else {
      _timeController.text = '10:30';
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _beanNameController.dispose();
    _weightController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final timeParts = _timeController.text.split(':');
    int hour = 10;
    int minute = 30;

    if (timeParts.length == 2) {
      hour = int.tryParse(timeParts[0]) ?? 10;
      minute = int.tryParse(timeParts[1]) ?? 30;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _saveMemo() {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();
      final today = DateTime.now();
      final memo = RoastScheduleMemo(
        id: widget.memo?.id ?? const Uuid().v4(),
        time: _timeController.text,
        beanName: _beanNameController.text.isNotEmpty
            ? _beanNameController.text
            : null,
        weight: int.tryParse(_weightController.text),
        quantity: int.tryParse(_quantityController.text),
        roastLevel: _selectedRoastLevel,
        isAfterPurge: _isAfterPurge,
        isRoasterOn: _isRoasterOn,
        date: widget.memo?.date ?? today,
        createdAt: widget.memo?.createdAt ?? now,
        updatedAt: now,
      );

      widget.onSave(memo);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Dialog(
      backgroundColor: themeSettings.dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: kIsWeb ? 500 : MediaQuery.of(context).size.width * 0.9,
          maxHeight: kIsWeb ? 700 : MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeSettings.appBarColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    color: themeSettings.appBarTextColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.memo == null ? 'メモを追加' : 'メモを編集',
                      style: TextStyle(
                        color: themeSettings.appBarTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: themeSettings.appBarTextColor,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // フォーム
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(kIsWeb ? 24 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 時間
                      Text(
                        '時間',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectTime,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _timeController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: Icon(Icons.access_time),
                              labelText: '時間を選択',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '時間を入力してください';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // 焙煎機オンチェックボックス
                      Row(
                        children: [
                          Checkbox(
                            value: _isRoasterOn,
                            onChanged: (value) {
                              setState(() {
                                _isRoasterOn = value ?? false;
                                if (_isRoasterOn) {
                                  _isAfterPurge = false;
                                }
                              });
                            },
                          ),
                          Text(
                            '焙煎機オン',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // アフターパージチェックボックス
                      Row(
                        children: [
                          Checkbox(
                            value: _isAfterPurge,
                            onChanged: (value) {
                              setState(() {
                                _isAfterPurge = value ?? false;
                                if (_isAfterPurge) {
                                  _isRoasterOn = false;
                                }
                              });
                            },
                          ),
                          Text(
                            'アフターパージ',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // 豆の名前（焙煎機オンでもアフターパージでもない場合のみ表示）
                      if (!_isAfterPurge && !_isRoasterOn) ...[
                        Text(
                          '豆の名前（任意）',
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _beanNameController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelText: '豆の名前',
                          ),
                        ),
                        SizedBox(height: 16),

                        // 重さと個数
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '重さ（g）',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    controller: _weightController,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      labelText: '重さ',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '個数',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    controller: _quantityController,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      labelText: '個数',
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // 焙煎度合い
                        Text(
                          '焙煎度合い（任意）',
                          style: TextStyle(
                            color: themeSettings.fontColor1,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRoastLevel,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelText: '焙煎度合いを選択',
                          ),
                          items: _roastLevels.map((level) {
                            return DropdownMenuItem(
                              value: level,
                              child: Text(level),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRoastLevel = value;
                            });
                          },
                        ),
                      ] else ...[
                        // 焙煎機オンまたはアフターパージの場合
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (_isAfterPurge ? Colors.blue : Colors.orange)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  (_isAfterPurge ? Colors.blue : Colors.orange)
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isAfterPurge
                                    ? Icons.ac_unit
                                    : Icons.local_fire_department,
                                color: _isAfterPurge
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                              SizedBox(width: 12),
                              Text(
                                _isAfterPurge ? 'アフターパージ' : '焙煎機オン',
                                style: TextStyle(
                                  color: _isAfterPurge
                                      ? Colors.blue
                                      : Colors.orange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // ボタン
            Container(
              padding: EdgeInsets.all(kIsWeb ? 24 : 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveMemo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeSettings.appButtonColor,
                        foregroundColor: themeSettings.fontColor2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
