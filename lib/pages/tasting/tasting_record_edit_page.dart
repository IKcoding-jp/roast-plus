import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tasting_models.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';

class TastingRecordEditPage extends StatefulWidget {
  final TastingRecord? tastingRecord;

  const TastingRecordEditPage({super.key, this.tastingRecord});

  @override
  State<TastingRecordEditPage> createState() => _TastingRecordEditPageState();
}

class _TastingRecordEditPageState extends State<TastingRecordEditPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _beanNameController = TextEditingController();
  final TextEditingController _overallImpressionController =
      TextEditingController();

  DateTime _selectedDate = DateTime.now();
  double _acidity = 3.0;
  double _bitterness = 3.0;
  double _aroma = 3.0;
  double _overallRating = 3.0;

  bool _isEditing = false;
  bool _isDuplicate = false;
  List<TastingRecord> _existingTastings = [];

  final List<String> _roastLevels = ['浅煎り', '中煎り', '中深煎り', '深煎り'];
  String _selectedRoastLevel = '中深煎り';

  @override
  void initState() {
    super.initState();
    _beanNameController.addListener(_checkDuplicate);

    if (widget.tastingRecord != null) {
      _loadTastingRecord(widget.tastingRecord!);
      _isEditing = true;
    }
  }

  void _loadTastingRecord(TastingRecord tastingRecord) {
    _beanNameController.text = tastingRecord.beanName;
    // 既存データの「深入り」を「深煎り」に変換
    String roastLevel = tastingRecord.roastLevel;
    if (roastLevel == '深入り') {
      roastLevel = '深煎り';
    }
    // 有効な選択肢に含まれていない場合はデフォルト値を使用
    if (!_roastLevels.contains(roastLevel)) {
      roastLevel = '中深煎り';
    }
    _selectedRoastLevel = roastLevel;
    _overallImpressionController.text = tastingRecord.overallImpression;
    _selectedDate = tastingRecord.tastingDate;
    _acidity = tastingRecord.acidity;
    _bitterness = tastingRecord.bitterness;
    _aroma = tastingRecord.aroma;
    _overallRating = tastingRecord.overallRating;
  }

  @override
  void dispose() {
    _beanNameController.removeListener(_checkDuplicate);
    _beanNameController.dispose();
    _overallImpressionController.dispose();
    super.dispose();
  }

  void _checkDuplicate() {
    final beanName = _beanNameController.text.trim();
    final roastLevel = _selectedRoastLevel;

    if (beanName.isNotEmpty && roastLevel.isNotEmpty) {
      final tastingProvider = context.read<TastingProvider>();
      final isDuplicate = tastingProvider.isDuplicateTasting(
        beanName,
        roastLevel,
      );
      final existingTastings = tastingProvider.getExistingTastings(
        beanName,
        roastLevel,
      );

      setState(() {
        _isDuplicate = isDuplicate;
        _existingTastings = existingTastings;
      });
    } else {
      setState(() {
        _isDuplicate = false;
        _existingTastings = [];
      });
    }
  }

  void _showHelpDialog(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '各項目の説明',
          style: TextStyle(
            color: themeSettings.fontColor1,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                '豆の名前',
                '試飲したコーヒー豆の名前を入力してください。\n例: エチオピア シダモ、グアテマラ アンティグア',
                themeSettings,
              ),
              _buildHelpItem(
                '焙煎度合い',
                '豆の焙煎の深さを表します。\n• 浅煎り: ライトロースト、シナモンロースト\n• 中煎り: ミディアムロースト、ハイロースト\n• 深煎り: シティロースト、フルシティロースト',
                themeSettings,
              ),
              _buildHelpItem(
                '酸味',
                'コーヒーの酸っぱさの強さです。\n• 弱い: 酸味をほとんど感じない\n• 強い: レモンやオレンジのような爽やかな酸味',
                themeSettings,
              ),
              _buildHelpItem(
                '苦味',
                'コーヒーの苦さの強さです。\n• 弱い: 苦味をほとんど感じない\n• 強い: ダークチョコレートのような強い苦味',
                themeSettings,
              ),
              _buildHelpItem(
                '香り',
                'コーヒーの香りの強さです。\n• 弱い: 香りをほとんど感じない\n• 強い: 花やフルーツのような豊かな香り',
                themeSettings,
              ),
              _buildHelpItem(
                'おいしさ',
                'コーヒー全体の満足度を評価します。\n• 低い: あまり好ましくない\n• 高い: 非常に満足できる',
                themeSettings,
              ),
              _buildHelpItem(
                '全体的な印象',
                'コーヒー全体のバランスや飲みやすさについて記録します。\n例: バランスが良く飲みやすい、酸味が効いて爽やか',
                themeSettings,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(
    String title,
    String description,
    ThemeSettings themeSettings,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: themeSettings.fontColor1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: themeSettings.fontColor1.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeSettings.fontColor1,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 1.0,
          max: 5.0,
          divisions: 8,
          activeColor: themeSettings.buttonColor,
          inactiveColor: themeSettings.fontColor1.withValues(alpha: 0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _saveTastingRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final tastingProvider = context.read<TastingProvider>();
    final groupProvider = context.read<GroupProvider>();
    final beanName = _beanNameController.text.trim();
    final roastLevel = _selectedRoastLevel;
    final now = DateTime.now();
    final groupId = groupProvider.hasGroup
        ? groupProvider.currentGroup!.id
        : null;

    // 既存レコードを検索
    final existing = tastingProvider.getExistingTastings(beanName, roastLevel);
    String recordId = widget.tastingRecord?.id ?? '';
    DateTime createdAt = widget.tastingRecord?.createdAt ?? now;
    String userId = widget.tastingRecord?.userId ?? 'local_user';
    if (!_isEditing && existing.isNotEmpty) {
      // 新規作成時、同じ豆＋焙煎度合いがあればそのIDで上書き
      recordId = existing.first.id;
      createdAt = existing.first.createdAt;
      userId = existing.first.userId;
    }

    final tastingRecord = TastingRecord(
      id: recordId,
      beanName: beanName,
      tastingDate: _selectedDate,
      roastLevel: roastLevel,
      acidity: _acidity,
      bitterness: _bitterness,
      aroma: _aroma,
      overallRating: _overallRating,
      overallImpression: _overallImpressionController.text.trim(),
      createdAt: createdAt,
      updatedAt: now,
      userId: userId,
      groupId: groupId,
    );

    try {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      if (_isEditing || (!_isEditing && existing.isNotEmpty)) {
        await tastingProvider.updateTastingRecord(
          tastingRecord,
          groupId: groupId,
        );
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('試飲感想記録を更新しました')));
      } else {
        await tastingProvider.addTastingRecord(tastingRecord, groupId: groupId);
        // グループレベルシステムで試飲記録を処理
        await _processTastingForGroup();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('試飲感想記録を保存しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました')));
    }
  }

  /// グループレベルシステムで試飲記録を処理
  Future<void> _processTastingForGroup() async {
    try {
      // グループプロバイダーを取得
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);

      if (groupProvider.hasGroup) {
        final groupId = groupProvider.currentGroup!.id;

        // グループのゲーミフィケーションシステムに通知
        await groupProvider.processGroupTasting(groupId, context: context);
      }
    } catch (e) {
      debugPrint('グループレベルシステム処理エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '試飲感想を編集' : '試飲感想を記録'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final groupProvider = context.read<GroupProvider>();
                final tastingProvider = context.read<TastingProvider>();
                final recordId = widget.tastingRecord!.id;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('削除確認'),
                    content: Text('この試飲感想記録を削除しますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('削除'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    final groupId = groupProvider.hasGroup
                        ? groupProvider.currentGroup!.id
                        : null;

                    await tastingProvider.deleteTastingRecord(
                      recordId,
                      groupId: groupId,
                    );

                    // ストリームでリストから消えるまで待つ
                    await Future.doWhile(() async {
                      await Future.delayed(Duration(milliseconds: 100));
                      return tastingProvider.tastingRecords.any(
                        (r) => r.id == recordId,
                      );
                    });

                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(content: Text('削除しました')));
                    navigator.pop();
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('削除に失敗しました')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本情報セクション
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '基本情報',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _beanNameController,
                        decoration: InputDecoration(
                          labelText: '豆の名前 *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '豆の名前を入力してください';
                          }
                          return null;
                        },
                        // 常に入力可能に修正
                        enabled: true,
                      ),

                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRoastLevel,
                        decoration: InputDecoration(
                          labelText: '焙煎度合い *',
                          border: OutlineInputBorder(),
                        ),
                        items: _roastLevels.map((String level) {
                          return DropdownMenuItem<String>(
                            value: level,
                            child: Text(level),
                          );
                        }).toList(),
                        // 常に選択可能に修正
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedRoastLevel = newValue!;
                          });
                          _checkDuplicate();
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '焙煎度合いを選択してください';
                          }
                          return null;
                        },
                      ),
                      // 重複警告表示
                      if (_isDuplicate && !_isEditing) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '重複警告',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                '同じ豆の種類と焙煎度合いの組み合わせが既に存在します。',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '既存の記録数:  ${_existingTastings.length}件',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: themeSettings.fontColor1.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              // 評価セクション
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '評価 (1-5段階)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildRatingSlider('酸味', _acidity, (value) {
                        setState(() {
                          _acidity = value;
                        });
                      }),
                      _buildRatingSlider('苦味', _bitterness, (value) {
                        setState(() {
                          _bitterness = value;
                        });
                      }),
                      _buildRatingSlider('香り', _aroma, (value) {
                        setState(() {
                          _aroma = value;
                        });
                      }),
                      _buildRatingSlider('おいしさ', _overallRating, (value) {
                        setState(() {
                          _overallRating = value;
                        });
                      }),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              // 感想セクション
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '感想',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeSettings.fontColor1,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _overallImpressionController,
                        decoration: InputDecoration(
                          labelText: '全体的な印象',
                          border: OutlineInputBorder(),
                          hintText: '例: バランスが良く、飲みやすい',
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32),
              // 保存ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!_isDuplicate || _isEditing)
                      ? _saveTastingRecord
                      : null,
                  child: Text(_isEditing ? '更新' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
