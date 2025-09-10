import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../utils/app_performance_config.dart';
import '../../services/encrypted_local_storage_service.dart';
import 'donation_page.dart';

class FontSizeSettingsPage extends StatefulWidget {
  const FontSizeSettingsPage({super.key});

  @override
  State<FontSizeSettingsPage> createState() => _FontSizeSettingsPageState();
}

class _FontSizeSettingsPageState extends State<FontSizeSettingsPage> {
  double _fontSizeScale = 1.0;
  String _selectedFontFamily = 'HannariMincho';
  bool? _isDonorUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDonorStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeSettings = Provider.of<ThemeSettings>(context, listen: false);
      setState(() {
        _fontSizeScale = themeSettings.fontSizeScale;
        // フォントが利用可能なリストにない場合はデフォルトに変更
        if (ThemeSettings.availableFonts.contains(themeSettings.fontFamily)) {
          _selectedFontFamily = themeSettings.fontFamily;
        } else {
          _selectedFontFamily = 'HannariMincho';
          // 設定も更新
          themeSettings.updateFontFamily('HannariMincho');
        }
      });
    });
  }

  Future<void> _checkDonorStatus() async {
    final isDonor = await isDonorUser();
    if (mounted) {
      setState(() {
        _isDonorUser = isDonor;
        _isLoading = false;
      });
    }
  }

  void _onFontSizeScaleChanged(double value) {
    setState(() {
      _fontSizeScale = value;
    });
    // ローカル保存のみで、notifyListeners()を呼ばない
    _saveFontSizeScaleLocally(value);
  }

  void _saveFontSizeScaleLocally(double value) async {
    try {
      await EncryptedLocalStorageService.setDouble('fontSizeScale', value);
    } catch (e) {
      debugPrint('ローカル保存エラー: $e');
    }
  }

  void _onFontSizeScaleChangedEnd(double value) {
    // ドラッグ終了時にThemeSettingsを更新
    Provider.of<ThemeSettings>(
      context,
      listen: false,
    ).updateFontSizeScale(value);
  }

  void _onFontFamilyChanged(String newValue) {
    setState(() {
      _selectedFontFamily = newValue;
    });
    // ローカル保存のみで、notifyListeners()を呼ばない
    _saveFontFamilyLocally(newValue);
    // ThemeSettingsを即座に更新
    Provider.of<ThemeSettings>(
      context,
      listen: false,
    ).updateFontFamily(newValue);
  }

  void _saveFontFamilyLocally(String value) async {
    try {
      await EncryptedLocalStorageService.setString('fontFamily', value);
    } catch (e) {
      debugPrint('ローカル保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('フォント設定'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _isDonorUser != true
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.volunteer_activism,
                      size: 48,
                      color: Colors.amber,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'この機能は寄付者限定です',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '300円以上の寄付でフォントカスタマイズが解放されます',
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
              )
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 600, // Web版での最大幅を制限
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: themeSettings.cardBackgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'フォントファミリー',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: themeSettings.fontColor1,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'アプリ内で使用するフォントを選択できます',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: themeSettings.fontColor1,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: themeSettings.buttonColor,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedFontFamily,
                                      isExpanded: true,
                                      dropdownColor:
                                          themeSettings.cardBackgroundColor,
                                      style: TextStyle(
                                        color: themeSettings.fontColor1,
                                        fontSize: 16,
                                      ),
                                      items: ThemeSettings.availableFonts.map((
                                        String font,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: font,
                                          child: Text(
                                            font,
                                            style: TextStyle(
                                              fontFamily: font,
                                              color: themeSettings.fontColor1,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          _onFontFamilyChanged(newValue);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: themeSettings.inputBackgroundColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'サンプルテキスト\nこれは現在のフォントのサンプルです。',
                                    style: TextStyle(
                                      fontFamily: _selectedFontFamily,
                                      fontSize: 16,
                                      color: themeSettings.fontColor1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: themeSettings.cardBackgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'フォントサイズ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: themeSettings.fontColor1,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'アプリ内の文字サイズを調整できます',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: themeSettings.fontColor1,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      '小',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: themeSettings.fontColor1,
                                      ),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: _fontSizeScale,
                                        min: 0.8,
                                        max: 1.5,
                                        divisions: 14, // 0.8から1.5まで0.05刻みで14分割
                                        label:
                                            '${(_fontSizeScale * 100).round()}%',
                                        activeColor: themeSettings.buttonColor,
                                        inactiveColor: themeSettings.buttonColor
                                            .withValues(alpha: 0.3),
                                        onChanged: (value) {
                                          _onFontSizeScaleChanged(value);
                                        },
                                        onChangeEnd: (value) {
                                          _onFontSizeScaleChangedEnd(value);
                                        },
                                      ),
                                    ),
                                    Text(
                                      '大',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: themeSettings.fontColor1,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    '${(_fontSizeScale * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: themeSettings.fontColor1,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: themeSettings.inputBackgroundColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'サンプルテキスト\nこれは現在のフォントサイズのサンプルです。',
                                    style: TextStyle(
                                      fontFamily: _selectedFontFamily,
                                      fontSize: 16 * _fontSizeScale,
                                      color: themeSettings.fontColor1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
