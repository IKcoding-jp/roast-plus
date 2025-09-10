import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/consent_models.dart';
import '../../models/theme_settings.dart';
import '../../services/consent_service.dart';
import '../../widgets/consent_dialog.dart';

/// 同意管理ページ
/// ユーザーが自分の同意設定を確認・変更できる画面
class ConsentManagementPage extends StatefulWidget {
  const ConsentManagementPage({super.key});

  @override
  State<ConsentManagementPage> createState() => _ConsentManagementPageState();
}

class _ConsentManagementPageState extends State<ConsentManagementPage> {
  ConsentSettings? _consentSettings;
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsentData();
  }

  Future<void> _loadConsentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await ConsentService.getUserConsentSettings();
      final statistics = await ConsentService.getConsentStatistics();

      setState(() {
        _consentSettings = settings;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データの読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      backgroundColor: themeSettings.backgroundColor,
      appBar: AppBar(
        title: Text(
          '同意管理',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 18 * themeSettings.fontSizeScale,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConsentData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(themeSettings),
    );
  }

  Widget _buildContent(ThemeSettings themeSettings) {
    if (_consentSettings == null) {
      return _buildNoConsentData(themeSettings);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 統計情報
          _buildStatisticsCard(themeSettings),
          const SizedBox(height: 16),

          // 同意設定一覧
          _buildConsentList(themeSettings),
          const SizedBox(height: 16),

          // アクションボタン
          _buildActionButtons(themeSettings),
        ],
      ),
    );
  }

  Widget _buildNoConsentData(ThemeSettings themeSettings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.privacy_tip, size: 64, color: themeSettings.fontColor2),
          const SizedBox(height: 16),
          Text(
            '同意データが見つかりません',
            style: TextStyle(
              color: themeSettings.fontColor1,
              fontSize: 18 * themeSettings.fontSizeScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '初回ログイン時に同意を取得します',
            style: TextStyle(
              color: themeSettings.fontColor2,
              fontSize: 14 * themeSettings.fontSizeScale,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeSettings.buttonColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'ホームに戻る',
              style: TextStyle(
                fontSize: 16 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeSettings themeSettings) {
    return Card(
      elevation: 4,
      color: themeSettings.cardBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '同意状況',
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 18 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '同意済み',
                    _statistics['grantedConsents'] ?? 0,
                    Colors.green,
                    themeSettings,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '拒否',
                    _statistics['deniedConsents'] ?? 0,
                    Colors.red,
                    themeSettings,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '撤回',
                    _statistics['withdrawnConsents'] ?? 0,
                    Colors.orange,
                    themeSettings,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_statistics['requiredConsentsGranted'] ?? false)
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    (_statistics['requiredConsentsGranted'] ?? false)
                        ? Icons.check_circle
                        : Icons.warning,
                    color: (_statistics['requiredConsentsGranted'] ?? false)
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (_statistics['requiredConsentsGranted'] ?? false)
                          ? '必須同意がすべて取得されています'
                          : '必須同意が不足しています',
                      style: TextStyle(
                        color: themeSettings.fontColor1,
                        fontSize: 14 * themeSettings.fontSizeScale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    int value,
    Color color,
    ThemeSettings themeSettings,
  ) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: themeSettings.fontColor2,
            fontSize: 12 * themeSettings.fontSizeScale,
          ),
        ),
      ],
    );
  }

  Widget _buildConsentList(ThemeSettings themeSettings) {
    final consentRequests = ConsentService.getConsentRequests();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '同意設定',
          style: TextStyle(
            color: themeSettings.fontColor1,
            fontSize: 18 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...consentRequests.map(
          (request) => _buildConsentItem(request, themeSettings),
        ),
      ],
    );
  }

  Widget _buildConsentItem(
    ConsentRequest request,
    ThemeSettings themeSettings,
  ) {
    final currentStatus =
        _consentSettings?.consents[request.type] ?? ConsentStatus.notRequested;
    final isGranted = currentStatus == ConsentStatus.granted;
    final isRequired = request.isRequired;

    return Card(
      elevation: 2,
      color: themeSettings.cardBackgroundColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isGranted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isGranted ? Colors.green : themeSettings.fontColor2,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                request.title,
                style: TextStyle(
                  color: themeSettings.fontColor1,
                  fontSize: 16 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isRequired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.description,
              style: TextStyle(
                color: themeSettings.fontColor2,
                fontSize: 14 * themeSettings.fontSizeScale,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '状態: ${currentStatus.displayName}',
              style: TextStyle(
                color: isGranted ? Colors.green : Colors.red,
                fontSize: 12 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showConsentEditDialog(request),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeSettings themeSettings) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showAllConsentDialog,
            icon: const Icon(Icons.privacy_tip),
            label: Text(
              'すべての同意を再設定',
              style: TextStyle(
                fontSize: 16 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeSettings.buttonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _withdrawAllConsents,
            icon: const Icon(Icons.cancel),
            label: Text(
              'すべての同意を撤回',
              style: TextStyle(
                fontSize: 16 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showConsentEditDialog(ConsentRequest request) async {
    await ConsentDialogHelper.showCustomConsentDialog(
      context,
      [request],
      isRequired: request.isRequired,
      onComplete: () {
        _loadConsentData();
      },
    );
  }

  Future<void> _showAllConsentDialog() async {
    final allRequests = ConsentService.getConsentRequests();

    await ConsentDialogHelper.showCustomConsentDialog(
      context,
      allRequests,
      isRequired: false,
      onComplete: () {
        _loadConsentData();
      },
    );
  }

  Future<void> _withdrawAllConsents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('すべての同意を撤回しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('撤回', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ConsentService.withdrawAllConsents();
        await _loadConsentData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('すべての同意を撤回しました'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('同意の撤回に失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
