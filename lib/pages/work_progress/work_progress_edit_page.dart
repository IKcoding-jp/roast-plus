import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../models/work_progress_models.dart';
import '../../models/theme_settings.dart';
import '../../models/group_provider.dart';

class WorkProgressEditPage extends StatefulWidget {
  final WorkProgress? workProgress;
  final String? groupId;

  const WorkProgressEditPage({this.workProgress, this.groupId, super.key});

  @override
  State<WorkProgressEditPage> createState() => _WorkProgressEditPageState();
}

class _WorkProgressEditPageState extends State<WorkProgressEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _beanNameController = TextEditingController();
  final _notesController = TextEditingController();
  WorkStage? _selectedStage;
  WorkStatus? _selectedStatus = WorkStatus.before; // デフォルトで「前」を選択

  bool _isLoading = false;
  bool _canEdit = true;
  String? _permissionMessage;
  bool _didCheckPermission = false;

  @override
  void initState() {
    super.initState();
    if (widget.workProgress != null) {
      _beanNameController.text = widget.workProgress!.beanName;
      _notesController.text = widget.workProgress!.notes ?? '';

      // 既存の記録から最初の作業段階を取得
      if (widget.workProgress!.stageStatus.isNotEmpty) {
        final firstEntry = widget.workProgress!.stageStatus.entries.first;
        _selectedStage = firstEntry.key;
        _selectedStatus = firstEntry.value;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCheckPermission || !mounted) return;
    _didCheckPermission = true;
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    if (groupProvider.hasGroup) {
      final userRole = groupProvider.getCurrentUserRole();
      final groupSettings = groupProvider.getCurrentGroupSettings();
      if (userRole != null && groupSettings != null) {
        if (mounted) {
          setState(() {
            _canEdit = groupSettings.canEditDataType(
              'work_progress', // ←ここを修正
              userRole,
            );
            _permissionMessage = _canEdit
                ? null
                : 'このグループで作業状況記録の追加・編集権限がありません。';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _canEdit = false;
            _permissionMessage = '権限情報の取得に失敗しました。';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _canEdit = true;
          _permissionMessage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _didCheckPermission = false;
    _beanNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _getStageDisplayName(WorkStage stage) {
    switch (stage) {
      case WorkStage.handpick:
        return 'ハンドピック';
      case WorkStage.roast:
        return 'ロースト';
      case WorkStage.afterPick:
        return 'アフターピック';
      case WorkStage.mill:
        return 'ミル';
      case WorkStage.dripPack:
        return 'ドリップパック';
      case WorkStage.threeWayBag:
        return '三方袋';
      case WorkStage.packaging:
        return '梱包';
      case WorkStage.shipping:
        return '発送';
    }
  }

  Future<void> _saveWorkProgress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final workProgressProvider = context.read<WorkProgressProvider>();
      final now = DateTime.now();
      final workProgress = WorkProgress(
        id: widget.workProgress?.id ?? '',
        beanName: _beanNameController.text.trim(),
        beanId:
            widget.workProgress?.beanId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        stageStatus: _selectedStage != null
            ? {_selectedStage!: _selectedStatus!}
            : {},
        createdAt: widget.workProgress?.createdAt ?? now,
        updatedAt: now,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        userId: 'local_user',
      );

      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      if (widget.workProgress == null) {
        await workProgressProvider.addWorkProgress(
          workProgress,
          groupId: widget.groupId,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('作業状況記録を作成しました'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await workProgressProvider.updateWorkProgress(
          workProgress,
          groupId: widget.groupId,
        );
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('作業状況記録を更新しました')));
      }
      if (!mounted) return;
      navigator.pop(true); // 保存完了を親画面に伝える
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final isEditing = widget.workProgress != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '作業状況記録を編集' : '作業状況記録を作成'),
        backgroundColor: themeSettings.appBarColor,
        foregroundColor: themeSettings.appBarTextColor,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: kIsWeb ? 720 : 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_permissionMessage != null)
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock, color: Colors.red),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _permissionMessage!,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 豆の名前
                        TextFormField(
                          controller: _beanNameController,
                          decoration: InputDecoration(
                            labelText: '豆の名前 *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: themeSettings.inputBackgroundColor,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '豆の名前を入力してください';
                            }
                            return null;
                          },
                          enabled: _canEdit,
                        ),
                        SizedBox(height: 24),

                        // 作業段階の選択
                        Text(
                          '現在の作業段階',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeSettings.fontColor1,
                          ),
                        ),
                        SizedBox(height: 16),

                        // 作業段階のドロップダウン
                        DropdownButtonFormField<WorkStage>(
                          initialValue: _selectedStage,
                          decoration: InputDecoration(
                            labelText: '作業段階を選択',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: themeSettings.inputBackgroundColor,
                          ),
                          items: [
                            DropdownMenuItem<WorkStage>(
                              value: null,
                              child: Text('作業段階を選択してください'),
                            ),
                            ...WorkStage.values.map((stage) {
                              return DropdownMenuItem<WorkStage>(
                                value: stage,
                                child: Text(_getStageDisplayName(stage)),
                              );
                            }),
                          ],
                          onChanged: _canEdit
                              ? (value) {
                                  setState(() {
                                    _selectedStage = value;
                                    // 作業段階が変更されたら状況もリセット
                                    if (value != _selectedStage) {
                                      _selectedStatus = WorkStatus.before;
                                    }
                                  });
                                }
                              : null,
                        ),
                        SizedBox(height: 16),

                        // 作業状況の選択（作業段階が選択されている場合のみ表示）
                        if (_selectedStage != null) ...[
                          Text(
                            '作業状況',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: themeSettings.fontColor1,
                            ),
                          ),
                          SizedBox(height: 8),
                          DropdownButtonFormField<WorkStatus>(
                            initialValue: _selectedStatus,
                            decoration: InputDecoration(
                              labelText: '作業状況を選択',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: themeSettings.inputBackgroundColor,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: WorkStatus.before,
                                child: Text('前'),
                              ),
                              DropdownMenuItem(
                                value: WorkStatus.inProgress,
                                child: Text('途中'),
                              ),
                              DropdownMenuItem(
                                value: WorkStatus.after,
                                child: Text('済'),
                              ),
                            ],
                            onChanged: _canEdit
                                ? (value) {
                                    setState(() {
                                      _selectedStatus = value;
                                    });
                                  }
                                : null,
                          ),
                          SizedBox(height: 24),
                        ],

                        SizedBox(height: 24),

                        // メモ
                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            labelText: 'メモ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: themeSettings.inputBackgroundColor,
                          ),
                          maxLines: 3,
                          enabled: _canEdit,
                        ),
                        SizedBox(height: 32),

                        // 保存ボタン
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canEdit ? _saveWorkProgress : null,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isEditing ? '更新' : '作成',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
