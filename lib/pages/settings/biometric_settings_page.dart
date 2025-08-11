import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/biometric_auth_service.dart';
import '../../services/secure_storage_service.dart';

class BiometricSettingsPage extends StatefulWidget {
  const BiometricSettingsPage({super.key});

  @override
  State<BiometricSettingsPage> createState() => _BiometricSettingsPageState();
}

class _BiometricSettingsPageState extends State<BiometricSettingsPage> {
  bool _isLoading = true;
  bool _biometricEnabled = false;
  List<BiometricType> _availableBiometrics = [];
  Map<String, dynamic> _biometricStatus = {};
  bool _isDeviceSupported = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }

  /// 生体認証設定を読み込み
  Future<void> _loadBiometricSettings() async {
    try {
      setState(() => _isLoading = true);

      // 生体認証サービスの初期化
      await BiometricAuthService.initialize();

      // 各種状態を取得
      final biometricEnabled = await BiometricAuthService.isBiometricEnabled();
      final availableBiometrics =
          await BiometricAuthService.getAvailableBiometrics();
      final biometricStatus = await BiometricAuthService.getBiometricStatus();

      if (mounted) {
        setState(() {
          _biometricEnabled = biometricEnabled;
          _availableBiometrics = availableBiometrics;
          _biometricStatus = biometricStatus;
          _isDeviceSupported = biometricStatus['is_device_supported'] ?? false;
          _canCheckBiometrics =
              biometricStatus['can_check_biometrics'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('生体認証設定読み込みエラー: $e', name: 'BiometricSettingsPage');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('設定の読み込みに失敗しました: $e');
      }
    }
  }

  /// 生体認証を有効化
  Future<void> _enableBiometric() async {
    try {
      setState(() => _isLoading = true);

      final success = await BiometricAuthService.enableBiometric();

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          setState(() => _biometricEnabled = true);
          _showSuccessSnackBar('生体認証が有効化されました');
          await _loadBiometricSettings(); // 設定を再読み込み
        } else {
          _showErrorSnackBar('生体認証の有効化に失敗しました');
        }
      }
    } catch (e) {
      developer.log('生体認証有効化エラー: $e', name: 'BiometricSettingsPage');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('生体認証の有効化に失敗しました: $e');
      }
    }
  }

  /// 生体認証を無効化
  Future<void> _disableBiometric() async {
    try {
      setState(() => _isLoading = true);

      final success = await BiometricAuthService.disableBiometric();

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          setState(() => _biometricEnabled = false);
          _showSuccessSnackBar('生体認証が無効化されました');
          await _loadBiometricSettings(); // 設定を再読み込み
        } else {
          _showErrorSnackBar('生体認証の無効化に失敗しました');
        }
      }
    } catch (e) {
      developer.log('生体認証無効化エラー: $e', name: 'BiometricSettingsPage');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('生体認証の無効化に失敗しました: $e');
      }
    }
  }

  /// 生体認証をテスト
  Future<void> _testBiometric() async {
    try {
      setState(() => _isLoading = true);

      final success = await BiometricAuthService.authenticateWithBiometrics(
        reason: '生体認証をテストします',
        fallbackTitle: 'パスコードを使用',
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          _showSuccessSnackBar('生体認証テストが成功しました');
        } else {
          _showErrorSnackBar('生体認証テストに失敗しました');
        }
      }
    } catch (e) {
      developer.log('生体認証テストエラー: $e', name: 'BiometricSettingsPage');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('生体認証テストに失敗しました: $e');
      }
    }
  }

  /// 成功メッセージを表示
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// エラーメッセージを表示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 生体認証タイプの表示名を取得
  String _getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return '顔認証';
      case BiometricType.fingerprint:
        return '指紋認証';
      case BiometricType.iris:
        return '虹彩認証';
      default:
        return type.toString();
    }
  }

  /// 生体認証タイプのアイコンを取得
  IconData _getBiometricTypeIcon(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return Icons.face;
      case BiometricType.fingerprint:
        return Icons.fingerprint;
      case BiometricType.iris:
        return Icons.visibility;
      default:
        return Icons.security;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '生体認証設定',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 18 * themeSettings.fontSizeScale,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      backgroundColor: themeSettings.backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: themeSettings.settingsColor,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // デバイス対応状況
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
                            'デバイス対応状況',
                            style: TextStyle(
                              fontSize: 18 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              color: themeSettings.fontColor1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStatusRow(
                            'デバイス対応',
                            _isDeviceSupported,
                            Icons.phone_android,
                            themeSettings,
                          ),
                          _buildStatusRow(
                            '生体認証利用可能',
                            _canCheckBiometrics,
                            Icons.security,
                            themeSettings,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 利用可能な生体認証
                  if (_availableBiometrics.isNotEmpty) ...[
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
                              '利用可能な生体認証',
                              style: TextStyle(
                                fontSize: 18 * themeSettings.fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: themeSettings.fontColor1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...(_availableBiometrics.map(
                              (type) => ListTile(
                                leading: Icon(
                                  _getBiometricTypeIcon(type),
                                  color: themeSettings.settingsColor,
                                ),
                                title: Text(
                                  _getBiometricTypeName(type),
                                  style: TextStyle(
                                    color: themeSettings.fontColor1,
                                    fontSize: 16 * themeSettings.fontSizeScale,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 生体認証設定
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
                            '生体認証設定',
                            style: TextStyle(
                              fontSize: 18 * themeSettings.fontSizeScale,
                              fontWeight: FontWeight.bold,
                              color: themeSettings.fontColor1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: Text(
                              '生体認証を有効にする',
                              style: TextStyle(
                                color: themeSettings.fontColor1,
                                fontSize: 16 * themeSettings.fontSizeScale,
                              ),
                            ),
                            subtitle: Text(
                              '指紋・顔認証でアプリにアクセス',
                              style: TextStyle(
                                color: themeSettings.fontColor1,
                                fontSize: 14 * themeSettings.fontSizeScale,
                              ),
                            ),
                            value: _biometricEnabled,
                            onChanged: _isDeviceSupported && _canCheckBiometrics
                                ? (value) {
                                    if (value) {
                                      _enableBiometric();
                                    } else {
                                      _disableBiometric();
                                    }
                                  }
                                : null,
                            secondary: Icon(
                              Icons.fingerprint,
                              color: themeSettings.settingsColor,
                            ),
                            activeColor: themeSettings.settingsColor,
                          ),
                          if (_biometricEnabled) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _testBiometric,
                              icon: Icon(
                                Icons.security,
                                color: themeSettings.fontColor2,
                              ),
                              label: Text(
                                '生体認証をテスト',
                                style: TextStyle(
                                  color: themeSettings.fontColor2,
                                  fontSize: 16 * themeSettings.fontSizeScale,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeSettings.settingsColor,
                                foregroundColor: themeSettings.fontColor2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 注意事項
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Text(
                                '注意事項',
                                style: TextStyle(
                                  fontSize: 16 * themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• 生体認証はデバイスの設定で有効になっている必要があります\n'
                            '• 生体認証が失敗した場合は、パスコードでの認証に切り替わります\n'
                            '• セキュリティのため、定期的に認証が必要になる場合があります',
                            style: TextStyle(
                              fontSize: 14 * themeSettings.fontSizeScale,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// ステータス行を構築
  Widget _buildStatusRow(
    String title,
    bool status,
    IconData icon,
    ThemeSettings themeSettings,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: status ? Colors.green : themeSettings.iconColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: themeSettings.fontColor1,
          fontSize: 16 * themeSettings.fontSizeScale,
        ),
      ),
      trailing: Icon(
        status ? Icons.check_circle : Icons.cancel,
        color: status ? Colors.green : Colors.red,
      ),
    );
  }
}
