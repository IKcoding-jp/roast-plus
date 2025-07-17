import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import 'custom_theme_settings_page.dart';
import 'dart:async'; // Added for Timer
import '../../utils/app_performance_config.dart';
import '../../settings/donation_page.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  Map<String, Map<String, Color>> _customThemes = {};
  bool _isLoading = true;
  late BuildContext _rootContext;

  // --- 追加: debounce用 ---
  Timer? _snackbarDebounceTimer;
  String? _pendingThemeName;
  void _showDebouncedSnackBar(String themeName) {
    _pendingThemeName = themeName;
    _snackbarDebounceTimer?.cancel();
    _snackbarDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_pendingThemeName != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_pendingThemeName テーマを適用しました')),
        );
        _pendingThemeName = null;
      }
    });
  }

  @override
  void dispose() {
    _snackbarDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCustomThemes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCustomThemes();
  }

  Future<void> _loadCustomThemes() async {
    final customThemes = await ThemeSettings.getCustomThemes();
    setState(() {
      _customThemes = customThemes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _rootContext = context;
    final themeSettings = Provider.of<ThemeSettings>(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('テーマ設定'),
          backgroundColor: themeSettings.appBarColor,
        ),
        body: Container(
          color: themeSettings.backgroundColor,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('テーマ設定'),
        backgroundColor: themeSettings.appBarColor,
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: themeSettings.appBarTextColor),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomThemeSettingsPage(),
                ),
              );
              if (result == true) {
                await _loadCustomThemes();
              }
            },
            tooltip: 'カスタム設定',
          ),
        ],
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
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _buildPresetSection(context, themeSettings),
                const SizedBox(height: 24),
                _buildCustomThemesSection(context, themeSettings),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetSection(
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
                  'プリセットテーマ',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 基本テーマ（デフォルト、ダーク、ライト）
            Text(
              '基本テーマ',
              style: TextStyle(
                fontSize: 16 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.w600,
                color: themeSettings.fontColor1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['デフォルト', 'ダーク', 'ライト'].map((presetName) {
                return _PresetButton(
                  presetName: presetName,
                  onPressed: () {
                    themeSettings.applyPreset(presetName);
                    _showDebouncedSnackBar(presetName);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // カラーテーマ（その他の色）
            Text(
              'カラーテーマ',
              style: TextStyle(
                fontSize: 16 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.w600,
                color: themeSettings.fontColor1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ThemeSettings.getPresetNames()
                  .where(
                    (presetName) =>
                        !['デフォルト', 'ダーク', 'ライト'].contains(presetName),
                  )
                  .map((presetName) {
                    return _PresetButton(
                      presetName: presetName,
                      onPressed: () {
                        themeSettings.applyPreset(presetName);
                        _showDebouncedSnackBar(presetName);
                      },
                    );
                  })
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomThemesSection(
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
                Icon(Icons.save, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  'カスタムテーマ',
                  style: TextStyle(
                    fontSize: 18 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    color: themeSettings.fontColor1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_customThemes.isEmpty)
              Center(
                child: Text(
                  '保存されたカスタムテーマはありません',
                  style: TextStyle(
                    color: themeSettings.fontColor1.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _customThemes.keys.map((themeName) {
                  return _CustomThemeButton(
                    themeName: themeName,
                    themeData: _customThemes[themeName]!,
                    onPressed: () async {
                      await themeSettings.applyCustomTheme(themeName);
                      _showDebouncedSnackBar(themeName);
                    },
                    onLongPress: () =>
                        _showCustomThemeOptions(context, themeName),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _showCustomThemeOptions(BuildContext context, String themeName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('名前を変更'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(_rootContext, themeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('ボタンの色を変更'),
              onTap: () {
                Navigator.pop(context);
                _showButtonColorDialog(_rootContext, themeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(_rootContext, themeName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テーマ名を変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新しい名前',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                await ThemeSettings.renameCustomTheme(oldName, newName);
                await _loadCustomThemes();
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('テーマ名を変更しました')));
              }
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String themeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テーマを削除'),
        content: Text('「$themeName」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ThemeSettings.deleteCustomTheme(themeName);
              await _loadCustomThemes();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('テーマを削除しました')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCustomThemeButtonColor(
    String themeName,
    Color newColor,
  ) async {
    final customThemes = await ThemeSettings.getCustomThemes();
    if (customThemes.containsKey(themeName)) {
      final themeData = Map<String, Color>.from(customThemes[themeName]!);
      themeData['buttonColor'] = newColor;
      await ThemeSettings.saveCustomTheme(themeName, themeData);
      await _loadCustomThemes();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ボタンの色を変更しました')));
      }
    }
  }

  void _showButtonColorDialog(BuildContext context, String themeName) async {
    final customThemes = await ThemeSettings.getCustomThemes();
    final currentColor = customThemes[themeName]?['buttonColor'] ?? Colors.grey;

    final picked = await showDialog<Color>(
      context: context,
      builder: (context) =>
          _ColorPickerDialog(initialColor: currentColor, label: 'ボタン'),
    );

    if (picked != null) {
      await _updateCustomThemeButtonColor(themeName, picked);
    }
  }

  void _showSaveCustomThemeDialog(
    BuildContext context,
    ThemeSettings themeSettings,
  ) async {
    // 重複チェックを先に行う
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
      'bottomNavigationTextColor': themeSettings.bottomNavigationTextColor,
    };

    final customThemes = await ThemeSettings.getCustomThemes();
    bool isDuplicate = false;
    String existingThemeName = '';

    // カスタムテーマとの重複チェック
    for (final entry in customThemes.entries) {
      if (_isThemeDataEqual(entry.value, themeData)) {
        isDuplicate = true;
        existingThemeName = entry.key;
        break;
      }
    }

    if (isDuplicate) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: themeSettings.backgroundColor2 ?? Colors.white,
          title: Text(
            '重複エラー',
            style: TextStyle(color: themeSettings.fontColor1),
          ),
          content: Text(
            'すでに「$existingThemeName」として同じカスタム設定が追加されています。',
            style: TextStyle(color: themeSettings.fontColor1),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeSettings.buttonColor,
                foregroundColor: themeSettings.fontColor2,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // プリセットテーマとの重複チェック
    for (final entry in ThemeSettings.presets.entries) {
      if (_isThemeDataEqual(entry.value, themeData)) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: themeSettings.backgroundColor2 ?? Colors.white,
            title: Text(
              'プリセット重複エラー',
              style: TextStyle(color: themeSettings.fontColor1),
            ),
            content: Text(
              'プリセットテーマ「${entry.key}」と同じ設定です。プリセットはカスタムとして登録することはできません。',
              style: TextStyle(color: themeSettings.fontColor1),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeSettings.buttonColor,
                  foregroundColor: themeSettings.fontColor2,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    final controller = TextEditingController();
    final suggestedName = await ThemeSettings.getNextCustomThemeName();
    controller.text = suggestedName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeSettings.backgroundColor2 ?? Colors.white,
        title: Text(
          'カスタムテーマを保存',
          style: TextStyle(color: themeSettings.fontColor1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'テーマ名を入力してください',
              style: TextStyle(color: themeSettings.fontColor1),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: TextStyle(color: themeSettings.fontColor1),
              decoration: InputDecoration(
                labelText: 'テーマ名',
                labelStyle: TextStyle(color: themeSettings.fontColor1),
                border: const OutlineInputBorder(),
                hintText: '例: マイテーマ',
                hintStyle: TextStyle(
                  color: themeSettings.fontColor1.withOpacity(0.6),
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
            style: TextButton.styleFrom(
              foregroundColor: themeSettings.fontColor1,
            ),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final themeName = controller.text.trim();
              if (themeName.isNotEmpty) {
                await ThemeSettings.saveCustomTheme(themeName, themeData);
                await _loadCustomThemes();
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$themeName を保存しました')));
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

  bool _isThemeDataEqual(Map<String, Color> theme1, Map<String, Color> theme2) {
    final keys = [
      'appBarColor',
      'backgroundColor',
      'buttonColor',
      'backgroundColor2',
      'fontColor1',
      'fontColor2',
      'iconColor',
      'timerCircleColor',
      'bottomNavigationColor',
      'inputBackgroundColor',
      'memberBackgroundColor',
      'appBarTextColor',
      'bottomNavigationTextColor',
    ];

    for (final key in keys) {
      if (theme1[key]?.value != theme2[key]?.value) {
        return false;
      }
    }
    return true;
  }
}

class _PresetButton extends StatelessWidget {
  final String presetName;
  final VoidCallback onPressed;

  const _PresetButton({required this.presetName, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final preset = ThemeSettings.presets[presetName];
    final isLight = presetName == 'ライト';
    final paletteColor = isLight ? Colors.black : Colors.white;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: preset?['buttonColor'] ?? Colors.grey,
        foregroundColor: preset?['fontColor2'] ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.palette, color: paletteColor, size: 20),
          const SizedBox(width: 8),
          Text(
            presetName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

class _CustomThemeButton extends StatelessWidget {
  final String themeName;
  final Map<String, Color> themeData;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  const _CustomThemeButton({
    required this.themeName,
    required this.themeData,
    required this.onPressed,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final paletteColor = (themeName == 'ライト') ? Colors.black : Colors.white;
    return GestureDetector(
      onLongPress: onLongPress,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: themeData['buttonColor'] ?? Colors.grey,
          foregroundColor: themeData['fontColor2'] ?? Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette, color: paletteColor, size: 20),
            const SizedBox(width: 8),
            Text(
              themeName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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
    return AlertDialog(
      backgroundColor: themeSettings.backgroundColor2 ?? Colors.white,
      title: Text(
        '${widget.label}の色を選択',
        style: TextStyle(color: themeSettings.fontColor1),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            // 色選択器
            MaterialPicker(
              pickerColor: _color,
              onColorChanged: (c) => setState(() => _color = c),
              enableLabel: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: themeSettings.fontColor1,
          ),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _color),
          style: ElevatedButton.styleFrom(
            backgroundColor: themeSettings.buttonColor,
            foregroundColor: themeSettings.fontColor2,
          ),
          child: const Text('決定'),
        ),
      ],
    );
  }

  Color _getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
