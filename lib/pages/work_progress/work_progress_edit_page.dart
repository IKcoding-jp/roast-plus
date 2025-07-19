import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/work_progress_models.dart';
import '../../models/theme_settings.dart';
import '../../services/experience_manager.dart';

class WorkProgressEditPage extends StatefulWidget {
  final WorkProgress? workProgress;

  const WorkProgressEditPage({this.workProgress, super.key});

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
  void dispose() {
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

      if (widget.workProgress == null) {
        await workProgressProvider.addWorkProgress(workProgress);

        // 新規作成時のみ経験値を獲得
        final result = await ExperienceManager.instance
            .addWorkProgressExperience(workDate: now);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('作業状況記録を作成しました (+${result.xpGained}XP)'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('作業状況記録を作成しました')));
        }
      } else {
        await workProgressProvider.updateWorkProgress(workProgress);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('作業状況記録を更新しました')));
      }

      Navigator.pop(context);
      // 少し遅延を入れてからデータを再読み込み
      Future.delayed(Duration(milliseconds: 100), () {
        workProgressProvider.loadWorkProgress();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      value: _selectedStage,
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
                      onChanged: (value) {
                        setState(() {
                          _selectedStage = value;
                          // 作業段階が変更されたら状況もリセット
                          if (value != _selectedStage) {
                            _selectedStatus = WorkStatus.before;
                          }
                        });
                      },
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
                      SizedBox(height: 12),
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
                                _getStageDisplayName(_selectedStage!),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: themeSettings.fontColor1,
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<WorkStatus>(
                                      title: Text('前'),
                                      value: WorkStatus.before,
                                      groupValue: _selectedStatus,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStatus = value;
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<WorkStatus>(
                                      title: Text('済'),
                                      value: WorkStatus.after,
                                      groupValue: _selectedStatus,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStatus = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    ),
                    SizedBox(height: 32),

                    // 保存ボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveWorkProgress,
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
    );
  }
}
