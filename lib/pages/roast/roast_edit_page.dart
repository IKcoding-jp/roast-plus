import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:bysnapp/main.dart';
import 'package:bysnapp/pages/roast/roast_timer_settings_page.dart';
import 'package:bysnapp/pages/roast/roast_record_page.dart';
import 'package:bysnapp/pages/roast/roast_advisor_page.dart';
import 'package:bysnapp/pages/roast/roast_timer_page.dart';

class RoastEditPage extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const RoastEditPage({super.key, required this.initialData});

  @override
  State<RoastEditPage> createState() => _RoastEditPageState();
}

class _RoastEditPageState extends State<RoastEditPage> {
  late TextEditingController _beanController;
  late TextEditingController _weightController;
  late TextEditingController _minuteController;
  late TextEditingController _secondController;
  late String _selectedRoast;
  late String _side;
  late String _timestamp;

  @override
  void initState() {
    super.initState();
    final timeParts =
        (widget.initialData['time'] as String?)?.split(':') ?? ['0', '0'];
    _beanController = TextEditingController(
      text: widget.initialData['bean'] ?? '',
    );
    _weightController = TextEditingController(
      text: widget.initialData['weight'] ?? '',
    );
    _minuteController = TextEditingController(text: timeParts[0]);
    _secondController = TextEditingController(
      text: timeParts.length > 1 ? timeParts[1] : '0',
    );
    _selectedRoast = widget.initialData['roast'] ?? '中煎り';
    _side = widget.initialData['side'] ?? 'A台';
    _timestamp =
        widget.initialData['timestamp'] ?? DateTime.now().toIso8601String();
  }

  void _saveChanges() {
    final updated = {
      'bean': _beanController.text.trim(),
      'weight': _weightController.text.trim(),
      'time':
          '${_minuteController.text.trim().padLeft(2, '0')}:${_secondController.text.trim().padLeft(2, '0')}',
      'roast': _selectedRoast,
      'side': _side,
      'timestamp': _timestamp,
    };
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('記録の編集')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _beanController,
              decoration: const InputDecoration(labelText: '豆の種類'),
            ),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: '重さ（g）'),
              keyboardType: TextInputType.number,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minuteController,
                    decoration: const InputDecoration(labelText: '分'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _secondController,
                    decoration: const InputDecoration(labelText: '秒'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              value: _selectedRoast,
              decoration: const InputDecoration(labelText: '煎り度'),
              items: [
                '浅煎り',
                '中煎り',
                '中深煎り',
                '深煎り',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedRoast = v!),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
