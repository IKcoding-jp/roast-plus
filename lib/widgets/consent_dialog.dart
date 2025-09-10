import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/consent_models.dart';
import '../models/theme_settings.dart';
import '../services/consent_service.dart';

/// 同意取得ダイアログ
/// 個人情報保護法およびGDPRに準拠した同意取得UI
class ConsentDialog extends StatefulWidget {
  final List<ConsentRequest> consentRequests;
  final bool isRequired;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const ConsentDialog({
    super.key,
    required this.consentRequests,
    this.isRequired = false,
    this.onComplete,
    this.onCancel,
  });

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  final Map<ConsentType, bool> _consentStates = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 初期状態を設定
    for (final request in widget.consentRequests) {
      _consentStates[request.type] = request.isRequired;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return AlertDialog(
      backgroundColor: themeSettings.backgroundColor,
      title: Text(
        widget.isRequired ? '必須同意' : 'オプション同意',
        style: TextStyle(
          color: themeSettings.fontColor1,
          fontSize: 18 * themeSettings.fontSizeScale,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 説明文
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeSettings.cardBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: themeSettings.fontColor2.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  widget.isRequired
                      ? 'アプリを利用するために、以下の同意が必要です。'
                      : 'サービス向上のため、以下の機能の利用にご同意ください。',
                  style: TextStyle(
                    color: themeSettings.fontColor1,
                    fontSize: 14 * themeSettings.fontSizeScale,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 同意項目一覧
              ...widget.consentRequests.map(
                (request) => _buildConsentItem(request),
              ),

              const SizedBox(height: 16),

              // プライバシーポリシーへのリンク
              _buildPrivacyPolicyLink(),
            ],
          ),
        ),
      ),
      actions: [
        // キャンセルボタン（必須同意の場合は表示しない）
        if (!widget.isRequired)
          TextButton(
            onPressed: _isLoading ? null : _handleCancel,
            child: Text(
              'キャンセル',
              style: TextStyle(
                color: themeSettings.fontColor2,
                fontSize: 14 * themeSettings.fontSizeScale,
              ),
            ),
          ),

        // 同意ボタン
        ElevatedButton(
          onPressed: _isLoading ? null : _handleConsent,
          style: ElevatedButton.styleFrom(
            backgroundColor: themeSettings.buttonColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.isRequired ? '同意して続行' : '選択した項目に同意',
                  style: TextStyle(
                    fontSize: 14 * themeSettings.fontSizeScale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildConsentItem(ConsentRequest request) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final isChecked = _consentStates[request.type] ?? false;
    final isRequired = request.isRequired;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRequired
              ? Colors.orange.withValues(alpha: 0.3)
              : themeSettings.fontColor2.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // チェックボックスとタイトル
          Row(
            children: [
              Checkbox(
                value: isChecked,
                onChanged: isRequired
                    ? null
                    : (value) {
                        setState(() {
                          _consentStates[request.type] = value ?? false;
                        });
                      },
                activeColor: themeSettings.buttonColor,
              ),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      request.title,
                      style: TextStyle(
                        color: themeSettings.fontColor1,
                        fontSize: 16 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '必須',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // 説明文
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 8),
            child: Text(
              request.description,
              style: TextStyle(
                color: themeSettings.fontColor2,
                fontSize: 14 * themeSettings.fontSizeScale,
              ),
            ),
          ),

          // 詳細説明（展開可能）
          if (request.detailedDescription != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: ExpansionTile(
                title: Text(
                  '詳細を見る',
                  style: TextStyle(
                    color: themeSettings.buttonColor,
                    fontSize: 12 * themeSettings.fontSizeScale,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      request.detailedDescription!,
                      style: TextStyle(
                        color: themeSettings.fontColor2,
                        fontSize: 12 * themeSettings.fontSizeScale,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyLink() {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeSettings.cardBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.privacy_tip, color: themeSettings.buttonColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '詳細はプライバシーポリシーをご確認ください',
              style: TextStyle(
                color: themeSettings.fontColor2,
                fontSize: 12 * themeSettings.fontSizeScale,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // プライバシーポリシーページに遷移
              Navigator.pushNamed(context, '/privacy-policy');
            },
            child: Text(
              '確認',
              style: TextStyle(
                color: themeSettings.buttonColor,
                fontSize: 12 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConsent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 選択された同意を記録
      for (final entry in _consentStates.entries) {
        final status = entry.value
            ? ConsentStatus.granted
            : ConsentStatus.denied;
        await ConsentService.recordConsent(entry.key, status);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同意の記録に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop();
    widget.onCancel?.call();
  }
}

/// 同意取得のヘルパー関数
class ConsentDialogHelper {
  /// 必須同意を取得
  static Future<void> showRequiredConsentDialog(BuildContext context) async {
    final requiredRequests = ConsentService.getRequiredConsentRequests();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConsentDialog(
        consentRequests: requiredRequests,
        isRequired: true,
        onComplete: () {
          // 必須同意完了後の処理
        },
      ),
    );
  }

  /// オプション同意を取得
  static Future<void> showOptionalConsentDialog(BuildContext context) async {
    final optionalRequests = ConsentService.getOptionalConsentRequests();

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ConsentDialog(
        consentRequests: optionalRequests,
        isRequired: false,
        onComplete: () {
          // オプション同意完了後の処理
        },
      ),
    );
  }

  /// カスタム同意を取得
  static Future<void> showCustomConsentDialog(
    BuildContext context,
    List<ConsentRequest> requests, {
    bool isRequired = false,
    VoidCallback? onComplete,
    VoidCallback? onCancel,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isRequired,
      builder: (context) => ConsentDialog(
        consentRequests: requests,
        isRequired: isRequired,
        onComplete: onComplete,
        onCancel: onCancel,
      ),
    );
  }
}
