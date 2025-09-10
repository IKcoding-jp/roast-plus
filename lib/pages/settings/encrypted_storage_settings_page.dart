import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/encrypted_local_storage_service.dart';
import 'dart:developer' as developer;

class EncryptedStorageSettingsPage extends StatefulWidget {
  const EncryptedStorageSettingsPage({super.key});

  @override
  State<EncryptedStorageSettingsPage> createState() =>
      _EncryptedStorageSettingsPageState();
}

class _EncryptedStorageSettingsPageState
    extends State<EncryptedStorageSettingsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _encryptionStats;
  bool _dataIntegrity = false;
  Set<String> _allKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _loadEncryptionData();
  }

  Future<void> _loadEncryptionData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 暗号化統計を取得
      final stats = await EncryptedLocalStorageService.getEncryptionStats();

      // データ整合性をチェック
      final integrity =
          await EncryptedLocalStorageService.validateDataIntegrity();

      // すべてのキーを取得
      final keys = await EncryptedLocalStorageService.getKeys();

      if (mounted) {
        setState(() {
          _encryptionStats = stats;
          _dataIntegrity = integrity;
          _allKeys = keys;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('暗号化データ読み込みエラー: $e', name: 'EncryptedStorageSettingsPage');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearAllEncryptedData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('すべての暗号化データを削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await EncryptedLocalStorageService.clear();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('すべての暗号化データを削除しました')));
          _loadEncryptionData(); // データを再読み込み
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('データ削除に失敗しました: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeSettings>(
      builder: (context, themeSettings, child) {
        return Scaffold(
          backgroundColor: themeSettings.backgroundColor,
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.security, color: themeSettings.iconColor),
                const SizedBox(width: 8),
                Text(
                  '暗号化ストレージ設定',
                  style: TextStyle(
                    color: themeSettings.appBarTextColor,
                    fontSize: 20 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                    fontFamily: themeSettings.fontFamily,
                  ),
                ),
              ],
            ),
            backgroundColor: themeSettings.appBarColor,
            iconTheme: IconThemeData(color: themeSettings.iconColor),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: themeSettings.iconColor,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 暗号化統計カード
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
                              Row(
                                children: [
                                  Icon(
                                    Icons.analytics,
                                    color: themeSettings.iconColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '暗号化統計',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          18 * themeSettings.fontSizeScale,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_encryptionStats != null) ...[
                                _buildStatItem(
                                  '総キー数',
                                  '${_encryptionStats!['totalKeys']}',
                                  themeSettings,
                                ),
                                _buildStatItem(
                                  '暗号化済みキー数',
                                  '${_encryptionStats!['encryptedKeys']}',
                                  themeSettings,
                                ),
                                _buildStatItem(
                                  '暗号化率',
                                  '${_encryptionStats!['encryptionRate']}%',
                                  themeSettings,
                                  isPercentage: true,
                                ),
                                _buildStatItem(
                                  '最終チェック',
                                  _formatDateTime(
                                    _encryptionStats!['lastChecked'],
                                  ),
                                  themeSettings,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // データ整合性カード
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
                              Row(
                                children: [
                                  Icon(
                                    _dataIntegrity
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: _dataIntegrity
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'データ整合性',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          18 * themeSettings.fontSizeScale,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _dataIntegrity
                                    ? 'すべてのデータが正常に暗号化されています'
                                    : '一部のデータに問題があります',
                                style: TextStyle(
                                  color: _dataIntegrity
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 14 * themeSettings.fontSizeScale,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 保存されているキー一覧カード
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
                              Row(
                                children: [
                                  Icon(
                                    Icons.list,
                                    color: themeSettings.iconColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '保存されているキー (${_allKeys.length})',
                                    style: TextStyle(
                                      color: themeSettings.fontColor1,
                                      fontSize:
                                          18 * themeSettings.fontSizeScale,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: themeSettings.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_allKeys.isEmpty)
                                Text(
                                  '保存されているデータがありません',
                                  style: TextStyle(
                                    color: themeSettings.fontColor2,
                                    fontSize: 14 * themeSettings.fontSizeScale,
                                    fontFamily: themeSettings.fontFamily,
                                  ),
                                )
                              else
                                ...(_allKeys.toList()..sort()).map(
                                  (key) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.key,
                                          size: 16,
                                          color: themeSettings.iconColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            key,
                                            style: TextStyle(
                                              color: themeSettings.fontColor1,
                                              fontSize:
                                                  14 *
                                                  themeSettings.fontSizeScale,
                                              fontFamily:
                                                  themeSettings.fontFamily,
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
                      const SizedBox(height: 24),

                      // 操作ボタン
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loadEncryptionData,
                              icon: Icon(Icons.refresh, color: Colors.white),
                              label: Text(
                                '更新',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16 * themeSettings.fontSizeScale,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeSettings.buttonColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _clearAllEncryptedData,
                              icon: Icon(
                                Icons.delete_forever,
                                color: Colors.white,
                              ),
                              label: Text(
                                '全削除',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16 * themeSettings.fontSizeScale,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    ThemeSettings themeSettings, {
    bool isPercentage = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: themeSettings.fontColor1,
              fontSize: 14 * themeSettings.fontSizeScale,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isPercentage
                  ? _getPercentageColor(value)
                  : themeSettings.fontColor2,
              fontSize: 14 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPercentageColor(String percentage) {
    final value = double.tryParse(percentage.replaceAll('%', '')) ?? 0;
    if (value >= 90) return Colors.green;
    if (value >= 70) return Colors.orange;
    return Colors.red;
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }
}
