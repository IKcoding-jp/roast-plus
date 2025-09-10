import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/app_performance_config.dart';
import 'donation_page.dart';

class CustomThemeSettingsPage extends StatefulWidget {
  const CustomThemeSettingsPage({super.key});

  @override
  State<CustomThemeSettingsPage> createState() =>
      _CustomThemeSettingsPageState();
}

class _CustomThemeSettingsPageState extends State<CustomThemeSettingsPage> {
  @override
  void dispose() {
    // デバッグログ: ページが破棄されることを確認
    debugPrint('カスタムテーマ設定ページが破棄されました');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('カスタム設定'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: FutureBuilder<bool>(
        future: isDonorUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volunteer_activism, size: 48, color: Colors.amber),
                  SizedBox(height: 16),
                  Text(
                    'この機能は寄付者限定です',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '300円以上の寄付でテーマカスタマイズが解放されます',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DonationPage()),
                    ),
                    child: Text('寄付して応援する'),
                  ),
                ],
              ),
            );
          }
          // 寄付者は従来UI
          return Container(
            color: themeSettings.backgroundColor,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600, // Web版での最大幅を制限
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      _buildBasicColorsSection(context, themeSettings),
                      const SizedBox(height: 24),
                      _buildTextColorsSection(context, themeSettings),
                      const SizedBox(height: 24),
                      _buildUIColorsSection(context, themeSettings),
                      const SizedBox(height: 24),
                      _buildSaveButton(context, themeSettings),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
      color: themeSettings.cardBackgroundColor,
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
              color: themeSettings.cardBackgroundColor,
              onColorChanged: themeSettings.updateCardBackgroundColor,
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
      color: themeSettings.cardBackgroundColor,
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
              label: '画面下部の選択済みの色',
              color:
                  themeSettings.customBottomNavigationSelectedColor ??
                  themeSettings.bottomNavigationSelectedColor,
              onColorChanged: (color) {
                setState(() {
                  themeSettings.customBottomNavigationSelectedColor = color;
                });
                themeSettings.save();
              },
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '画面下部の未選択の色',
              color:
                  themeSettings.customBottomNavigationUnselectedColor ??
                  themeSettings.bottomNavigationUnselectedColor,
              onColorChanged: (color) {
                setState(() {
                  themeSettings.customBottomNavigationUnselectedColor = color;
                });
                themeSettings.save();
              },
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
      color: themeSettings.cardBackgroundColor,
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
              color: themeSettings.appButtonColor,
              onColorChanged: themeSettings.updateAppButtonColor,
            ),
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: 'アイコンの色',
              color: themeSettings.iconColor,
              onColorChanged: (color) {
                themeSettings.updateIconColor(color);
                // 設定アイコンの色も同時に更新
                themeSettings.updateSettingsColor(color);
              },
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
            const SizedBox(height: 16),
            _ColorPickerTile(
              label: '電卓の色',
              color: themeSettings.calculatorColor,
              onColorChanged: themeSettings.updateCalculatorColor,
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
      color: themeSettings.cardBackgroundColor,
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
                  backgroundColor: themeSettings.appButtonColor,
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
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              if (themeName.isNotEmpty) {
                // プリセットテーマと同じかチェック
                final currentThemeData = {
                  'appBarColor': themeSettings.appBarColor,
                  'backgroundColor': themeSettings.backgroundColor,
                  'buttonColor': themeSettings.appButtonColor,
                  'backgroundColor2': themeSettings.cardBackgroundColor,
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
                bool isPreset = false;
                for (final preset in ThemeSettings.presets.values) {
                  if (preset.length == currentThemeData.length &&
                      preset.keys.every(
                        (k) => preset[k] == currentThemeData[k],
                      )) {
                    isPreset = true;
                    break;
                  }
                }
                if (isPreset) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('保存できません'),
                      content: Text('プリセットテーマと同じ設定です'),
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
                final themeData = {
                  'appBarColor': themeSettings.appBarColor,
                  'backgroundColor': themeSettings.backgroundColor,
                  'buttonColor': themeSettings.appButtonColor,
                  'backgroundColor2': themeSettings.cardBackgroundColor,
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
                  'cardBackgroundColor': themeSettings.cardBackgroundColor,
                  'borderColor': themeSettings.borderColor,
                  'bottomNavigationSelectedColor':
                      themeSettings.bottomNavigationSelectedColor,
                  'settingsColor': themeSettings.settingsColor,
                  if (themeSettings.customBottomNavigationSelectedColor != null)
                    'customBottomNavigationSelectedColor':
                        themeSettings.customBottomNavigationSelectedColor!,
                  if (themeSettings.customBottomNavigationUnselectedColor !=
                      null)
                    'customBottomNavigationUnselectedColor':
                        themeSettings.customBottomNavigationUnselectedColor!,
                };
                await ThemeSettings.saveCustomTheme(themeName, themeData);
                navigator.pop(true);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$themeName として保存しました'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeSettings.appButtonColor,
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
      color: themeSettings.cardBackgroundColor,
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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700, // Web版での最大幅を制限（カラーピッカー用に拡張）
        ),
        child: Dialog(
          backgroundColor: themeSettings.cardBackgroundColor,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.75,
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
                                color: themeSettings.fontColor1.withValues(
                                  alpha: 0.3,
                                ),
                                width: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (_) {
                              final int r =
                                  ((widget.initialColor.r * 255.0).round() &
                                  0xff);
                              final int g =
                                  ((widget.initialColor.g * 255.0).round() &
                                  0xff);
                              final int b =
                                  ((widget.initialColor.b * 255.0).round() &
                                  0xff);
                              final hex =
                                  '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}${g.toRadixString(16).padLeft(2, '0').toUpperCase()}${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
                              return Text(
                                hex,
                                style: TextStyle(
                                  color: themeSettings.fontColor1,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              );
                            },
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
                                color: themeSettings.fontColor1.withValues(
                                  alpha: 0.3,
                                ),
                                width: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (_) {
                              final int r = ((_color.r * 255.0).round() & 0xff);
                              final int g = ((_color.g * 255.0).round() & 0xff);
                              final int b = ((_color.b * 255.0).round() & 0xff);
                              final hex =
                                  '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}${g.toRadixString(16).padLeft(2, '0').toUpperCase()}${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
                              return Text(
                                hex,
                                style: TextStyle(
                                  color: themeSettings.fontColor1,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              );
                            },
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
                        backgroundColor: themeSettings.appButtonColor,
                        foregroundColor: themeSettings.fontColor2,
                      ),
                      child: const Text('決定'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
