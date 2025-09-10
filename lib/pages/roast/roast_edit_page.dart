import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import '../../utils/permission_utils.dart';

class RoastEditPage extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const RoastEditPage({super.key, required this.initialData});

  @override
  State<RoastEditPage> createState() => _RoastEditPageState();
}

class _RoastEditPageState extends State<RoastEditPage> {
  late TextEditingController _beanController;
  late TextEditingController _minuteController;
  late TextEditingController _secondController;
  late TextEditingController _memoController;
  late String _selectedRoast;
  late String _selectedWeight;
  late String _timestamp;
  bool _canEdit = true;
  bool _isCheckingPermissions = true;

  @override
  void initState() {
    super.initState();
    final timeParts =
        (widget.initialData['time'] as String?)?.split(':') ?? ['0', '0'];
    _beanController = TextEditingController(
      text: widget.initialData['bean'] ?? '',
    );
    _selectedWeight = widget.initialData['weight'] ?? '300';
    _minuteController = TextEditingController(text: timeParts[0]);
    _secondController = TextEditingController(
      text: timeParts.length > 1 ? timeParts[1] : '0',
    );
    _selectedRoast = widget.initialData['roast'] ?? '中煎り';
    _memoController = TextEditingController(
      text: widget.initialData['memo'] ?? '',
    );
    _timestamp =
        widget.initialData['timestamp'] ?? DateTime.now().toIso8601String();

    // 権限チェックを実行
    _checkPermissions();
  }

