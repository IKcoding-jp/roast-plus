import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../services/firebase_security_audit_service.dart';
import 'dart:developer' as developer;

class FirebaseSecuritySettingsPage extends StatefulWidget {
  const FirebaseSecuritySettingsPage({super.key});

  @override
  State<FirebaseSecuritySettingsPage> createState() =>
      _FirebaseSecuritySettingsPageState();
}

class _FirebaseSecuritySettingsPageState
    extends State<FirebaseSecuritySettingsPage> {
  bool _isLoading = false;
  bool _isAuditing = false;
  Map<String, dynamic>? _latestAuditResult;
  List<Map<String, dynamic>> _auditHistory = [];

  @override
  void initState() {
    super.initState();
    _loadAuditData();
  }

  Future<void> _loadAuditData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 最新の監査結果を取得
      final latestResult =
          await FirebaseSecurityAuditService.getLatestAuditResult();

      // 監査履歴を取得
      final history = await FirebaseSecurityAuditService.getAuditHistory();

      if (mounted) {
        setState(() {
          _latestAuditResult = latestResult;
          _auditHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log(
        'Firebaseセキュリティデータ読み込みエラー: $e',
        name: 'FirebaseSecuritySettingsPage',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runSecurityAudit() async {
    try {
      setState(() {
        _isAuditing = true;
      });

      // セキュリティ監査を実行
      final auditResult =
          await FirebaseSecurityAuditService.performSecurityAudit();

      if (mounted) {
        setState(() {
          _latestAuditResult = auditResult;
          _isAuditing = false;
        });

        // 監査履歴を更新
        await _loadAuditData();

        // 結果を表示
        _showAuditResult(auditResult);
      }
    } catch (e) {
      developer.log('セキュリティ監査実行エラー: $e', name: 'FirebaseSecuritySettingsPage');
      if (mounted) {
        setState(() {
          _isAuditing = false;
        });
        _showError('セキュリティ監査の実行に失敗しました: $e');
      }
    }
  }

  void _showAuditResult(Map<String, dynamic> auditResult) {
    final score = auditResult['overall_score'] ?? 0;
    final recommendations = List<String>.from(
      auditResult['recommendations'] ?? [],
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('セキュリティ監査結果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('総合スコア: $score/100'),
            const SizedBox(height: 16),
            if (recommendations.isNotEmpty) ...[
              Text('推奨事項:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...recommendations.map(
                (rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $rec'),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
                  'Firebaseセキュリティ設定',
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
                      // セキュリティルール状況カード
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
                                  Icon(Icons.rule, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Firestoreセキュリティルール',
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
                                '認証必須',
                                '有効',
                                Colors.green,
                                themeSettings,
                              ),
                              _buildSecurityStatusItem(
                                'ユーザーデータ保護',
                                '有効',
                                Colors.green,
                                themeSettings,
                              ),
                              _buildSecurityStatusItem(
                                'グループデータ保護',
                                '有効',
                                Colors.green,
                                themeSettings,
                              ),
                              _buildSecurityStatusItem(
                                '権限昇格防止',
                                '有効',
                                Colors.green,
                                themeSettings,
                              ),
                              _buildSecurityStatusItem(
                                '未認証アクセス拒否',
                                '有効',
                                Colors.green,
                                themeSettings,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 最新監査結果カード
                      if (_latestAuditResult != null) ...[
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
                                      Icons.assessment,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '最新セキュリティ監査結果',
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
                                _buildStatItem(
                                  '総合スコア',
                                  '${_latestAuditResult!['overall_score'] ?? 0}/100',
                                  themeSettings,
                                ),
                                _buildStatItem(
                                  'テスト数',
                                  '${(_latestAuditResult!['tests'] as List?)?.length ?? 0}',
                                  themeSettings,
                                ),
                                _buildStatItem(
                                  '合格テスト数',
                                  '${(_latestAuditResult!['tests'] as List?)?.where((test) => test['passed'] == true).length ?? 0}',
                                  themeSettings,
                                ),
                                _buildStatItem(
                                  '監査日時',
                                  _formatDateTime(
                                    _latestAuditResult!['timestamp'],
                                  ),
                                  themeSettings,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 監査履歴カード
                      if (_auditHistory.isNotEmpty) ...[
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
                                      Icons.history,
                                      color: themeSettings.iconColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '監査履歴 (${_auditHistory.length})',
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
                                ..._auditHistory
                                    .take(5)
                                    .map(
                                      (audit) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${audit['overall_score'] ?? 0}/100',
                                              style: TextStyle(
                                                color: _getScoreColor(
                                                  audit['overall_score'] ?? 0,
                                                ),
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
                                                audit['timestamp'],
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
                              onPressed: _isAuditing ? null : _runSecurityAudit,
                              icon: _isAuditing
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.security, color: Colors.white),
                              label: Text(
                                _isAuditing ? '監査中...' : 'セキュリティ監査実行',
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
                              onPressed: _loadAuditData,
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
                                backgroundColor: Colors.blue,
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
                      const SizedBox(height: 16),

                      // セキュリティルールデプロイ情報
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
                                    Icons.cloud_upload,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'セキュリティルールデプロイ',
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
                              Text(
                                'セキュリティルールを更新する場合は、以下のコマンドを実行してください：',
                                style: TextStyle(
                                  color: themeSettings.fontColor1,
                                  fontSize: 14 * themeSettings.fontSizeScale,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'firebase deploy --only firestore:rules',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12 * themeSettings.fontSizeScale,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'または、deploy_firestore_rules.bat（Windows）またはdeploy_firestore_rules.sh（Linux/Mac）を実行してください。',
                                style: TextStyle(
                                  color: themeSettings.fontColor2,
                                  fontSize: 12 * themeSettings.fontSizeScale,
                                  fontFamily: themeSettings.fontFamily,
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

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
