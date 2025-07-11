import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('テーマ設定'),
        backgroundColor: themeSettings.appBarColor,
      ),
      body: Container(
        color: themeSettings.backgroundColor,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _ColorPickerTile(
              label: 'AppBarの色',
              color: themeSettings.appBarColor,
              onColorChanged: themeSettings.updateAppBarColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '背景色',
              color: themeSettings.backgroundColor,
              onColorChanged: themeSettings.updateBackgroundColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '背景色2（カード・パネル）',
              color: themeSettings.backgroundColor2 ?? Colors.white,
              onColorChanged: themeSettings.updateBackgroundColor2,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'ボタン色',
              color: themeSettings.buttonColor,
              onColorChanged: themeSettings.updateButtonColor,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('デフォルトに戻す'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSettings.buttonColor,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  themeSettings.resetToDefault();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('デフォルトの色に戻しました')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerTile extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerTile({
    required this.label,
    required this.color,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Icon(Icons.color_lens, color: color),
        onTap: () async {
          final picked = await showDialog<Color>(
            context: context,
            builder: (context) => _ColorPickerDialog(initialColor: color),
          );
          if (picked != null) onColorChanged(picked);
        },
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('色を選択'),
      content: SingleChildScrollView(
        child: MaterialPicker(
          pickerColor: _color,
          onColorChanged: (c) => setState(() => _color = c),
          enableLabel: false,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('決定'),
        ),
      ],
    );
  }
}
