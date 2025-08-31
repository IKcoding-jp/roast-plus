import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:roastplus/pages/drip/drip_pack_record_list_page.dart';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';
import '../../models/dashboard_stats_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../services/user_settings_firestore_service.dart';
import '../../services/group_data_sync_service.dart';
import '../../utils/permission_utils.dart';
import '../../utils/web_compatibility.dart';
import '../../widgets/permission_denied_page.dart';
import 'dart:developer' as developer;

class DripCounterPage extends StatefulWidget {
  const DripCounterPage({super.key});

  @override
  State<DripCounterPage> createState() => DripCounterPageState();
}

class DripCounterPageState extends State<DripCounterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _beanController = TextEditingController();
  int _counter = 0;
  final List<String> _roastLevels = ['浅煎り', '中煎り', '中深煎り', '深煎り'];
  String? _selectedRoast;
  // Stateに追加
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // 権限チェック用の状態変数
  bool _canUseDripCounter = true;
  bool _isCheckingPermission = true;
  StreamSubscription<bool>? _permissionSubscription;

  // Firestore同期用 記録リスト
  String? _currentGroupId;
  void setDripRecordsFromFirestore(List<Map<String, dynamic>> records) {
    setState(() {
      // _records = List<Map<String, dynamic>>.from(records); // This line was removed
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _loadDripRecordsFromFirestore();
    _startDripRecordsListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkGroupChange();
    // 権限チェックとリスナーの開始
    if (_isCheckingPermission) {
      _checkPermission();
      _startPermissionListener();
    }
  }

  /// グループ変更をチェックして、必要に応じてデータをクリア
  void _checkGroupChange() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final currentGroupId = groupProvider.hasGroup
        ? groupProvider.currentGroup!.id
        : null;

    // グループが変更された場合、データをクリア
    if (_currentGroupId != null && _currentGroupId != currentGroupId) {
      setState(() {
        // _records = []; // This line was removed
        _counter = 0;
        _beanController.clear();
        _selectedRoast = null;
      });
      // グループ変更時に権限監視も再開始
      _startPermissionListener();
    }

    _currentGroupId = currentGroupId;
  }

  /// 権限チェック
  Future<void> _checkPermission() async {
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        final canUse = await PermissionUtils.canCreateDataType(
          groupId: groupProvider.currentGroup!.id,
          dataType: 'dripCounter',
        );
        if (mounted) {
          setState(() {
            _canUseDripCounter = canUse;
            _isCheckingPermission = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _canUseDripCounter = true;
            _isCheckingPermission = false;
          });
        }
      }
    } catch (e, st) {
      developer.log(
        'ドリップパックカウンター権限チェックエラー',
        name: 'DripCounterPage',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _canUseDripCounter = false;
          _isCheckingPermission = false;
        });
      }
    }

    // タイムアウト処理（5秒後に強制的に権限チェックを終了）
    Future.delayed(Duration(seconds: 5), () {
      if (mounted && _isCheckingPermission) {
        setState(() {
          _canUseDripCounter = true; // デフォルトで許可
          _isCheckingPermission = false;
        });
      }
    });
  }

  Future<void> _loadDripRecordsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dripPackRecords')
        .doc(docId)
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['records'] != null) {
        if (!mounted) return;
        setState(() {
          // _records = List<Map<String, dynamic>>.from(data['records']); // This line was removed
        });
      }
    }
  }

  StreamSubscription? _dripRecordsSubscription;
  void _startDripRecordsListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today = DateTime.now();
    final docId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _dripRecordsSubscription?.cancel();
    _dripRecordsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dripPackRecords')
        .doc(docId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (data['records'] != null) {
              if (!mounted) return;
              setState(() {
                // _records = List<Map<String, dynamic>>.from(data['records']); // This line was removed
              });
            }
          }
        });
  }

  void _startPermissionListener() {
    // didChangeDependenciesで呼ばれるため、contextが利用可能
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    if (groupProvider.hasGroup) {
      _permissionSubscription?.cancel();
      _permissionSubscription = PermissionUtils.listenForPermissionChange(
        groupId: groupProvider.currentGroup!.id,
        dataType: 'dripCounter',
        onPermissionChange: (canUse) {
          if (mounted) {
            setState(() {
              _canUseDripCounter = canUse;
              _isCheckingPermission = false;
            });
          }
        },
      );
    } else {
      _permissionSubscription?.cancel();
      if (mounted) {
        setState(() {
          _canUseDripCounter = true;
          _isCheckingPermission = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _beanController.dispose();
    _animationController.dispose();
    _dripRecordsSubscription?.cancel();
    _permissionSubscription?.cancel();
    super.dispose();
  }

  // カウンター更新時
  void _addToCounter(int value) {
    setState(() {
      _counter = (_counter + value).clamp(0, 500);
    });
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    // 権限チェック中
    if (_isCheckingPermission) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(
                Icons.coffee,
                color: Provider.of<ThemeSettings>(context).iconColor,
              ),
              SizedBox(width: 8),
              Text('ドリップパックカウンター'),
            ],
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Provider.of<ThemeSettings>(context).buttonColor,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Provider.of<ThemeSettings>(context).fontColor1,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 権限がない場合
    if (!_canUseDripCounter) {
      return PermissionDeniedPage(
        title: 'ドリップパックカウンター',
        message: 'ドリップパックカウンターを使用するには、管理者またはリーダーの権限が必要です。',
        additionalInfo:
            'メンバーがドリップパックカウンターを使用できる設定が有効になっている場合は、管理者またはリーダーに設定の確認を依頼してください。',
        customIcon: Icons.coffee,
        onBackPressed: () {
          // ホームに戻る
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
      );
    }

    // 美しいグラデーションカラーパレット
    final primaryGradient = LinearGradient(
      colors: [
        themeSettings.buttonColor,
        themeSettings.buttonColor.withValues(alpha: 0.8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final cardGradient = LinearGradient(
      colors: [
        themeSettings.cardBackgroundColor,
        themeSettings.cardBackgroundColor.withValues(alpha: 0.95),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // Web版とモバイル版でレイアウトを分岐
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'ドリップパックカウンター',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          if (_canUseDripCounter)
            IconButton(
              icon: Icon(Icons.list, color: themeSettings.iconColor),
              tooltip: '記録一覧',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DripPackRecordListPage()),
                );
              },
            ),
        ],
      ),
      body: kIsWeb
          ? _buildWebLayout(themeSettings, primaryGradient, cardGradient)
          : _buildMobileLayout(themeSettings, primaryGradient, cardGradient),
    );
  }

  Widget _buildCountButton(
    int value, {
    double fontSize = 22,
    LinearGradient? primaryGradient,
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final isPositive = value > 0;

    return Container(
      decoration: BoxDecoration(
        gradient:
            primaryGradient ??
            LinearGradient(
              colors: [
                themeSettings.buttonColor,
                themeSettings.buttonColor.withValues(alpha: 0.8),
              ],
            ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: themeSettings.buttonColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addToCounter(value),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              isPositive ? '+$value' : '$value',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    double fontSize = 17,
    double iconSize = 22,
    double labelFontSize = 16,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeSettings.iconColor.withValues(alpha: 0.1),
                    themeSettings.iconColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: themeSettings.iconColor, size: iconSize),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: labelFontSize,
                color: themeSettings.fontColor1,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: themeSettings.inputBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: contentPadding,
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: fontSize,
              ),
            ),
            style: TextStyle(
              fontSize: fontSize,
              color: themeSettings.fontColor1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoastDropdown({
    double fontSize = 17,
    double iconSize = 22,
    double labelFontSize = 16,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeSettings.iconColor.withValues(alpha: 0.1),
                    themeSettings.iconColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_fire_department,
                color: themeSettings.iconColor,
                size: iconSize,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '煎り度',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: labelFontSize,
                color: themeSettings.fontColor1,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: themeSettings.inputBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedRoast,
            items: _roastLevels
                .map(
                  (level) => DropdownMenuItem(
                    value: level,
                    child: Text(
                      level,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: themeSettings.fontColor1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedRoast = val;
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: contentPadding,
              hintText: '煎り度を選択',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: fontSize,
              ),
            ),
            style: TextStyle(
              fontSize: fontSize,
              color: themeSettings.fontColor1,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: themeSettings.cardBackgroundColor,
            icon: Icon(Icons.arrow_drop_down, color: themeSettings.iconColor),
            selectedItemBuilder: (BuildContext context) {
              return _roastLevels.map<Widget>((String item) {
                return Text(
                  item,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: themeSettings.fontColor1,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addRecord() async {
    final bean = _beanController.text.trim();
    final roast = _selectedRoast;
    final count = _counter;
    if (bean.isEmpty || roast == null || roast.isEmpty || count <= 0) return;

    try {
      final now = DateTime.now();
      final newRecord = {
        'bean': bean,
        'roast': roast,
        'count': count,
        'timestamp': now.toIso8601String(),
      };

      // グループプロバイダーを取得
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (groupProvider.hasGroup) {
        // グループモード：グループの共有データにのみ同期
        final groupId = groupProvider.currentGroup!.id;

        // 既存のグループデータを取得
        final existingData =
            await GroupDataSyncService.getGroupDripCounterRecords(groupId);
        List<Map<String, dynamic>> records = [];

        if (existingData != null && existingData['records'] != null) {
          records = List<Map<String, dynamic>>.from(existingData['records']);
        }

        // 新しい記録を追加
        records.insert(0, newRecord);

        // グループの共有データに同期
        await GroupDataSyncService.syncDripCounterRecords(groupId, {
          'records': records,
        });

        developer.log(
          'ドリップパック記録をグループに同期しました: $count袋',
          name: 'DripCounterPage',
        );
      } else {
        // ローカルモード：ローカルデータにのみ保存
        final saved = await UserSettingsFirestoreService.getSetting(
          'dripPackRecords',
        );
        List<Map<String, dynamic>> records = [];
        if (saved != null) {
          records = List<Map<String, dynamic>>.from(saved);
        }
        records.insert(0, newRecord);
        await UserSettingsFirestoreService.saveSetting(
          'dripPackRecords',
          records,
        );
        developer.log(
          'ドリップパック記録をローカルに保存しました: $count袋',
          name: 'DripCounterPage',
        );
      }

      // グループレベルシステムでドリップパック記録を処理（グループモードの場合のみ）
      if (groupProvider.hasGroup) {
        await _processDripPackForGroup(count, bean, now);
      }

      // 統計データを更新
      if (mounted) {
        final statsProvider = Provider.of<DashboardStatsProvider>(
          context,
          listen: false,
        );
        await statsProvider.onDripPackAdded();
      }

      // UIをリセット
      if (!mounted) return;
      setState(() {
        _beanController.clear();
        _selectedRoast = null;
        _counter = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count袋の記録を保存しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, st) {
      developer.log(
        'ドリップパック記録保存エラー',
        name: 'DripCounterPage',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// グループレベルシステムでドリップパック記録を処理
  Future<void> _processDripPackForGroup(
    int count,
    String bean,
    DateTime createDate,
  ) async {
    try {
      // グループプロバイダーを取得
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;

        // グループのゲーミフィケーションシステムに通知（統一された演出を使用）
        await groupProvider.processGroupDripPack(
          groupId,
          count,
          context: context,
        );
      }
    } catch (e, st) {
      developer.log(
        'グループレベルシステム処理エラー',
        name: 'DripCounterPage',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// カウンター入力ダイアログを表示
  void _showCounterInputDialog() {
    final TextEditingController inputController = TextEditingController(
      text: _counter.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final themeSettings = Provider.of<ThemeSettings>(context);

        return AlertDialog(
          backgroundColor: themeSettings.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'カウンターを設定',
            style: TextStyle(
              color: themeSettings.fontColor1,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '0〜500の数字を入力してください',
                style: TextStyle(
                  color: themeSettings.fontColor1.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: inputController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: themeSettings.fontColor1,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: themeSettings.fontColor1.withValues(alpha: 0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: themeSettings.iconColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: themeSettings.iconColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: themeSettings.backgroundColor,
                ),
                onSubmitted: (value) {
                  _updateCounterFromInput(value);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'キャンセル',
                style: TextStyle(
                  color: themeSettings.fontColor1.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _updateCounterFromInput(inputController.text);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeSettings.buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('設定'),
            ),
          ],
        );
      },
    );
  }

  /// 入力された値でカウンターを更新
  void _updateCounterFromInput(String value) {
    final int? newValue = int.tryParse(value);
    if (newValue != null && newValue >= 0 && newValue <= 500) {
      setState(() {
        _counter = newValue;
      });
    } else if (newValue != null && newValue > 500) {
      // 500を超える値の場合はエラーメッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('500以下の数字を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // 無効な値の場合はエラーメッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('有効な数字を入力してください'), backgroundColor: Colors.red),
      );
    }
  }

  /// Web版専用レイアウト
  Widget _buildWebLayout(
    ThemeSettings themeSettings,
    LinearGradient primaryGradient,
    LinearGradient cardGradient,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: themeSettings.cardBackgroundColor,
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // カウンター表示
                  SizedBox(
                    height: 200,
                    child: Stack(
                      children: [
                        // 背景装飾
                        Positioned(
                          top: -20,
                          right: -20,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  themeSettings.buttonColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // カウンター数字
                        Center(
                          child: AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: GestureDetector(
                                  onTap: () => _showCounterInputDialog(),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$_counter',
                                        style: WebCompatibility.isWeb
                                            ? WebCompatibility.createTextStyle(
                                                fontSize: 72,
                                                fontWeight: FontWeight.w900,
                                                color: themeSettings.fontColor1,
                                                letterSpacing: 2,
                                                fontFamily: 'Arial',
                                                shadows: [
                                                  WebCompatibility.createShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(2, 2),
                                                  ),
                                                  WebCompatibility.createShadow(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.8),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              )
                                            : TextStyle(
                                                fontSize: 72,
                                                fontWeight: FontWeight.w900,
                                                foreground: Paint()
                                                  ..shader =
                                                      LinearGradient(
                                                        colors: [
                                                          themeSettings
                                                              .fontColor1,
                                                          themeSettings
                                                              .fontColor1
                                                              .withValues(
                                                                alpha: 0.8,
                                                              ),
                                                        ],
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                      ).createShader(
                                                        Rect.fromLTWH(
                                                          0,
                                                          0,
                                                          200,
                                                          72,
                                                        ),
                                                      ),
                                                letterSpacing: 2,
                                                fontFamily: 'Arial',
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.1),
                                                    blurRadius: 8,
                                                    offset: Offset(2, 2),
                                                  ),
                                                  Shadow(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.8),
                                                    blurRadius: 2,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '袋',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: themeSettings.fontColor1
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // リセットボタン（右上）
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  themeSettings.iconColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  themeSettings.iconColor.withValues(
                                    alpha: 0.05,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: themeSettings.iconColor.withValues(
                                  alpha: 0.2,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.refresh,
                                color: themeSettings.iconColor,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _counter = 0;
                                });
                              },
                              tooltip: 'カウンターをリセット',
                              padding: EdgeInsets.all(6),
                              constraints: BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  // カウンター操作ボタン
                  Row(
                    children: [
                      for (final v in [-10, -5, -1, 1, 5, 10])
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3),
                            child: SizedBox(
                              height: 44,
                              child: _buildCountButton(
                                v,
                                fontSize: 16,
                                primaryGradient: primaryGradient,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // 記録情報入力
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          label: '豆の種類',
                          controller: _beanController,
                          icon: Icons.coffee,
                          hint: '例: グアテマラ',
                          fontSize: 15,
                          iconSize: 18,
                          labelFontSize: 13,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildRoastDropdown(
                          fontSize: 15,
                          iconSize: 18,
                          labelFontSize: 13,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // 保存ボタン
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: themeSettings.buttonColor.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save, size: 20),
                        label: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            '記録を保存',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeSettings.appButtonColor,
                          foregroundColor: themeSettings.fontColor2,
                          textStyle: TextStyle(fontSize: 16),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _addRecord,
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

  /// モバイル版専用レイアウト
  Widget _buildMobileLayout(
    ThemeSettings themeSettings,
    LinearGradient primaryGradient,
    LinearGradient cardGradient,
  ) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final availableHeight = constraints.maxHeight - 32 - keyboardHeight;
          final double minSectionHeight = 120;
          final double sectionHeight = (availableHeight / 3).clamp(
            minSectionHeight,
            double.infinity,
          );
          final double buttonFont = 28;

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // 1. カウンター枠
                  SizedBox(
                    height: sectionHeight,
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: cardGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 1,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // 背景装飾
                          Positioned(
                            top: -20,
                            right: -20,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    themeSettings.buttonColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          // カウンター数字（タップ可能）
                          Center(
                            child: AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: GestureDetector(
                                    onTap: () => _showCounterInputDialog(),
                                    child: Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        color: Colors.transparent,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$_counter',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: WebCompatibility.isWeb
                                                ? WebCompatibility.createTextStyle(
                                                    fontSize: 120,
                                                    fontWeight: FontWeight.w900,
                                                    color: themeSettings
                                                        .fontColor1,
                                                    letterSpacing: 2,
                                                    fontFamily: 'Arial',
                                                    shadows: [
                                                      WebCompatibility.createShadow(
                                                        color: Colors.black
                                                            .withValues(alpha: 0.1),
                                                        blurRadius: 8,
                                                        offset: const Offset(
                                                          2,
                                                          2,
                                                        ),
                                                      ),
                                                      WebCompatibility.createShadow(
                                                        color: Colors.white
                                                            .withValues(alpha: 0.8),
                                                        blurRadius: 2,
                                                        offset: const Offset(
                                                          0,
                                                          1,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : TextStyle(
                                                    fontSize: 120,
                                                    fontWeight: FontWeight.w900,
                                                    foreground: Paint()
                                                      ..shader =
                                                          LinearGradient(
                                                            colors: [
                                                              themeSettings
                                                                  .fontColor1,
                                                              themeSettings
                                                                  .fontColor1
                                                                  .withValues(
                                                                    alpha: 0.8,
                                                                  ),
                                                            ],
                                                            begin: Alignment
                                                                .topCenter,
                                                            end: Alignment
                                                                .bottomCenter,
                                                          ).createShader(
                                                            Rect.fromLTWH(
                                                              0,
                                                              0,
                                                              200,
                                                              120,
                                                            ),
                                                          ),
                                                    letterSpacing: 2,
                                                    fontFamily: 'Arial',
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        blurRadius: 8,
                                                        offset: Offset(2, 2),
                                                      ),
                                                      Shadow(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        blurRadius: 2,
                                                        offset: Offset(0, 1),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // リセットボタン（右上）
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    themeSettings.iconColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    themeSettings.iconColor.withValues(
                                      alpha: 0.05,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: themeSettings.iconColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.refresh,
                                  color: themeSettings.iconColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _counter = 0;
                                  });
                                },
                                tooltip: 'カウンターをリセット',
                                padding: EdgeInsets.all(8),
                                constraints: BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // 2. ボタン枠
                  SizedBox(
                    height: sectionHeight,
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: cardGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 1,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final v in [-10, -5, -1, 1, 5, 10])
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: SizedBox(
                                    height: sectionHeight * 0.7,
                                    child: _buildCountButton(
                                      v,
                                      fontSize: buttonFont,
                                      primaryGradient: primaryGradient,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // 3. 入力フォーム枠
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: minSectionHeight,
                      maxHeight: sectionHeight * 1.5,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: cardGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 1,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    label: '豆の種類',
                                    controller: _beanController,
                                    icon: Icons.coffee,
                                    hint: '例: グアテマラ',
                                    fontSize: 17,
                                    iconSize: 22,
                                    labelFontSize: 16,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: _buildRoastDropdown(
                                    fontSize: 17,
                                    iconSize: 22,
                                    labelFontSize: 16,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeSettings.buttonColor
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.save, size: 22),
                                  label: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      '記録を保存',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        themeSettings.appButtonColor,
                                    foregroundColor: themeSettings.fontColor2,
                                    textStyle: TextStyle(fontSize: 16),
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _addRecord,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
