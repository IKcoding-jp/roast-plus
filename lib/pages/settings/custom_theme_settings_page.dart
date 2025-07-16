import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';

class CustomThemeSettingsPage extends StatefulWidget {
  const CustomThemeSettingsPage({super.key});

  @override
  State<CustomThemeSettingsPage> createState() =>
      _CustomThemeSettingsPageState();
}

class _CustomThemeSettingsPageState extends State<CustomThemeSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('カスタム設定'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: Container(
        color: themeSettings.backgroundColor,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // 基本色設定セクション
            _buildBasicColorsSection(context, themeSettings),
            const SizedBox(height: 24),

            // テキスト色設定セクション
            _buildTextColorsSection(context, themeSettings),
            const SizedBox(height: 24),

            // UI要素色設定セクション
            _buildUIColorsSection(context, themeSettings),
            const SizedBox(height: 24),

            // 保存ボタン
            _buildSaveButton(context, themeSettings),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicColorsSection(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.backgroundColor2 ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  '基本色設定',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '背景色',
              color: themeSettings.backgroundColor,
              onColorChanged: themeSettings.updateBackgroundColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'カード・パネルの背景色',
              color: themeSettings.backgroundColor2 ?? Colors.white,
              onColorChanged: themeSettings.updateBackgroundColor2,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '画面上部の色',
              color: themeSettings.appBarColor,
              onColorChanged: themeSettings.updateAppBarColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '画面下部の色',
              color: themeSettings.bottomNavigationColor,
              onColorChanged: themeSettings.updateBottomNavigationColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextColorsSection(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.backgroundColor2 ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  'テキスト色設定',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '通常の文字色',
              color: themeSettings.fontColor1,
              onColorChanged: themeSettings.updateFontColor1,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '画面上部の文字色',
              color: themeSettings.appBarTextColor,
              onColorChanged: themeSettings.updateAppBarTextColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '画面下部の文字色',
              color: themeSettings.bottomNavigationTextColor,
              onColorChanged: themeSettings.updateBottomNavigationTextColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'ボタンの文字色',
              color: themeSettings.fontColor2,
              onColorChanged: themeSettings.updateFontColor2,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '入力欄の文字色',
              color: themeSettings.inputTextColor,
              onColorChanged: themeSettings.updateInputTextColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'ダイアログの文字色',
              color: themeSettings.dialogTextColor,
              onColorChanged: themeSettings.updateDialogTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUIColorsSection(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.backgroundColor2 ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  'UI要素色設定',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'ボタンの色',
              color: themeSettings.buttonColor,
              onColorChanged: themeSettings.updateButtonColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'アイコンの色',
              color: themeSettings.iconColor,
              onColorChanged: themeSettings.updateIconColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '入力欄の背景',
              color: themeSettings.inputBackgroundColor,
              onColorChanged: themeSettings.updateInputBackgroundColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'メンバーの背景色',
              color: themeSettings.memberBackgroundColor,
              onColorChanged: themeSettings.updateMemberBackgroundColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'タイマーの円の色',
              color: themeSettings.timerCircleColor,
              onColorChanged: themeSettings.updateTimerCircleColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'ダイアログの背景色',
              color: themeSettings.dialogBackgroundColor,
              onColorChanged: themeSettings.updateDialogBackgroundColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, ThemeSettings themeSettings) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.backgroundColor2 ?? Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.save, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  'カスタムテーマの保存',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('現在の設定をカスタムテーマとして保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSettings.buttonColor,
                  foregroundColor: themeSettings.fontColor2,
                  textStyle: const TextStyle(fontSize: 16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  _showSaveCustomThemeDialog(context, themeSettings);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveCustomThemeDialog(
    BuildContext context,
    ThemeSettings themeSettings,
  ) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeSettings.dialogBackgroundColor,
        title: Text(
          'カスタムテーマを保存',
          style: TextStyle(
            color: themeSettings.dialogTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'テーマ名を入力してください',
              style: TextStyle(
                color: themeSettings.dialogTextColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: TextStyle(
                color: themeSettings.inputTextColor,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: 'テーマ名',
                labelStyle: TextStyle(color: themeSettings.inputTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: themeSettings.inputBackgroundColor,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: TextStyle(color: themeSettings.dialogTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final themeName = nameController.text.trim();
              if (themeName.isNotEmpty) {
                final themeData = {
                  'appBarColor': themeSettings.appBarColor,
                  'backgroundColor': themeSettings.backgroundColor,
                  'buttonColor': themeSettings.buttonColor,
                  'backgroundColor2': themeSettings.backgroundColor2,
                  'fontColor1': themeSettings.fontColor1,
                  'fontColor2': themeSettings.fontColor2,
                  'iconColor': themeSettings.iconColor,
                  'timerCircleColor': themeSettings.timerCircleColor,
                  'bottomNavigationColor': themeSettings.bottomNavigationColor,
                  'inputBackgroundColor': themeSettings.inputBackgroundColor,
                  'memberBackgroundColor': themeSettings.memberBackgroundColor,
                  'appBarTextColor': themeSettings.appBarTextColor,
                  'bottomNavigationTextColor':
                      themeSettings.bottomNavigationTextColor,
                  'dialogBackgroundColor': themeSettings.dialogBackgroundColor,
                  'dialogTextColor': themeSettings.dialogTextColor,
                  'inputTextColor': themeSettings.inputTextColor,
                };
                await ThemeSettings.saveCustomTheme(themeName, themeData);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$themeName として保存しました'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeSettings.buttonColor,
              foregroundColor: themeSettings.fontColor2,
            ),
            child: const Text('保存'),
          ),
        ],
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
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: themeSettings.backgroundColor2 ?? Colors.white,
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeSettings.fontColor1,
          ),
        ),
        trailing: Icon(Icons.color_lens, color: color),
        onTap: () async {
          final picked = await showDialog<Color>(
            context: context,
            builder: (context) =>
                _ColorPickerDialog(initialColor: color, label: label),
          );
          if (picked != null) onColorChanged(picked);
        },
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String label;
  const _ColorPickerDialog({required this.initialColor, required this.label});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color;
  late ThemeSettings themeSettings;

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    themeSettings = Provider.of<ThemeSettings>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: themeSettings.backgroundColor2 ?? Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // タイトル
            Text(
              '${widget.label}の色を選択',
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 現在の色と選択中の色の比較
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '現在の色',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: widget.initialColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeSettings.fontColor1.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '選択中の色',
                        style: TextStyle(
                          color: themeSettings.fontColor1,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: themeSettings.fontColor1.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 色選択器（残りのスペースをすべて使用）
            Expanded(
              child: MaterialPicker(
                pickerColor: _color,
                onColorChanged: (c) => setState(() => _color = c),
                enableLabel: false,
              ),
            ),
            const SizedBox(height: 16),
            // ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: themeSettings.fontColor1,
                  ),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _color),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeSettings.buttonColor,
                    foregroundColor: themeSettings.fontColor2,
                  ),
                  child: const Text('決定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
