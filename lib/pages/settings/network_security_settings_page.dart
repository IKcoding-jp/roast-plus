import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/network_security_service.dart';
import 'dart:developer' as developer;

class NetworkSecuritySettingsPage extends StatefulWidget {
  const NetworkSecuritySettingsPage({super.key});

  @override
  State<NetworkSecuritySettingsPage> createState() =>
      _NetworkSecuritySettingsPageState();
}

class _NetworkSecuritySettingsPageState
    extends State<NetworkSecuritySettingsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _networkSecurityReport;
  List<Map<String, dynamic>> _recentViolations = [];

  @override
  void initState() {
    super.initState();
    _loadNetworkSecurityData();
  }

  Future<void> _loadNetworkSecurityData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // ネットワークセキュリティレポートを取得
      final report =
          await NetworkSecurityService.generateNetworkSecurityReport();

      if (mounted) {
        setState(() {
          _networkSecurityReport = report;
          _recentViolations = List<Map<String, dynamic>>.from(
            report['violations'] ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log(
        'ネットワークセキュリティデータ読み込みエラー: $e',
        name: 'NetworkSecuritySettingsPage',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
                  'ネットワークセキュリティ設定',
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
                      // HTTPS通信状況カード
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
                                  Icon(Icons.https, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(
                                    'HTTPS通信状況',
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
                              _buildSecurityStatusItem(
                                'HTTPS通信強制',
                                '有効',
                                Colors.green,
                                themeSettings,
                              ),
                              _buildSecurityStatusItem(
                                'TLS 1.2以上',
                                '有効',
                                Colors.green,
                                themeSettings,
                              ),
                              _buildSecurityStatusItem(
                                '証明書透明性',
                                '有効',
                                Colors.green,
                                themeSettings,
                              ),
                              _buildSecurityStatusItem(
                                'HTTP通信',
                                'ブロック',
                                Colors.red,
                                themeSettings,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 証明書ピニングカード
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
                                  Icon(Icons.verified, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    '証明書ピニング',
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
                              if (_networkSecurityReport != null &&
                                  _networkSecurityReport!['certificate_pins'] !=
                                      null)
                                ...(_networkSecurityReport!['certificate_pins']
                                        as List)
                                    .map(
                                      (domain) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.domain,
                                              size: 16,
                                              color: themeSettings.iconColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                domain,
                                                style: TextStyle(
                                                  color:
                                                      themeSettings.fontColor1,
                                                  fontSize:
                                                      14 *
                                                      themeSettings
                                                          .fontSizeScale,
                                                  fontFamily:
                                                      themeSettings.fontFamily,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    ,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ネットワーク統計カード
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
                                    'ネットワーク統計',
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
                              if (_networkSecurityReport != null &&
                                  _networkSecurityReport!['stats'] != null) ...[
                                _buildStatItem(
                                  '総チェック回数',
                                  '${_networkSecurityReport!['stats']['totalChecks'] ?? 0}',
                                  themeSettings,
                                ),
                                _buildStatItem(
                                  'セキュア接続',
                                  '${_networkSecurityReport!['stats']['secureConnections'] ?? 0}',
                                  themeSettings,
                                ),
                                _buildStatItem(
                                  '証明書検証',
                                  '${_networkSecurityReport!['stats']['certificateValidations'] ?? 0}',
                                  themeSettings,
                                ),
                                _buildStatItem(
                                  '最終チェック',
                                  _formatDateTime(
                                    _networkSecurityReport!['stats']['lastCheck'],
                                  ),
                                  themeSettings,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 最近のセキュリティ違反カード
                      if (_recentViolations.isNotEmpty) ...[
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
                                    Icon(Icons.warning, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(
                                      '最近のセキュリティ違反 (${_recentViolations.length})',
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
                                ..._recentViolations
                                    .take(5)
                                    .map(
                                      (violation) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              violation['details']['violation_type'] ??
                                                  '不明',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize:
                                                    14 *
                                                    themeSettings.fontSizeScale,
                                                fontWeight: FontWeight.bold,
                                                fontFamily:
                                                    themeSettings.fontFamily,
                                              ),
                                            ),
                                            Text(
                                              _formatDateTime(
                                                violation['timestamp'],
                                              ),
                                              style: TextStyle(
                                                color: themeSettings.fontColor2,
                                                fontSize:
                                                    12 *
                                                    themeSettings.fontSizeScale,
                                                fontFamily:
                                                    themeSettings.fontFamily,
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
                        const SizedBox(height: 16),
                      ],

                      // 操作ボタン
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loadNetworkSecurityData,
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
                        ],
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSecurityStatusItem(
    String label,
    String status,
    Color statusColor,
    ThemeSettings themeSettings,
  ) {
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
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 14 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    ThemeSettings themeSettings,
  ) {
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
              color: themeSettings.fontColor2,
              fontSize: 14 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
              fontFamily: themeSettings.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '不明';

    try {
      if (dateTime is String) {
        final dt = DateTime.parse(dateTime);
        return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return dateTime.toString();
    } catch (e) {
      return dateTime.toString();
    }
  }
}
