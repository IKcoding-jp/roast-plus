import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../models/theme_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/group_data_sync_service.dart';
import '../../models/group_provider.dart';
import '../../models/group_models.dart';
import '../../services/schedule_firestore_service.dart' as ScheduleService;
import '../schedule/schedule_time_label_edit_page.dart';

class TodaySchedule extends StatefulWidget {
  final void Function(void Function())? onEditTimeLabels;
  const TodaySchedule({super.key, this.onEditTimeLabels});

  @override
  State<TodaySchedule> createState() => _TodayScheduleState();
}

class _TodayScheduleState extends State<TodaySchedule> {
  List<String> _scheduleLabels = [''];
  Map<String, String> _scheduleContents = {};
  bool _canEditTodaySchedule = true;
  bool _canEditTimeLabels = true;

  // テキストコントローラー管理
  final Map<String, TextEditingController> _scheduleControllers = {};

  // ラベル追加・削除・初期化時にコントローラを管理
  void _initScheduleControllers() {
    // 新規ラベルのみcontroller生成
    for (final label in _scheduleLabels) {
      if (!_scheduleControllers.containsKey(label)) {
        _scheduleControllers[label] = TextEditingController(
          text: _scheduleContents[label] ?? '',
        );
      }
    }
    // 不要なコントローラを破棄
    final toRemove = _scheduleControllers.keys
        .where((k) => !_scheduleLabels.contains(k))
        .toList();
    for (final k in toRemove) {
      _scheduleControllers[k]?.dispose();
      _scheduleControllers.remove(k);
    }
  }

  // グループデータからの更新（保存しない）
  void _updateFromGroupData(List<String> labels, Map<String, String> contents) {
    print('TodaySchedule: グループデータから更新（保存なし）');

    // リーダーの場合はグループデータで上書きしない
    if (_canEditTodaySchedule) {
      print('TodaySchedule: リーダーのため、グループデータで上書きしません');
      return;
    }

    setState(() {
      _scheduleLabels = labels;
      _scheduleContents = contents;
    });
    _initScheduleControllers();
    _updateScheduleControllers();
  }

  // テキストコントローラーの内容を更新
  void _updateScheduleControllers() {
    print('TodaySchedule: テキストコントローラー更新開始');
    print('TodaySchedule: ラベル数: ${_scheduleLabels.length}');
    print('TodaySchedule: 内容数: ${_scheduleContents.length}');

    // リーダーの場合はテキストコントローラーを更新しない
    if (_canEditTodaySchedule) {
      print('TodaySchedule: リーダーのため、テキストコントローラーを更新しません');
      return;
    }

    for (final label in _scheduleLabels) {
      final controller = _scheduleControllers[label];
      if (controller != null) {
        final newText = _scheduleContents[label] ?? '';
        if (controller.text != newText) {
          print(
            'TodaySchedule: コントローラー更新前 - $label: "${controller.text}" -> "$newText"',
          );
          controller.text = newText;
          print('TodaySchedule: コントローラー更新完了 - $label: "$newText"');
        } else {
          print('TodaySchedule: コントローラー変更なし - $label: "$newText"');
        }
      } else {
        print('TodaySchedule: コントローラーが見つかりません - $label');
      }
    }
    print('TodaySchedule: テキストコントローラー更新完了');
  }

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _setupGroupDataListener();
    _checkEditPermissions();
    _setupFirestoreListener();

    // 親からコールバックを受け取る場合
    if (widget.onEditTimeLabels != null) {
      widget.onEditTimeLabels!(_openLabelEdit);
    }

