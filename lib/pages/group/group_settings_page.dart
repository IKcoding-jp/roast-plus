import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_models.dart';
import '../../models/theme_settings.dart';
import '../../services/group_firestore_service.dart';

class GroupSettingsPage extends StatefulWidget {
  final Group group;

  const GroupSettingsPage({required this.group, super.key});

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  GroupSettings? _settings;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await GroupFirestoreService.getGroupSettings(
        widget.group.id,
      );
      setState(() {
        _settings = settings ?? GroupSettings.defaultSettings();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _settings = GroupSettings.defaultSettings();
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    setState(() {
      _saving = true;
    });

    try {
      await GroupFirestoreService.updateGroupSettings(
        groupId: widget.group.id,
        settings: _settings!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定を保存しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('設定の保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _updateDataPermission(String dataType, DataPermission permission) {
    if (_settings == null) return;

    final updatedPermissions = Map<String, DataPermission>.from(
      _settings!.dataPermissions,
    );
    updatedPermissions[dataType] = permission;

    setState(() {
      _settings = _settings!.copyWith(dataPermissions: updatedPermissions);
    });
    
    // 設定をリアルタイムで保存
    _saveSettingsRealtime();
  }

  // リアルタイムで設定を保存（自動保存）
  Future<void> _saveSettingsRealtime() async {
    if (_settings == null) return;

    try {
      print('GroupSettingsPage: リアルタイム設定保存開始');
      await GroupFirestoreService.updateGroupSettings(
        groupId: widget.group.id,
        settings: _settings!,
      );
      print('GroupSettingsPage: リアルタイム設定保存完了');
    } catch (e) {
      print('GroupSettingsPage: リアルタイム設定保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'データ権限設定',
          style: TextStyle(
            color: themeSettings.appBarTextColor,
            fontSize: 20 * themeSettings.fontSizeScale,
            fontWeight: FontWeight.bold,
            fontFamily: themeSettings.fontFamily,
          ),
        ),
        backgroundColor: themeSettings.appBarColor,
        iconTheme: IconThemeData(color: themeSettings.iconColor),
        actions: [
          if (!_loading && _settings != null)
            IconButton(
              icon: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: themeSettings.fontColor2,
                      ),
                    )
                  : Icon(Icons.save, color: themeSettings.iconColor),
              onPressed: _saving ? null : _saveSettings,
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: themeSettings.iconColor),
            )
          : _settings == null
          ? Center(
              child: Text(
                '設定の読み込みに失敗しました',
                style: TextStyle(
                  color: themeSettings.fontColor1,
                  fontSize: 16 * themeSettings.fontSizeScale,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // データ権限設定
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.backgroundColor2 ?? Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: themeSettings.iconColor,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'データ権限設定',
                                style: TextStyle(
                                  color: themeSettings.fontColor1,
                                  fontSize: 18 * themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '各データタイプの編集権限を設定できます',
                            style: TextStyle(
                              color: themeSettings.fontColor1,
                              fontSize: 14 * themeSettings.fontSizeScale,
                              fontFamily: themeSettings.fontFamily,
                            ),
                          ),
                          SizedBox(height: 16),
                          ..._buildDataPermissionSettings(),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // メンバー権限設定
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeSettings.backgroundColor2 ?? Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: themeSettings.iconColor,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'メンバー権限設定',
                                style: TextStyle(
                                  color: themeSettings.fontColor1,
                                  fontSize: 18 * themeSettings.fontSizeScale,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeSettings.fontFamily,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          ..._buildMemberPermissionSettings(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildDataPermissionSettings() {
    final themeSettings = Provider.of<ThemeSettings>(context);
    final dataTypes = {
      'roast_records': '焙煎記録一覧',
      'todo_list': 'TODOリスト',
      'drip_counter_records': 'ドリップカウンター',
      'assignment_board': '担当表',
      'today_assignment': '今日の担当履歴',
      'assignment_history': '担当履歴',
      'schedule': 'スケジュール',
      'today_schedule': '本日のスケジュール',
      'time_labels': '時間ラベル',
      'settings': '設定',
    };

    return dataTypes.entries.map((entry) {
      final dataType = entry.key;
      final displayName = entry.value;
      final currentPermission = _settings!.getPermissionForDataType(dataType);

      return Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: TextStyle(
                color: themeSettings.fontColor1,
                fontSize: 16 * themeSettings.fontSizeScale,
                fontWeight: FontWeight.bold,
                fontFamily: themeSettings.fontFamily,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: DataPermission.values.map((permission) {
                final isSelected = currentPermission == permission;
                final label = _getPermissionLabel(permission);
                final color = _getPermissionColor(permission);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _updateDataPermission(dataType, permission),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? color : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? color : Colors.grey,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : themeSettings.fontColor1,
                            fontSize: 12 * themeSettings.fontSizeScale,
                            fontWeight: FontWeight.bold,
                            fontFamily: themeSettings.fontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildMemberPermissionSettings() {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return [
      _buildPermissionSwitch(
        title: 'メンバーが招待できる',
        description: 'メンバーが他のユーザーをグループに招待できるようにする',
        value: _settings!.allowMemberInvite,
        onChanged: (value) {
          setState(() {
            _settings = _settings!.copyWith(allowMemberInvite: value);
          });
          _saveSettingsRealtime();
        },
      ),
      SizedBox(height: 16),
      _buildPermissionSwitch(
        title: 'メンバーがデータ同期できる',
        description: 'メンバーがグループとのデータ同期を実行できるようにする',
        value: _settings!.allowMemberDataSync,
        onChanged: (value) {
          setState(() {
            _settings = _settings!.copyWith(allowMemberDataSync: value);
          });
          _saveSettingsRealtime();
        },
      ),
      SizedBox(height: 16),
      _buildPermissionSwitch(
        title: 'メンバーがメンバー一覧を見れる',
        description: 'メンバーがグループのメンバー一覧を閲覧できるようにする',
        value: _settings!.allowMemberViewMembers,
        onChanged: (value) {
          setState(() {
            _settings = _settings!.copyWith(allowMemberViewMembers: value);
          });
          _saveSettingsRealtime();
        },
      ),
    ];
  }

  Widget _buildPermissionSwitch({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final themeSettings = Provider.of<ThemeSettings>(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: themeSettings.fontColor1,
                  fontSize: 16 * themeSettings.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: themeSettings.fontColor1,
                  fontSize: 12 * themeSettings.fontSizeScale,
                  fontFamily: themeSettings.fontFamily,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: themeSettings.buttonColor,
        ),
      ],
    );
  }

  String _getPermissionLabel(DataPermission permission) {
    switch (permission) {
      case DataPermission.leaderOnly:
        return 'リーダーのみ';
      case DataPermission.allMembers:
        return '全メンバー';
      case DataPermission.readOnly:
        return '閲覧のみ';
    }
  }

  Color _getPermissionColor(DataPermission permission) {
    switch (permission) {
      case DataPermission.leaderOnly:
        return Colors.orange;
      case DataPermission.allMembers:
        return Colors.green;
      case DataPermission.readOnly:
        return Colors.grey;
    }
  }
}
