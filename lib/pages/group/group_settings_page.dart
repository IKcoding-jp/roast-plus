import 'dart:developer' as developer;
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
    // print('GroupSettingsPage: initState開始');
    // print('GroupSettingsPage: グループID: ${widget.group.id}');
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // print('GroupSettingsPage: _loadSettings開始');
    try {
      final settings = await GroupFirestoreService.getGroupSettings(
        widget.group.id,
      );
      // print('GroupSettingsPage: 設定取得完了: $settings');
      setState(() {
        _settings = settings ?? GroupSettings.defaultSettings();
        _loading = false;
      });
      // print('GroupSettingsPage: setState完了 - _settings: $_settings');
    } catch (e) {
      // print('GroupSettingsPage: 設定取得エラー: $e');
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
      // print('GroupSettingsPage: 手動保存時のsettings: ${_settings!.toJson()}');
      await GroupFirestoreService.updateGroupSettings(
        groupId: widget.group.id,
        settings: _settings!,
      );
      // print('GroupSettingsPage: 手動保存完了');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定を保存しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // print('GroupSettingsPage: 手動保存エラー: $e');
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

  void _updateDataPermission(String dataType, AccessLevel permission) {
    if (_settings == null) return;

    // print('GroupSettingsPage: 権限更新開始');
    // print('GroupSettingsPage: データタイプ: $dataType');
    // print('GroupSettingsPage: 新しい権限: $permission');
    // print('GroupSettingsPage: 現在の設定: ${_settings!.dataPermissions}');

    final updatedPermissions = Map<String, AccessLevel>.from(
      _settings!.dataPermissions,
    );
    updatedPermissions[dataType] = permission;

    // print('GroupSettingsPage: 更新後の設定: $updatedPermissions');

    setState(() {
      _settings = _settings!.copyWith(dataPermissions: updatedPermissions);
    });

    // print('GroupSettingsPage: setState完了');
    // print(
    //   'GroupSettingsPage: setState後の_settings.dataPermissions: ${_settings!.dataPermissions}',
    // );

    // 設定をリアルタイムで保存
    _saveSettingsRealtime();
  }

  // リアルタイムで設定を保存（自動保存）
  Future<void> _saveSettingsRealtime() async {
    if (_settings == null) return;

    try {
      // print(
      //   'GroupSettingsPage: Firestoreに保存するsettings: ${_settings!.toJson()}',
      // );
      await GroupFirestoreService.updateGroupSettings(
        groupId: widget.group.id,
        settings: _settings!,
      );
      // print('GroupSettingsPage: Firestore保存完了');
    } catch (e) {
      // print('GroupSettingsPage: Firestore保存エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    developer.log(
      'build開始 - _loading: $_loading, _settings: $_settings',
      name: 'GroupSettingsPage',
    );
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
                    color: themeSettings.cardBackgroundColor,
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
                          ..._buildDataPermissionSettings(themeSettings),
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
                    color: themeSettings.cardBackgroundColor,
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
                          ..._buildMemberPermissionSettings(themeSettings),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildDataPermissionSettings(ThemeSettings themeSettings) {
    developer.log('_buildDataPermissionSettings開始', name: 'GroupSettingsPage');
    developer.log('_settings: $_settings', name: 'GroupSettingsPage');
    if (_settings != null) {
      developer.log(
        '現在のdataPermissions: ${_settings!.dataPermissions}',
        name: 'GroupSettingsPage',
      );
    }

    final dataTypes = {
      'work_progress': '作業状況記録',
      'roastRecords': '焙煎記録一覧',
      'dripCounter': 'ドリップパックカウンター',
      'assignment_board': '担当表', // 担当表関連の権限を一本化
      'todaySchedule': '本日のスケジュール',
      'cuppingNotes': '試飲感想記録',
      'circleStamps': '丸シール設定',
    };

    return dataTypes.entries.map((entry) {
      final dataType = entry.key;
      final displayName = entry.value;
      final currentPermission = _settings!.getPermissionForDataType(dataType);

      developer.log(
        '$dataType の現在の権限: $currentPermission',
        name: 'GroupSettingsPage',
      );

      // 選択状態を配列で表現
      List<bool> selected = [false, false, false];
      switch (currentPermission) {
        case AccessLevel.adminOnly:
          selected = [true, false, false];
          break;
        case AccessLevel.adminLeader:
          selected = [true, true, false];
          break;
        case AccessLevel.allMembers:
          selected = [true, true, true];
          break;
      }

      developer.log('$dataType の選択状態: $selected', name: 'GroupSettingsPage');

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
              children: [
                // 管理者ボタン
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        developer.log(
                          '管理者ボタンタップ - データタイプ: $dataType',
                          name: 'GroupSettingsPage',
                        );
                        _updateDataPermission(dataType, AccessLevel.adminOnly);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected[0]
                              ? _getPermissionColor(AccessLevel.adminOnly)
                              : Colors.transparent,
                          border: Border.all(
                            color: selected[0]
                                ? _getPermissionColor(AccessLevel.adminOnly)
                                : Colors.grey,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '管理者',
                          style: TextStyle(
                            color: selected[0]
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
                ),
                // リーダーボタン
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        developer.log(
                          'リーダーボタンタップ - データタイプ: $dataType',
                          name: 'GroupSettingsPage',
                        );
                        _updateDataPermission(
                          dataType,
                          AccessLevel.adminLeader,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected[1]
                              ? _getPermissionColor(AccessLevel.adminLeader)
                              : Colors.transparent,
                          border: Border.all(
                            color: selected[1]
                                ? _getPermissionColor(AccessLevel.adminLeader)
                                : Colors.grey,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'リーダー',
                          style: TextStyle(
                            color: selected[1]
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
                ),
                // メンバーボタン
                Expanded(
                  child: InkWell(
                    onTap: () {
                      developer.log(
                        'メンバーボタンタップ - データタイプ: $dataType',
                        name: 'GroupSettingsPage',
                      );
                      _updateDataPermission(dataType, AccessLevel.allMembers);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected[2]
                            ? _getPermissionColor(AccessLevel.allMembers)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected[2]
                              ? _getPermissionColor(AccessLevel.allMembers)
                              : Colors.grey,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'メンバー',
                        style: TextStyle(
                          color: selected[2]
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
              ],
            ),
            SizedBox(height: 6),
            // 選択状態に応じた説明文を表示
            Builder(
              builder: (_) {
                String desc = '';
                if (currentPermission == AccessLevel.adminOnly) {
                  desc = '管理者が追加・削除・編集できます';
                } else if (currentPermission == AccessLevel.adminLeader) {
                  desc = 'リーダーが追加・削除・編集できます';
                } else if (currentPermission == AccessLevel.allMembers) {
                  desc = 'メンバー全員が追加・削除・編集できます';
                }
                return Text(
                  desc,
                  style: TextStyle(
                    color: themeSettings.fontColor1.withValues(alpha: 0.7),
                    fontSize: 12 * themeSettings.fontSizeScale,
                    fontFamily: themeSettings.fontFamily,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildMemberPermissionSettings(ThemeSettings themeSettings) {
    return [
      _buildPermissionSwitch(
        themeSettings: themeSettings,
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
        themeSettings: themeSettings,
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
    required ThemeSettings themeSettings,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
          activeThumbColor: themeSettings.buttonColor,
        ),
      ],
    );
  }

  Color _getPermissionColor(AccessLevel permission) {
    switch (permission) {
      case AccessLevel.adminOnly:
        return Colors.red; // 管理者のみは赤
      case AccessLevel.adminLeader:
        return Colors.orange; // リーダーのみはオレンジ
      case AccessLevel.allMembers:
        return Colors.green; // メンバーも編集可は緑
    }
  }
}