    // GroupProviderのグループ読み込みを確認
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isEmpty && !groupProvider.loading) {
        print('TodaySchedule: グループが読み込まれていないため、読み込みを開始します');
        groupProvider.loadUserGroups();
      } else if (groupProvider.groups.isNotEmpty) {
        print('TodaySchedule: グループが既に読み込まれています - グループデータ監視を開始');
        _startGroupDataWatching(groupProvider);
        _setupGroupTimeLabelsListener();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _scheduleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final labelsStr = prefs.getString('todaySchedule_labels');
      final contentsStr = prefs.getString('todaySchedule_contents');
      List<String> loadedLabels = [];
      Map<String, String> loadedContents = {};
      if (labelsStr != null) {
        loadedLabels = List<String>.from(json.decode(labelsStr));
      }
      if (contentsStr != null) {
        loadedContents = Map<String, String>.from(json.decode(contentsStr));
      }
      setState(() {
        _scheduleLabels = loadedLabels;
        _scheduleContents = loadedContents;
      });
      _initScheduleControllers();
    } catch (_) {
      setState(() {
        _scheduleLabels = [];
        _scheduleContents = {};
      });
      _initScheduleControllers();
    }
  }

  // ラベル編集後やスケジュールロード後にもコントローラを再初期化
  void _openLabelEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleTimeLabelEditPage(
          labels: _scheduleLabels,
          onLabelsChanged: (newLabels) {
            setState(() {
              _scheduleLabels = List.from(newLabels);
              // _scheduleContents からは値を消さずに残す（ラベルが復活したときに内容も復活するため）
              _initScheduleControllers();
            });
            _saveSchedules();
          },
        ),
      ),
    );
  }

  Future<void> _saveSchedules() async {
    print('TodaySchedule: _saveSchedules 開始');
    print('TodaySchedule: ラベル: $_scheduleLabels');
    print('TodaySchedule: 内容: $_scheduleContents');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'todaySchedule_labels',
        json.encode(_scheduleLabels),
      );
      await prefs.setString(
        'todaySchedule_contents',
        json.encode(_scheduleContents),
      );

      final groupProvider = context.read<GroupProvider>();
      final isNoGroup = groupProvider.groups.isEmpty;

      // グループ未参加時 or リーダー時はFirestoreに保存
      if (_canEditTodaySchedule || isNoGroup) {
        try {
          print('TodaySchedule: Firestoreに保存開始（リーダーまたはグループ未参加）');
          await ScheduleService.ScheduleFirestoreService.saveTodayTodoSchedule(
            labels: _scheduleLabels,
            contents: _scheduleContents,
          );
          print('TodaySchedule: Firestoreに保存完了');

          // グループ参加時のみグループ同期
          if (!isNoGroup) {
            await _triggerGroupSync();
          }
        } catch (e) {
          print('TodaySchedule: Firestore保存エラー: $e');
        }
      } else {
        print('TodaySchedule: メンバーのため、ローカル保存のみ実行');
      }
    } catch (e) {
      print('TodaySchedule: ローカル保存エラー: $e');
    }
  }

  // グループ同期を実行
  Future<void> _triggerGroupSync() async {
    try {
      print('TodaySchedule: グループ同期を開始');
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        await GroupDataSyncService.syncTodaySchedule(group.id, {
          'labels': _scheduleLabels,
          'contents': _scheduleContents,
          'savedAt': DateTime.now().toIso8601String(),
        });
        print('TodaySchedule: グループ同期完了');
      }
    } catch (e) {
      print('TodaySchedule: グループ同期エラー: $e');
    }
  }

  // 時間ラベル保存用のメソッドを追加
  Future<void> _saveTimeLabels(List<String> labels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('todaySchedule_labels', json.encode(labels));
    setState(() {
      _scheduleLabels = List.from(labels);
      _initScheduleControllers();
    });
    final groupProvider = context.read<GroupProvider>();
    final isNoGroup = groupProvider.groups.isEmpty;
    if (_canEditTimeLabels || isNoGroup) {
      try {
        await ScheduleService.ScheduleFirestoreService.saveTimeLabels(labels);
      } catch (e) {
        print('TodaySchedule: 時間ラベルFirestore保存エラー: $e');
      }
    }
  }

  // Firestoreからのリアルタイム更新を監視
  void _setupFirestoreListener() {
    print('TodaySchedule: Firestoreリスナーを設定開始');
    try {
      final today = DateTime.now();
      final docId =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 本日のスケジュールの変更を監視（メンバーのみ）
      if (!_canEditTodaySchedule) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('todaySchedule')
            .doc(docId)
            .snapshots()
            .listen((snapshot) {
              print('TodaySchedule: Firestoreからスケジュール変更を検知（メンバー）');
              if (snapshot.exists && snapshot.data() != null) {
                final data = snapshot.data()!;
                print('TodaySchedule: 受信したデータ: $data');
                setState(() {
                  _scheduleLabels = List<String>.from(data['labels'] ?? []);
                  _scheduleContents = Map<String, String>.from(
                    data['contents'] ?? {},
                  );
                });
                _initScheduleControllers();
                _updateScheduleControllers();
                print('TodaySchedule: スケジュールを更新しました（メンバー）');
              }
            });
      }

      // 時間ラベルの変更を監視（メンバーのみ）
      if (!_canEditTimeLabels) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('labels')
            .doc('timeLabels')
            .snapshots()
            .listen((snapshot) {
              print('TodaySchedule: Firestoreから時間ラベル変更を検知（メンバー）');
              if (snapshot.exists && snapshot.data() != null) {
                final data = snapshot.data()!;
                print('TodaySchedule: 受信した時間ラベルデータ: $data');
                setState(() {
                  _scheduleLabels = List<String>.from(data['labels'] ?? []);
                });
                _initScheduleControllers();
                print('TodaySchedule: 時間ラベルを更新しました（メンバー）');
              }
            });
      }

      print('TodaySchedule: Firestoreリスナー設定完了');
    } catch (e) {
      print('TodaySchedule: Firestoreリスナー設定エラー: $e');
    }
  }

  // グループの時間ラベル変更を監視
  void _setupGroupTimeLabelsListener() {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;

        // グループの時間ラベル変更を監視（メンバーのみ）
        if (!_canEditTimeLabels) {
          GroupDataSyncService.watchGroupTimeLabels(group.id).listen((data) {
            print('TodaySchedule: グループから時間ラベル変更を検知（メンバー）: $data');
            if (data != null) {
              final labels = data['labels'] as List<dynamic>?;
              if (labels != null) {
                setState(() {
                  _scheduleLabels = List<String>.from(labels);
                });
                _initScheduleControllers();
                print('TodaySchedule: グループから時間ラベルを更新しました（メンバー）');
              }
            }
          });
        }

        // グループの本日のスケジュール変更を監視（メンバーのみ）
        if (!_canEditTodaySchedule) {
          GroupDataSyncService.watchGroupTodaySchedule(group.id).listen((data) {
            print('TodaySchedule: グループから本日のスケジュール変更を検知（メンバー）: $data');
            if (data != null) {
              final labels = data['labels'] as List<dynamic>?;
              final contents = data['contents'] as Map<String, dynamic>?;
              if (labels != null) {
                _updateFromGroupData(
                  List<String>.from(labels),
                  contents != null ? Map<String, String>.from(contents) : {},
                );
                print('TodaySchedule: グループから本日のスケジュールを更新しました（メンバー）');
              }
            }
          });
        }
      }
    } catch (e) {
      print('TodaySchedule: グループ時間ラベルリスナー設定エラー: $e');
    }
  }

  // グループデータの変更を監視
  void _setupGroupDataListener() {
    print('TodaySchedule: グループデータリスナーを設定開始');

    // GroupProviderの変更を監視
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupProvider = context.read<GroupProvider>();

      // 初回のグループデータ監視開始
      _startGroupDataWatching(groupProvider);

      // GroupProviderの変更を監視
      groupProvider.addListener(() {
        print('TodaySchedule: GroupProviderの変更を検知');
        print('TodaySchedule: グループ数: ${groupProvider.groups.length}');

        // グループが追加された場合、監視を開始
        _startGroupDataWatching(groupProvider);

        // グループ設定の変更を検知するため、常に権限チェックを実行
        _checkEditPermissions();

        if (groupProvider.isWatchingGroupData) {
          // グループデータが更新されたら、ローカルデータを再読み込み
          // 元のデザインでは個別のFirestore読み込みは不要
        }
      });
    });

    print('TodaySchedule: グループデータリスナー設定完了');
  }

  // グループデータの監視を開始
  void _startGroupDataWatching(GroupProvider groupProvider) {
    if (groupProvider.groups.isNotEmpty && !groupProvider.isWatchingGroupData) {
      print('TodaySchedule: グループデータ監視を開始します');
      groupProvider.startWatchingGroupData();
    }
  }

  // 編集権限をチェック
  Future<void> _checkEditPermissions() async {
    try {
      print('TodaySchedule: 編集権限チェック開始');
      final groupProvider = context.read<GroupProvider>();
      print('TodaySchedule: グループ数: ${groupProvider.groups.length}');

      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        final currentUser = FirebaseAuth.instance.currentUser;
        print('TodaySchedule: 現在のユーザー: ${currentUser?.uid}');

        if (currentUser != null) {
          final userRole = group.getMemberRole(currentUser.uid);
          print('TodaySchedule: ユーザーロール: $userRole');
          final groupSettings = groupProvider.getCurrentGroupSettings();
          print('TodaySchedule: グループ設定: $groupSettings');

          if (groupSettings != null) {
            // 本日のスケジュールの編集権限をチェック
            final canEditTodaySchedule = groupSettings.canEditDataType(
              'today_schedule',
              userRole ?? GroupRole.member,
            );
            // 時間ラベルの編集権限をチェック
            final canEditTimeLabels = groupSettings.canEditDataType(
              'time_labels',
              userRole ?? GroupRole.member,
            );

            print('TodaySchedule: 権限チェック結果:');
            print('TodaySchedule: - today_schedule: $canEditTodaySchedule');
            print('TodaySchedule: - time_labels: $canEditTimeLabels');

            // 現在の権限と比較して変更があったかチェック
            final hasChanged =
                _canEditTodaySchedule != canEditTodaySchedule ||
                _canEditTimeLabels != canEditTimeLabels;

            if (hasChanged) {
              print('TodaySchedule: 権限に変更を検知しました！');
              print(
                'TodaySchedule: 変更前 - today_schedule: $_canEditTodaySchedule, time_labels: $_canEditTimeLabels',
              );
              print(
                'TodaySchedule: 変更後 - today_schedule: $canEditTodaySchedule, time_labels: $canEditTimeLabels',
              );
            }

            setState(() {
              _canEditTodaySchedule = canEditTodaySchedule;
              _canEditTimeLabels = canEditTimeLabels;
            });

            print('TodaySchedule: 編集権限チェック完了');
            print('TodaySchedule: 本日のスケジュール編集可能: $_canEditTodaySchedule');
            print('TodaySchedule: 時間ラベル編集可能: $_canEditTimeLabels');
          } else {
            print('TodaySchedule: グループ設定がnullです');
          }
        } else {
          print('TodaySchedule: 現在のユーザーがnullです');
        }
      } else {
        print('TodaySchedule: グループがありません');
      }
    } catch (e) {
      print('TodaySchedule: 編集権限チェックエラー: $e');
      print('TodaySchedule: エラーの詳細: ${e.toString()}');
    }
  }

  // Firestore同期用setter
  void setScheduleFromFirestore(Map<String, dynamic> schedule) {
    setState(() {
      _scheduleLabels = List<String>.from(schedule['labels'] ?? []);
      _scheduleContents = Map<String, String>.from(schedule['contents'] ?? {});
      _initScheduleControllers();
    });
  }

  void setTimeLabelsFromFirestore(List<String> labels) {
    setState(() {
      _scheduleLabels = labels;
      _initScheduleControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        // グループデータの監視状態を確認
        if (groupProvider.groups.isNotEmpty &&
            !groupProvider.isWatchingGroupData) {
          // グループデータの監視を開始
          WidgetsBinding.instance.addPostFrameCallback((_) {
            groupProvider.startWatchingGroupData();
          });
        }

        // 権限チェックを実行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkEditPermissions();
        });

        return Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color:
                  Provider.of<ThemeSettings>(context).backgroundColor2 ??
                  Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: []),
                    SizedBox(height: 16),
                    if (_scheduleLabels.isEmpty ||
                        (_scheduleLabels.length == 1 &&
                            _scheduleLabels.first.isEmpty))
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 48,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).iconColor.withOpacity(0.5),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '時間ラベルを追加してください',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).fontColor1.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      (_scheduleLabels.length <= 10)
                          ? Column(
                              children: _scheduleLabels
                                  .map(
                                    (label) => Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).buttonColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    Provider.of<ThemeSettings>(
                                                      context,
                                                    ).fontColor1,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: _canEditTodaySchedule
                                                ? TextField(
                                                    controller:
                                                        _scheduleControllers[label],
                                                    keyboardType:
                                                        TextInputType.text,
                                                    enableSuggestions: true,
                                                    autocorrect: true,
                                                    enabled: true,
                                                    onChanged: (v) {
                                                      setState(() {
                                                        _scheduleContents[label] =
                                                            v;
                                                      });
                                                      _saveSchedules();
                                                    },
                                                    maxLines: null,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                    decoration: InputDecoration(
                                                      filled: true,
                                                      fillColor:
                                                          Provider.of<
                                                                ThemeSettings
                                                              >(context)
                                                              .inputBackgroundColor,
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: Colors
                                                              .grey
                                                              .shade300,
                                                        ),
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            borderSide:
                                                                BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300,
                                                                ),
                                                          ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color:
                                                              Provider.of<
                                                                    ThemeSettings
                                                                  >(context)
                                                                  .buttonColor,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 12,
                                                          ),
                                                    ),
                                                  )
                                                : Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Provider.of<
                                                                ThemeSettings
                                                              >(context)
                                                              .inputBackgroundColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      _scheduleContents[label] ??
                                                          '',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          : SizedBox(
                              height: 540, // 10行分程度の高さ（1行約54px）
                              child: ListView.builder(
                                itemCount: _scheduleLabels.length,
                                itemBuilder: (context, idx) {
                                  final label = _scheduleLabels[idx];
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Provider.of<ThemeSettings>(
                                              context,
                                            ).buttonColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Provider.of<ThemeSettings>(
                                                context,
                                              ).fontColor1,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: _canEditTodaySchedule
                                              ? TextField(
                                                  controller:
                                                      _scheduleControllers[label],
                                                  keyboardType:
                                                      TextInputType.text,
                                                  enableSuggestions: true,
                                                  autocorrect: true,
                                                  enabled: true,
                                                  onChanged: (v) {
                                                    setState(() {
                                                      _scheduleContents[label] =
                                                          v;
                                                    });
                                                    _saveSchedules();
                                                  },
                                                  maxLines: null,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                  decoration: InputDecoration(
                                                    filled: true,
                                                    fillColor:
                                                        Provider.of<
                                                              ThemeSettings
                                                            >(context)
                                                            .inputBackgroundColor,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          borderSide:
                                                              BorderSide(
                                                                color: Colors
                                                                    .grey
                                                                    .shade300,
                                                              ),
                                                        ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color:
                                                            Provider.of<
                                                                  ThemeSettings
                                                                >(context)
                                                                .buttonColor,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                )
                                              : Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Provider.of<
                                                              ThemeSettings
                                                            >(context)
                                                            .inputBackgroundColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _scheduleContents[label] ??
                                                        '',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