  // 権限チェック
  Future<void> _checkPermissions() async {
    try {
      developer.log('権限チェック開始', name: 'RoastEditPage');

      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.hasGroup) {
        developer.log('グループに参加中 - 権限チェック実行', name: 'RoastEditPage');

        final canEdit = await PermissionUtils.canEditDataType(
          groupId: groupProvider.currentGroup!.id,
          dataType: 'roastRecords',
        );

        developer.log('権限チェック結果 - 編集: $canEdit', name: 'RoastEditPage');

        setState(() {
          _canEdit = canEdit;
          _isCheckingPermissions = false;
        });
      } else {
        developer.log('グループに参加していないため、編集可能', name: 'RoastEditPage');
        setState(() {
          _canEdit = true;
          _isCheckingPermissions = false;
        });
      }
    } catch (e) {
      developer.log('権限チェックエラー: $e', name: 'RoastEditPage', error: e);
      setState(() {
        _canEdit = false;
        _isCheckingPermissions = false;
      });
    }
  }

  // 権限エラーメッセージを表示
  void _showPermissionError() {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final currentGroup = groupProvider.currentGroup;

    String message;
    if (currentGroup == null) {
      message = 'グループに参加していません';
    } else {
      final groupSettings = groupProvider.getCurrentGroupSettings();
      final permission = groupSettings?.getPermissionForDataType(
        'roastRecords',
      );

      switch (permission) {
        case AccessLevel.adminOnly:
          message = '管理者のみ編集可能です';
          break;
        case AccessLevel.adminLeader:
          message = '管理者・リーダーのみ編集可能です';
          break;
        case AccessLevel.allMembers:
          message = '全メンバーが編集可能です';
          break;
        default:
          message = '権限がありません';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _saveChanges() {
    // 権限チェック
    if (!_canEdit) {
      _showPermissionError();
      return;
    }

    final updated = {
      'bean': _beanController.text.trim(),
      'weight': _selectedWeight,
      'time':
          '${_minuteController.text.trim().padLeft(2, '0')}:${_secondController.text.trim().padLeft(2, '0')}',
      'roast': _selectedRoast,
      'memo': _memoController.text.trim(),
      'timestamp': _timestamp,
    };
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        final canEdit = _canEdit;

        // 権限チェック中
        if (_isCheckingPermissions) {
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    color: Provider.of<ThemeSettings>(context).iconColor,
                  ),
                  SizedBox(width: 8),
                  Text('記録の編集'),
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

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: Provider.of<ThemeSettings>(context).iconColor,
                ),
                SizedBox(width: 8),
                Text('記録の編集'),
              ],
            ),
            actions: [if (!canEdit) Icon(Icons.lock, color: Colors.orange)],
          ),
          body: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWeb ? 40.0 : 16.0,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: kIsWeb ? 700 : double.infinity,
                  ),
                  child: Column(
                    children: [
                      if (!canEdit)
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: Colors.orange.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '権限がないため、編集できません',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!canEdit) SizedBox(height: 20),

                      // すべての項目を1つのカードにまとめる
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: Provider.of<ThemeSettings>(
                          context,
                        ).cardBackgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // カードタイトル
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).iconColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.edit_note,
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).iconColor,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    '焙煎記録の編集',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Provider.of<ThemeSettings>(
                                        context,
                                      ).fontColor1,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),

                              // 豆の種類
                              _buildInputRow(
                                label: '豆の種類',
                                icon: Icons.coffee,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _beanController,
                                    enabled: canEdit,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      hintText: '例：ブラジル、コロンビア',
                                      hintStyle: TextStyle(
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1.withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 12),

                              // 重さ
                              _buildInputRow(
                                label: '重さ（g）',
                                icon: Icons.scale,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedWeight,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      hintText: '重さを選択',
                                      hintStyle: TextStyle(
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1.withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                    items: ['200', '300', '500']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text('${e}g'),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: canEdit
                                        ? (v) => setState(
                                            () => _selectedWeight = v!,
                                          )
                                        : null,
                                  ),
                                ),
                              ),

                              SizedBox(height: 12),

                              // 焙煎時間
                              _buildInputRow(
                                label: '焙煎時間',
                                icon: Icons.timer,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _minuteController,
                                          enabled: canEdit,
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                decimal: false,
                                                signed: false,
                                              ),
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                            hintText: '分',
                                            hintStyle: TextStyle(
                                              color:
                                                  Provider.of<ThemeSettings>(
                                                    context,
                                                  ).fontColor1.withValues(
                                                    alpha: 0.6,
                                                  ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      ':',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _secondController,
                                          enabled: canEdit,
                                          keyboardType:
                                              TextInputType.numberWithOptions(
                                                decimal: false,
                                                signed: false,
                                              ),
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                            hintText: '秒',
                                            hintStyle: TextStyle(
                                              color:
                                                  Provider.of<ThemeSettings>(
                                                    context,
                                                  ).fontColor1.withValues(
                                                    alpha: 0.6,
                                                  ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 12),

                              // 煎り度
                              _buildInputRow(
                                label: '煎り度',
                                icon: Icons.local_fire_department,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedRoast,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      hintText: '煎り度を選択',
                                      hintStyle: TextStyle(
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1.withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                    items: ['浅煎り', '中煎り', '中深煎り', '深煎り']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: canEdit
                                        ? (v) => setState(
                                            () => _selectedRoast = v!,
                                          )
                                        : null,
                                  ),
                                ),
                              ),

                              SizedBox(height: 12),

                              // メモ
                              _buildInputRow(
                                label: 'メモ',
                                icon: Icons.note,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _memoController,
                                    enabled: canEdit,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      hintText: 'メモを入力してください',
                                      hintStyle: TextStyle(
                                        color: Provider.of<ThemeSettings>(
                                          context,
                                        ).fontColor1.withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 32),

                      // 保存ボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: canEdit ? _saveChanges : null,
                          icon: Icon(Icons.save, size: 20),
                          label: Text(
                            '変更を保存',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context)
                                    .elevatedButtonTheme
                                    .style
                                    ?.backgroundColor
                                    ?.resolve(<WidgetState>{}) ??
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context)
                                    .elevatedButtonTheme
                                    .style
                                    ?.foregroundColor
                                    ?.resolve(<WidgetState>{}) ??
                                Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 4,
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
      },
    );
  }

  Widget _buildInputRow({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Provider.of<ThemeSettings>(context).iconColor,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Provider.of<ThemeSettings>(context).fontColor1,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        child,
      ],
    );
  }
}
