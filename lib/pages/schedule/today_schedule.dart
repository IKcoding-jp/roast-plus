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
import '../../services/user_settings_firestore_service.dart';
import '../../services/auto_sync_service.dart';
import '../schedule/schedule_time_label_edit_page.dart';
import '../../services/group_firestore_service.dart';
import 'package:flutter/foundation.dart';

// ▼▼▼ 範囲管理用クラスを追加 ▼▼▼
class _ArrowRange {
  final int start;
  final int end;
  _ArrowRange(this.start, this.end);
  bool contains(int idx) =>
      (start < end) ? (idx > start && idx < end) : (idx < start && idx > end);
  bool isStart(int idx) => idx == start;
  bool isEnd(int idx) => idx == end;
  bool inRange(int idx) => isStart(idx) || isEnd(idx);
}
// ▲▲▲

class TodaySchedule extends StatefulWidget {
  final void Function(void Function())? onEditTimeLabels;
  const TodaySchedule({super.key, this.onEditTimeLabels});

  @override
  State<TodaySchedule> createState() => _TodayScheduleState();
}

class _TodayScheduleState extends State<TodaySchedule>
    with TickerProviderStateMixin {
  List<String> _scheduleLabels = [''];
  Map<String, String> _scheduleContents = {};
  Map<String, TextEditingController> _scheduleControllers = {};
  List<_ArrowRange> _arrowRanges = [];
  bool _canEditTodaySchedule = true;
  bool _isSaving = false; // 保存中フラグを追加
  bool _isEditing = false; // 入力中フラグを追加
  bool _isInitializing = true; // 初期化中フラグを追加
  // time_labelsの権限は削除 - today_scheduleと一本化

  // リスナー関連
  StreamSubscription<DocumentSnapshot>? _scheduleSubscription;
  StreamSubscription<DocumentSnapshot>? _timeLabelsSubscription;
  StreamSubscription<GroupSettings?>? _groupSettingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _groupTodayScheduleSubscription;
  StreamSubscription<Map<String, dynamic>?>? _groupTimeLabelsSubscription;
  StreamSubscription<DocumentSnapshot>? _permissionSubscription; // 権限変更リスナーを追加
  VoidCallback? _groupProviderListener;
  GroupProvider? _groupProvider; // GroupProviderの参照を保存

  // ▼▼▼ 複数範囲用 ▼▼▼
  int? _tempStartIndex;
  // ▲▲▲

  // ▼▼▼ 追加: ラベル選択用インデックス ▼▼▼
  int? _selectedStartIndex;
  int? _selectedEndIndex;
  // ▲▲▲

  // テキストコントローラー管理
  // final Map<String, TextEditingController> _scheduleControllers = {};

  // StreamSubscription管理
  // StreamSubscription? _scheduleSubscription;
  // StreamSubscription? _timeLabelsSubscription;
  // StreamSubscription? _groupTimeLabelsSubscription;
  // StreamSubscription? _groupTodayScheduleSubscription;
  // StreamSubscription? _groupSettingsSubscription;

  // GroupProviderリスナー管理
  // VoidCallback? _groupProviderListener;

  // ラベル追加・削除・初期化時にコントローラを管理
  void _initScheduleControllers() {
    print(
      'TodaySchedule: _initScheduleControllers開始 - ラベル数: ${_scheduleLabels.length}',
    );
    print('TodaySchedule: 現在のラベル: $_scheduleLabels');
    print('TodaySchedule: 現在のコントローラー数: ${_scheduleControllers.length}');

    // 新規ラベルのみcontroller生成
    for (final label in _scheduleLabels) {
      if (!_scheduleControllers.containsKey(label)) {
        print('TodaySchedule: 新規コントローラー作成: $label');
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
      print('TodaySchedule: 不要なコントローラー削除: $k');
      _scheduleControllers[k]?.dispose();
      _scheduleControllers.remove(k);
    }

    print(
      'TodaySchedule: _initScheduleControllers完了 - 最終コントローラー数: ${_scheduleControllers.length}',
    );
  }

  // ▼▼▼ 範囲選択の保存 ▼▼▼
  Future<void> _saveArrowRanges() async {
    try {
      final ranges = _arrowRanges.map((r) => [r.start, r.end]).toList();
      await UserSettingsFirestoreService.saveSetting(
        'todaySchedule_arrowRanges',
        ranges,
      );
    } catch (e) {
      print('範囲選択保存エラー: $e');
    }
  }

  Future<void> _loadArrowRanges() async {
    try {
      final ranges =
          await UserSettingsFirestoreService.getSetting(
            'todaySchedule_arrowRanges',
          ) ??
          [];
      _arrowRanges.clear();
      for (final item in ranges) {
        if (item is List && item.length == 2) {
          _arrowRanges.add(_ArrowRange(item[0], item[1]));
        }
      }
    } catch (e) {
      print('範囲選択読み込みエラー: $e');
    }
  }
  // ▲▲▲

  @override
  void initState() {
    super.initState();
    print('TodaySchedule: initState開始');
    _loadArrowRanges();
    _setupGroupDataListener();
    _setupFirestoreListener();
    _cleanupOldTimeLabelsData(); // 古いtime_labelsデータを削除

    // 初期化処理を一つのコールバックにまとめる
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final groupProvider = context.read<GroupProvider>();
      print(
        'TodaySchedule: GroupProvider確認 - グループ数: ${groupProvider.groups.length}, 読み込み中: ${groupProvider.loading}',
      );

      if (groupProvider.groups.isEmpty && !groupProvider.loading) {
        print('TodaySchedule: グループが読み込まれていないため、ローカルデータを読み込みます');
        // グループ未参加時のみローカルデータを読み込み
        await _loadSchedules();
        groupProvider.loadUserGroups();
      } else if (groupProvider.groups.isNotEmpty) {
        print('TodaySchedule: グループが既に読み込まれています - グループデータ監視を開始');
        _startGroupDataWatching(groupProvider);
        _setupGroupTimeLabelsListener();
        _setupPermissionListener(); // 権限変更リスナーを設定
        // グループが既に読み込まれている場合は権限チェックを実行
        await _checkEditPermissions();
        // 権限チェック完了後にグループデータの初期読み込み
        await _loadGroupData();
      } else {
        // グループが読み込み中の場合は、読み込み完了後に処理を実行
        print('TodaySchedule: グループ読み込み中 - 完了を待機');
        // グループ読み込み完了を待機
        groupProvider.addListener(() async {
          if (!mounted) return;
          if (groupProvider.groups.isNotEmpty) {
            print('TodaySchedule: グループ読み込み完了 - グループデータ監視を開始');
            _startGroupDataWatching(groupProvider);
            _setupGroupTimeLabelsListener();
            _setupPermissionListener(); // 権限変更リスナーを設定
            await _checkEditPermissions();
            await _loadGroupData();
          } else {
            print('TodaySchedule: グループ読み込み完了 - ローカルデータを読み込みます');
            _loadSchedules();
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // GroupProviderの参照を保存
    _groupProvider = context.read<GroupProvider>();
  }

  @override
  void dispose() {
    // フラグをリセット
    _isSaving = false;
    _isEditing = false;
    _isInitializing = false;

    // StreamSubscriptionをキャンセル
    _scheduleSubscription?.cancel();
    _timeLabelsSubscription?.cancel();
    _groupTimeLabelsSubscription?.cancel();
    _groupTodayScheduleSubscription?.cancel();
    _groupSettingsSubscription?.cancel();
    _permissionSubscription?.cancel(); // 権限変更リスナーをキャンセル

    // GroupProviderのリスナーを安全に削除
    if (_groupProviderListener != null && _groupProvider != null) {
      try {
        _groupProvider!.removeListener(_groupProviderListener!);
      } catch (e) {
        // dispose中なのでエラーは無視
        print('TodaySchedule: GroupProviderリスナー削除エラー（無視）: $e');
      }
      _groupProviderListener = null;
    }

    // テキストコントローラーを破棄
    for (final c in _scheduleControllers.values) {
      c.dispose();
    }
    _scheduleControllers.clear();

    super.dispose();
  }

  Future<void> _loadSchedules() async {
    try {
      print('TodaySchedule: スケジュール読み込み開始');

      // グループ参加時はグループデータを優先的に読み込み
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        print('TodaySchedule: グループ参加中 - グループデータを優先読み込み');

        try {
          final todayScheduleData =
              await GroupDataSyncService.getGroupTodaySchedule(group.id);
          if (todayScheduleData != null) {
            final labels = todayScheduleData['labels'] as List<dynamic>?;
            final contents =
                todayScheduleData['contents'] as Map<String, dynamic>?;

            if (labels != null && labels.isNotEmpty) {
              print('TodaySchedule: グループから読み込んだラベル: $labels');
              if (mounted) {
                setState(() {
                  _scheduleLabels = List<String>.from(labels);
                  if (contents != null) {
                    _scheduleContents = Map<String, String>.from(contents);
                  }
                });
                _initScheduleControllers();
                await _loadArrowRanges();
                print('TodaySchedule: グループデータ読み込み完了');
                return; // グループデータが読み込めた場合は終了
              }
            }
          }
        } catch (e) {
          print('TodaySchedule: グループデータ読み込みエラー: $e');
        }
      }

      // グループデータが読み込めない場合はローカルデータを読み込み
      print('TodaySchedule: ローカルデータを読み込みます');

      // グループ参加時は権限チェックを実行
      if (groupProvider.groups.isNotEmpty) {
        await _checkEditPermissions();
      }

      final settings = await UserSettingsFirestoreService.getMultipleSettings([
        'todaySchedule_labels',
        'todaySchedule_contents',
      ]);

      List<String> loadedLabels = [];
      Map<String, String> loadedContents = {};

      if (settings['todaySchedule_labels'] != null) {
        loadedLabels = List<String>.from(settings['todaySchedule_labels']);
        print('TodaySchedule: 読み込んだラベル数: ${loadedLabels.length}');
        print('TodaySchedule: 読み込んだラベル: $loadedLabels');
      } else {
        print('TodaySchedule: ラベルデータがnull');
      }
      if (settings['todaySchedule_contents'] != null) {
        loadedContents = Map<String, String>.from(
          settings['todaySchedule_contents'],
        );
      }

      // ラベルが空の場合は初期ラベルを設定
      if (loadedLabels.isEmpty) {
        loadedLabels = [''];
        print('TodaySchedule: ラベルが空のため初期ラベルを設定');
      }

      if (mounted) {
        setState(() {
          _scheduleLabels = loadedLabels;
          _scheduleContents = loadedContents;
        });
        print('TodaySchedule: setState完了 - 最終ラベル数: ${_scheduleLabels.length}');
        print('TodaySchedule: 最終ラベル: $_scheduleLabels');
        _initScheduleControllers();
        await _loadArrowRanges();
        if (mounted) {
          setState(() {
            // UIの強制更新
          }); // _arrowRangesの反映
          print('TodaySchedule: 最終UI更新完了');
        }
      }
    } catch (e) {
      print('TodaySchedule: スケジュール読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _scheduleLabels = [''];
          _scheduleContents = {};
        });
        _initScheduleControllers();
        _arrowRanges.clear();
        if (mounted) {
          setState(() {
            // エラー時のUI強制更新
          });
        }
      }
    }
  }

  // 時間ラベル編集後やスケジュールロード後にもコントローラを再初期化
  void _openLabelEdit() async {
    // 権限がない場合は編集を許可しない
    if (!_canEditTodaySchedule) {
      print('TodaySchedule: 時間ラベル編集権限がないため、編集を許可しません');
      return;
    }

    print('TodaySchedule: 時間ラベル編集ページを開きます');
    print('TodaySchedule: 現在のラベル: $_scheduleLabels');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleTimeLabelEditPage(
          labels: _scheduleLabels,
          onLabelsChanged: (newLabels) async {
            print('TodaySchedule: onLabelsChangedコールバック開始');
            print('TodaySchedule: 時間ラベル変更検知: $newLabels');
            print('TodaySchedule: 新しいラベル数: ${newLabels.length}');

            // 即座にUIを更新（保存処理の前に）
            if (mounted) {
              setState(() {
                _scheduleLabels = List.from(newLabels);
                // 削除されたラベルの内容も削除
                _scheduleContents.removeWhere(
                  (key, value) => !newLabels.contains(key),
                );
              });
              _initScheduleControllers();
              print(
                'TodaySchedule: UI即座更新完了 - ラベル数: ${_scheduleLabels.length}',
              );
            }

            try {
              // 保存中フラグを設定（保存処理開始時）
              _isSaving = true;
              print('TodaySchedule: onLabelsChangedで保存中フラグを設定: $_isSaving');

              // AutoSyncServiceを一時的に無効化
              AutoSyncService.disableSync();

              // 時間ラベルを保存（グループ同期も含む）
              await _saveTimeLabels(newLabels);

              // グループ同期の完了を待つため、より長く待機
              await Future.delayed(Duration(seconds: 3));

              print('TodaySchedule: 保存処理完了');
            } catch (e) {
              print('TodaySchedule: 保存処理エラー: $e');
            } finally {
              // 保存完了後にフラグをリセット
              _isSaving = false;
              print('TodaySchedule: 保存中フラグをリセット: $_isSaving');

              // AutoSyncServiceを再度有効化
              AutoSyncService.enableSync();
            }

            print('TodaySchedule: onLabelsChangedコールバック終了');
          },
        ),
      ),
    );

    print('TodaySchedule: 時間ラベル編集ページから戻りました - result: $result');

    // 編集ページから戻ってきたら、UIの状態を確認
    if (result == true) {
      print('TodaySchedule: 時間ラベル編集完了、UI状態を確認');
      print('TodaySchedule: 現在のラベル: $_scheduleLabels');
      // 既にonLabelsChangedでUI更新済みのため、追加の処理は不要
    }
  }

  Future<void> _saveSchedules() async {
    print('TodaySchedule: _saveSchedules 開始');
    print('TodaySchedule: ラベル: $_scheduleLabels');
    print('TodaySchedule: 内容: $_scheduleContents');

    // 保存中フラグを設定
    _isSaving = true;
    print('TodaySchedule: _saveSchedulesで保存中フラグを設定: $_isSaving');

    try {
      await UserSettingsFirestoreService.saveMultipleSettings({
        'todaySchedule_labels': _scheduleLabels,
        'todaySchedule_contents': _scheduleContents,
      });

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
            print('TodaySchedule: グループ同期開始');
            await _triggerGroupSync();
            print('TodaySchedule: グループ同期完了');
          }
        } catch (e) {
          print('TodaySchedule: Firestore保存エラー: $e');
        }
      } else {
        print('TodaySchedule: メンバーのため、ローカル保存のみ実行');
      }

      // 保存完了後に少し待機
      await Future.delayed(Duration(milliseconds: 300));
      print('TodaySchedule: _saveSchedules完了');
    } catch (e) {
      print('TodaySchedule: ローカル保存エラー: $e');
    } finally {
      // 保存完了後にフラグをリセット
      _isSaving = false;
      print('TodaySchedule: _saveSchedulesで保存中フラグをリセット: $_isSaving');
    }
  }

  // グループ同期を実行
  Future<void> _triggerGroupSync() async {
    try {
      print('TodaySchedule: グループ同期を開始');
      print('TodaySchedule: 同期するラベル: $_scheduleLabels');
      print('TodaySchedule: 同期する内容: $_scheduleContents');

      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        print('TodaySchedule: グループID: ${group.id}');

        // 同期権限をチェック
        final canSync = await GroupFirestoreService.canSyncDataType(
          groupId: group.id,
          dataType: 'today_schedule',
        );
        print('TodaySchedule: 同期権限チェック結果: $canSync');

        if (!canSync) {
          print('TodaySchedule: 同期権限がありません');
          return;
        }

        final syncData = {
          'labels': _scheduleLabels,
          'contents': _scheduleContents,
          'savedAt': DateTime.now().toIso8601String(),
        };
        print('TodaySchedule: 同期データのsavedAt: ${syncData['savedAt']}');
        print('TodaySchedule: 同期データ: $syncData');

        await GroupDataSyncService.syncTodaySchedule(group.id, syncData);
        print('TodaySchedule: グループ同期完了');
      } else {
        print('TodaySchedule: グループが存在しません');
      }
    } catch (e) {
      print('TodaySchedule: グループ同期エラー: $e');
      print('TodaySchedule: エラーの詳細: ${e.toString()}');
    }
  }

  // 時間ラベル保存用のメソッドを追加
  Future<void> _saveTimeLabels(List<String> labels) async {
    try {
      print('TodaySchedule: 時間ラベル保存開始: $labels');
      print('TodaySchedule: 保存するラベル数: ${labels.length}');

      // ローカル保存を最初に実行（確実に保存）
      print('TodaySchedule: ローカル保存開始');
      await UserSettingsFirestoreService.saveSetting(
        'todaySchedule_labels',
        labels,
      );
      print('TodaySchedule: ローカル保存完了');

      final groupProvider = context.read<GroupProvider>();
      final isNoGroup = groupProvider.groups.isEmpty;

      // グループ未参加時 or 編集権限がある場合はFirestoreに保存
      if (_canEditTodaySchedule || isNoGroup) {
        try {
          print('TodaySchedule: 時間ラベルFirestore保存開始（today_scheduleデータタイプ）');
          // 古いtime_labelsの代わりにtoday_scheduleデータタイプを使用
          await ScheduleService.ScheduleFirestoreService.saveTodayTodoSchedule(
            labels: labels,
            contents: _scheduleContents,
          );
          print('TodaySchedule: 時間ラベルFirestore保存完了');

          // グループ参加時のみグループ同期
          if (!isNoGroup) {
            print('TodaySchedule: グループ同期開始');
            await _triggerGroupSync(); // 時間ラベル専用同期の代わりに全データ同期を使用
            print('TodaySchedule: グループ同期完了');
          }
        } catch (e) {
          print('TodaySchedule: 時間ラベルFirestore保存エラー: $e');
          // Firestore保存に失敗してもローカル保存は成功しているので、エラーを無視
        }
      } else {
        print('TodaySchedule: メンバーのため、ローカル保存のみ実行');
      }

      print('TodaySchedule: 時間ラベル保存完了');
    } catch (e) {
      print('TodaySchedule: 時間ラベル保存エラー: $e');
      // ローカル保存に失敗した場合は例外を再スロー
      rethrow;
    }
  }

  // Firestoreからのリアルタイム更新を監視
  void _setupFirestoreListener() {
    print('TodaySchedule: Firestoreリスナーを設定開始');
    try {
      final groupProvider = context.read<GroupProvider>();
      final isNoGroup = groupProvider.groups.isEmpty;

      // グループ未参加時のみ個人のFirestoreを監視
      if (isNoGroup) {
        final today = DateTime.now();
        final docId =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

        // 本日のスケジュールの変更を監視（グループ未参加時のみ）
        _scheduleSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('todaySchedule')
            .doc(docId)
            .snapshots()
            .listen((snapshot) {
              if (!mounted) return; // mountedチェックを追加
              print('TodaySchedule: Firestoreからスケジュール変更を検知（個人）');
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
                print('TodaySchedule: スケジュールを更新しました（個人）');
              }
            });

        // 時間ラベルの変更を監視（グループ未参加時のみ）
        _timeLabelsSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('labels')
            .doc('timeLabels')
            .snapshots()
            .listen((snapshot) {
              if (!mounted) return; // mountedチェックを追加
              print('TodaySchedule: Firestoreから時間ラベル変更を検知（個人）');
              if (snapshot.exists && snapshot.data() != null) {
                final data = snapshot.data()!;
                print('TodaySchedule: 受信した時間ラベルデータ: $data');
                setState(() {
                  _scheduleLabels = List<String>.from(data['labels'] ?? []);
                });
                _initScheduleControllers();
                print('TodaySchedule: 時間ラベルを更新しました（個人）');
              }
            });
      } else {
        print('TodaySchedule: グループ参加中のため、個人のFirestore監視をスキップ');
      }

      print('TodaySchedule: Firestoreリスナー設定完了');
    } catch (e) {
      print('TodaySchedule: Firestoreリスナー設定エラー: $e');
    }
  }

  // グループの時間ラベル変更を監視
  void _setupGroupTimeLabelsListener() {
    try {
      print('TodaySchedule: グループ時間ラベルリスナー設定開始');

      // 既存の監視をキャンセル
      _groupTimeLabelsSubscription?.cancel();
      _groupTodayScheduleSubscription?.cancel();
      _groupSettingsSubscription?.cancel();
      _permissionSubscription?.cancel(); // 権限変更リスナーをキャンセル

      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        print(
          'TodaySchedule: グループ監視設定 - グループID: ${group.id}, 編集権限: $_canEditTodaySchedule',
        );

        // グループ設定の変更を監視
        _groupSettingsSubscription =
            GroupFirestoreService.watchGroupSettings(group.id).listen((
              groupSettings,
            ) {
              if (!mounted) return;
              print('TodaySchedule: グループ設定変更検知: $groupSettings');

              if (groupSettings != null) {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  final userRole = group.getMemberRole(currentUser.uid);
                  if (userRole != null) {
                    print('TodaySchedule: 設定変更時の権限チェック - ユーザーロール: $userRole');
                    print(
                      'TodaySchedule: 設定変更時のグループ設定: ${groupSettings.dataPermissions}',
                    );

                    final canEditTodaySchedule = groupSettings.canEditDataType(
                      'todaySchedule',
                      userRole,
                    );

                    print(
                      'TodaySchedule: 設定変更による権限チェック - todaySchedule: $canEditTodaySchedule',
                    );

                    if (mounted) {
                      setState(() {
                        _canEditTodaySchedule = canEditTodaySchedule;
                      });
                      print('TodaySchedule: 設定変更によるsetState実行完了');
                    }
                  } else {
                    print('TodaySchedule: 設定変更時 - ユーザーロールがnull');
                  }
                } else {
                  print('TodaySchedule: 設定変更時 - 現在のユーザーがnull');
                }
              } else {
                print('TodaySchedule: 設定変更時 - グループ設定がnull');
              }
            });

        // グループの本日のスケジュール変更を監視（全メンバー）
        print('TodaySchedule: 本日のスケジュール監視を開始（全メンバー）');
        _groupTodayScheduleSubscription =
            GroupDataSyncService.watchGroupTodaySchedule(group.id).listen((
              data,
            ) async {
              if (!mounted) return; // mountedチェックを追加

              // 保存中の場合は自分が保存したデータなのでスキップ（ただし、短時間のみ）
              if (_isSaving) {
                print(
                  'TodaySchedule: 保存中のため、グループデータ更新をスキップ - 保存中フラグ: $_isSaving',
                );
                // 保存中フラグが設定されている場合は、少し待ってから再チェック
                await Future.delayed(Duration(milliseconds: 100));
                if (_isSaving) {
                  print('TodaySchedule: 保存中が継続中のため、更新をスキップ');
                  return;
                }
              }

              // 入力中の場合はユーザーの入力を妨げないようスキップ
              if (_isEditing) {
                print(
                  'TodaySchedule: 入力中のため、グループデータ更新をスキップ - 入力中フラグ: $_isEditing',
                );
                return;
              }

              // 初期化中の場合はスキップ
              if (_isInitializing) {
                print(
                  'TodaySchedule: 初期化中のため、グループデータ更新をスキップ - 初期化中フラグ: $_isInitializing',
                );
                return;
              }

              print('TodaySchedule: グループから本日のスケジュール変更を検知（全メンバー）: $data');
              if (data != null) {
                final labels = data['labels'] as List<dynamic>?;
                final contents = data['contents'] as Map<String, dynamic>?;
                print('TodaySchedule: 受信したラベル: $labels');
                print('TodaySchedule: 受信した内容: $contents');

                if (labels != null) {
                  // 保存中フラグを再チェック（UI更新前に）
                  if (_isSaving) {
                    print(
                      'TodaySchedule: 保存中のため、グループデータ更新をスキップ（UI更新前） - 保存中フラグ: $_isSaving',
                    );
                    return;
                  }

                  // 入力中フラグを再チェック（UI更新前に）
                  if (_isEditing) {
                    print(
                      'TodaySchedule: 入力中のため、グループデータ更新をスキップ（UI更新前） - 入力中フラグ: $_isEditing',
                    );
                    return;
                  }

                  // 初期化中フラグを再チェック（UI更新前に）
                  if (_isInitializing) {
                    print(
                      'TodaySchedule: 初期化中のため、グループデータ更新をスキップ（UI更新前） - 初期化中フラグ: $_isInitializing',
                    );
                    return;
                  }

                  // 現在のラベルと比較して、新しいデータの場合のみ更新
                  final currentLabels = _scheduleLabels;
                  final newLabels = List<String>.from(labels);
                  final newContents = contents != null
                      ? Map<String, String>.from(contents)
                      : <String, String>{};

                  // 保存中フラグを再チェック（データ比較前）
                  if (_isSaving) {
                    print(
                      'TodaySchedule: 保存中のため、グループデータ更新をスキップ（データ比較前） - 保存中フラグ: $_isSaving',
                    );
                    return;
                  }

                  // ラベルまたは内容に変更があるかチェック
                  final labelsChanged =
                      currentLabels.length != newLabels.length ||
                      !listEquals(currentLabels, newLabels);

                  final contentsChanged = !mapEquals(
                    _scheduleContents,
                    newContents,
                  );

                  // 現在のラベルが空でない場合のみ更新（初期化時の誤更新を防ぐ）
                  if ((labelsChanged || contentsChanged) &&
                      currentLabels.isNotEmpty &&
                      currentLabels.first.isNotEmpty) {
                    print('TodaySchedule: データが変更されたため、UIを更新します');
                    print('TodaySchedule: ラベル変更: $labelsChanged');
                    print('TodaySchedule: 内容変更: $contentsChanged');
                    print('TodaySchedule: 現在のラベル: $currentLabels');
                    print('TodaySchedule: 新しいラベル: $newLabels');
                    print('TodaySchedule: 現在の内容: $_scheduleContents');
                    print('TodaySchedule: 新しい内容: $newContents');

                    setState(() {
                      _scheduleLabels = newLabels;
                      _scheduleContents = newContents;
                    });

                    // ローカルデータも更新（確実に保存）
                    _updateLocalData(newLabels, newContents);

                    // テキストコントローラーの内容も更新
                    for (final label in newLabels) {
                      if (_scheduleControllers.containsKey(label)) {
                        final newContent = newContents[label] ?? '';
                        if (_scheduleControllers[label]!.text != newContent) {
                          print(
                            'TodaySchedule: コントローラー内容を更新: $label -> $newContent',
                          );
                          _scheduleControllers[label]!.text = newContent;
                        }
                      }
                    }

                    _initScheduleControllers();
                    print('TodaySchedule: グループから本日のスケジュールを更新しました（全メンバー）');
                    print('TodaySchedule: 更新後のラベル数: ${_scheduleLabels.length}');
                  } else {
                    print('TodaySchedule: データに変更がないため、UI更新をスキップします');
                  }
                }
              } else {
                print('TodaySchedule: グループデータがnullです');
              }
            });

        print('TodaySchedule: グループ時間ラベルリスナー設定完了');
      } else {
        print('TodaySchedule: グループが存在しないため監視を設定しません');
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
      // 保存したGroupProviderの参照を使用
      final groupProvider = _groupProvider ?? context.read<GroupProvider>();

      // 初回のグループデータ監視開始
      _startGroupDataWatching(groupProvider);

      // 既存のリスナーを削除
      if (_groupProviderListener != null) {
        groupProvider.removeListener(_groupProviderListener!);
      }

      // GroupProviderの変更を監視
      groupProvider.addListener(() {
        if (!mounted) return; // mountedチェックを追加
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

      print('TodaySchedule: グループデータリスナー設定完了');
    });
  }

  // グループデータの監視を開始
  void _startGroupDataWatching(GroupProvider groupProvider) {
    if (groupProvider.groups.isNotEmpty && !groupProvider.isWatchingGroupData) {
      print('TodaySchedule: グループデータ監視を開始します');
      groupProvider.startWatchingGroupData();
    }
  }

  // グループデータの初期読み込み
  Future<void> _loadGroupData() async {
    try {
      print('TodaySchedule: グループデータ初期読み込み開始');
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;

        // 権限をチェック
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userRole = group.getMemberRole(currentUser.uid);
          final groupSettings = await GroupFirestoreService.getGroupSettings(
            group.id,
          );

          if (groupSettings != null) {
            final canEditTodaySchedule = groupSettings.canEditDataType(
              'todaySchedule',
              userRole ?? GroupRole.member,
            );

            print('TodaySchedule: 初期権限チェック - 編集権限: $canEditTodaySchedule');

            // 権限を設定
            if (mounted) {
              setState(() {
                _canEditTodaySchedule = canEditTodaySchedule;
              });
              print('TodaySchedule: 初期権限設定完了 - 編集可能: $_canEditTodaySchedule');
            }

            // 全メンバーがグループデータを読み込み（リアルタイム同期のため）
            print('TodaySchedule: グループデータを読み込みます（全メンバー）');

            // 本日のスケジュールを読み込み（時間ラベルも含む）
            final todayScheduleData =
                await GroupDataSyncService.getGroupTodaySchedule(group.id);
            if (todayScheduleData != null) {
              final labels = todayScheduleData['labels'] as List<dynamic>?;
              final contents =
                  todayScheduleData['contents'] as Map<String, dynamic>?;
              if (labels != null && labels.isNotEmpty) {
                print('TodaySchedule: グループから本日のスケジュールを読み込み: $labels');
                setState(() {
                  _scheduleLabels = List<String>.from(labels);
                  if (contents != null) {
                    _scheduleContents = Map<String, String>.from(contents);
                  }
                });
                _initScheduleControllers();
                print(
                  'TodaySchedule: グループデータ読み込み完了 - ラベル数: ${_scheduleLabels.length}',
                );
              } else {
                print('TodaySchedule: グループデータのラベルが空です - ローカルデータを読み込みます');
                await _loadSchedules();
              }
            } else {
              print('TodaySchedule: グループデータが存在しません - ローカルデータを読み込みます');
              await _loadSchedules();
            }
          } else {
            print('TodaySchedule: グループ設定が取得できませんでした - ローカルデータを読み込みます');
            await _loadSchedules();
          }
        } else {
          print('TodaySchedule: ユーザーが認証されていません - ローカルデータを読み込みます');
          await _loadSchedules();
        }
      } else {
        print('TodaySchedule: グループが存在しません - ローカルデータを読み込みます');
        await _loadSchedules();
      }
      print('TodaySchedule: グループデータ初期読み込み完了');
    } catch (e) {
      print('TodaySchedule: グループデータ初期読み込みエラー: $e');
      // エラー時はローカルデータを読み込み
      await _loadSchedules();
    }

    // 初期化完了
    _isInitializing = false;
    print('TodaySchedule: 初期化完了 - 初期化中フラグをリセット: $_isInitializing');
  }

  // 編集権限をチェック
  Future<void> _checkEditPermissions() async {
    try {
      final groupProvider = context.read<GroupProvider>();

      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          final userRole = group.getMemberRole(currentUser.uid);
          print('TodaySchedule: 権限チェック - ユーザーID: ${currentUser.uid}');
          print('TodaySchedule: 権限チェック - ユーザーロール: $userRole');
          print(
            'TodaySchedule: 権限チェック - グループメンバー: ${group.members.map((m) => '${m.uid}:${m.role}').toList()}',
          );
          print('TodaySchedule: 権限チェック - 現在のユーザーID: ${currentUser.uid}');

          // GroupFirestoreServiceから直接グループ設定を取得
          final groupSettings = await GroupFirestoreService.getGroupSettings(
            group.id,
          );

          if (groupSettings != null) {
            // 本日のスケジュールの編集権限をチェック（todayScheduleを使用）
            final canEditTodaySchedule = groupSettings.canEditDataType(
              'todaySchedule',
              userRole ?? GroupRole.member,
            );

            print(
              'TodaySchedule: 権限チェック - グループ設定: ${groupSettings.dataPermissions}',
            );
            print(
              'TodaySchedule: 権限チェック - todayScheduleのアクセスレベル: ${groupSettings.getPermissionForDataType('todaySchedule')}',
            );
            print('TodaySchedule: 権限チェック - 編集権限結果: $canEditTodaySchedule');

            // 現在の権限と比較して変更があったかチェック
            final hasChanged = _canEditTodaySchedule != canEditTodaySchedule;

            if (hasChanged) {
              print(
                'TodaySchedule: 権限変更を検知 - todaySchedule: $_canEditTodaySchedule -> $canEditTodaySchedule',
              );
            }

            if (mounted) {
              setState(() {
                _canEditTodaySchedule = canEditTodaySchedule;
              });

              print('TodaySchedule: 権限更新完了 - 編集可能: $_canEditTodaySchedule');
            }
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

  // 権限変更をリアルタイムで監視
  void _setupPermissionListener() {
    try {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;

        print('TodaySchedule: 権限変更リスナーを設定開始');

        // グループ設定の変更を監視
        _permissionSubscription = FirebaseFirestore.instance
            .collection('groups')
            .doc(group.id)
            .collection('settings')
            .doc('dataPermissions')
            .snapshots()
            .listen((snapshot) {
              if (!mounted) return;

              print('TodaySchedule: グループ設定変更を検知');
              print('TodaySchedule: 新しい設定データ: ${snapshot.data()}');

              // 権限を再チェック
              _checkEditPermissions();
            });

        print('TodaySchedule: 権限変更リスナー設定完了');
      }
    } catch (e) {
      print('TodaySchedule: 権限変更リスナー設定エラー: $e');
    }
  }

  // Firestore同期用setter
  void setScheduleFromFirestore(Map<String, dynamic> schedule) {
    if (mounted) {
      setState(() {
        _scheduleLabels = List<String>.from(schedule['labels'] ?? []);
        _scheduleContents = Map<String, String>.from(
          schedule['contents'] ?? {},
        );
        _initScheduleControllers();
      });
    }
  }

  void setTimeLabelsFromFirestore(List<String> labels) {
    if (mounted) {
      setState(() {
        _scheduleLabels = labels;
        _initScheduleControllers();
      });
    }
  }

  // 範囲選択の追加・削除時に保存
  void _onTapLabel(int i) {
    // 権限がない場合は範囲選択を許可しない
    if (!_canEditTodaySchedule) {
      print('TodaySchedule: 時間ラベル編集権限がないため、範囲選択を許可しません');
      return;
    }

    if (mounted) {
      setState(() {
        final removeIndex = _arrowRanges.indexWhere(
          (r) => r.isStart(i) || r.isEnd(i),
        );
        if (removeIndex != -1) {
          _arrowRanges.removeAt(removeIndex);
          _saveArrowRanges();
          return;
        }
        if (_tempStartIndex == null) {
          _tempStartIndex = i;
        } else if (_tempStartIndex != i) {
          _arrowRanges.add(_ArrowRange(_tempStartIndex!, i));
          _tempStartIndex = null;
          _saveArrowRanges();
        } else {
          _tempStartIndex = null;
        }
      });
    }
  }

  // ローカルデータを更新するメソッド
  Future<void> _updateLocalData(
    List<String> labels,
    Map<String, String> contents,
  ) async {
    try {
      await UserSettingsFirestoreService.saveSetting(
        'todaySchedule_labels',
        labels,
      );
      await UserSettingsFirestoreService.saveSetting(
        'todaySchedule_contents',
        contents,
      );
      print('TodaySchedule: ローカルデータを更新しました');
    } catch (e) {
      print('TodaySchedule: ローカルデータ更新エラー: $e');
    }
  }

  // 古いtime_labelsデータを削除するメソッド
  Future<void> _cleanupOldTimeLabelsData() async {
    try {
      final oldLabels = await UserSettingsFirestoreService.getSetting(
        'timeLabels',
      );
      final oldContents = await UserSettingsFirestoreService.getSetting(
        'timeLabelsContents',
      );

      if (oldLabels != null && oldLabels.isNotEmpty) {
        print('TodaySchedule: 古いtime_labelsデータを削除します: $oldLabels');
        await UserSettingsFirestoreService.deleteSetting('timeLabels');
        await UserSettingsFirestoreService.deleteSetting('timeLabelsContents');
        print('TodaySchedule: 古いtime_labelsデータの削除が完了しました。');
      }

      // グループの古いtime_labelsデータも削除
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isNotEmpty) {
        final group = groupProvider.groups.first;
        print('TodaySchedule: グループの古いtime_labelsデータを削除します');

        try {
          // グループのtime_labelsデータを削除
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(group.id)
              .collection('sharedData')
              .doc('time_labels')
              .delete();
          print('TodaySchedule: グループの古いtime_labelsデータの削除が完了しました');
        } catch (e) {
          print('TodaySchedule: グループの古いtime_labelsデータの削除中にエラーが発生しました: $e');
        }
      }
    } catch (e) {
      print('TodaySchedule: 古いtime_labelsデータの削除中にエラーが発生しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('TodaySchedule: build実行 - ラベル数: ${_scheduleLabels.length}');
    print('TodaySchedule: ラベル内容: $_scheduleLabels');
    print(
      'TodaySchedule: 最初のラベルが空か: ${_scheduleLabels.isNotEmpty ? _scheduleLabels.first.isEmpty : "ラベルなし"}',
    );

    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
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
                    Row(
                      children: [
                        Text(
                          '本日のスケジュール',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Provider.of<ThemeSettings>(
                              context,
                            ).fontColor1,
                          ),
                        ),
                        if (groupProvider.groups.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(left: 12),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade400),
                            ),
                            child: Icon(
                              Icons.groups,
                              size: 18,
                              color: Colors.blue.shade700,
                            ),
                          ),

                        // 権限状態表示を追加
                        Spacer(),
                        // 時間ラベル編集ボタンを追加
                        IconButton(
                          icon: Icon(
                            Icons.schedule,
                            color: _canEditTodaySchedule
                                ? Provider.of<ThemeSettings>(context).iconColor
                                : Provider.of<ThemeSettings>(
                                    context,
                                  ).iconColor.withOpacity(0.3),
                          ),
                          onPressed: _canEditTodaySchedule
                              ? _openLabelEdit
                              : null,
                          tooltip: _canEditTodaySchedule
                              ? '時間ラベルを編集'
                              : '時間ラベル編集権限がありません',
                        ),
                      ],
                    ),
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
                      Column(children: _buildScheduleLabelWidgets()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ▼▼▼ UI改善版: 昔のスタイルに戻したレイアウト ▼▼▼
  List<Widget> _buildScheduleLabelWidgets() {
    print(
      'TodaySchedule: _buildScheduleLabelWidgets開始 - ラベル数: ${_scheduleLabels.length}',
    );
    print('TodaySchedule: 表示するラベル: $_scheduleLabels');

    List<Widget> widgets = [];
    for (int i = 0; i < _scheduleLabels.length; i++) {
      print('TodaySchedule: ラベル $i を処理中: ${_scheduleLabels[i]}');
      final inAnyRange = _arrowRanges.any((r) => r.inRange(i));
      final isRangeStart = _arrowRanges.any((r) => r.isStart(i));
      final isRangeEnd = _arrowRanges.any((r) => r.isEnd(i));
      final isBetweenRange = _arrowRanges.any((r) => r.contains(i));

      // タイムライン用アイコン
      final themeButtonColor = Provider.of<ThemeSettings>(context).buttonColor;
      Widget timelineIcon;
      if (isRangeStart) {
        timelineIcon = Icon(
          Icons.fiber_manual_record,
          color: themeButtonColor,
          size: 18,
        ); // ●
      } else if (isRangeEnd) {
        timelineIcon = Icon(
          Icons.arrow_drop_down,
          color: themeButtonColor,
          size: 24,
        ); // ▼
      } else if (isBetweenRange) {
        timelineIcon = Container(
          width: 2,
          height: 24,
          color: themeButtonColor.withOpacity(0.7),
        ); // │
      } else {
        timelineIcon = SizedBox(width: 18, height: 24); // 空白
      }

      widgets.add(
        Container(
          decoration: BoxDecoration(
            color: (isRangeStart || isRangeEnd || isBetweenRange)
                ? Provider.of<ThemeSettings>(
                    context,
                  ).buttonColor.withOpacity(0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          margin: EdgeInsets.symmetric(vertical: isBetweenRange ? 1 : 4),
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 4),
              // 時間ラベル（左）
              GestureDetector(
                onTap: _canEditTodaySchedule ? () => _onTapLabel(i) : null,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_tempStartIndex == i || isRangeStart || isRangeEnd)
                        ? Provider.of<ThemeSettings>(
                            context,
                          ).buttonColor.withOpacity(0.18)
                        : inAnyRange
                        ? Colors.transparent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _scheduleLabels[i],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: inAnyRange
                          ? Colors.grey.shade700
                          : Provider.of<ThemeSettings>(context).fontColor1,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6),

              // コンテンツフィールド（右）
              if (!isBetweenRange)
                Expanded(
                  child: _canEditTodaySchedule
                      ? Container(
                          height: 50, // 適度な高さに調整
                          child: TextField(
                            controller:
                                _scheduleControllers[_scheduleLabels[i]],
                            keyboardType: TextInputType.text,
                            enableSuggestions: true,
                            autocorrect: true,
                            enabled: true,
                            textInputAction:
                                TextInputAction.done, // Enterキーの動作を明示
                            onChanged: (v) {
                              print(
                                'TodaySchedule: スケジュール内容変更検知 - ラベル: ${_scheduleLabels[i]}, 内容: $v',
                              );
                              setState(() {
                                _scheduleContents[_scheduleLabels[i]] = v;
                              });
                              print('TodaySchedule: スケジュール内容保存開始');
                              _saveSchedules();
                            },
                            onTap: () {
                              print(
                                'TodaySchedule: テキストフィールドタップ - ラベル: ${_scheduleLabels[i]}',
                              );
                              _isEditing = true;
                            },
                            onEditingComplete: () {
                              print(
                                'TodaySchedule: テキストフィールド編集完了 - ラベル: ${_scheduleLabels[i]}',
                              );
                              // 編集完了時（フォーカスが外れた時）のみ入力中フラグをリセット
                              _isEditing = false;
                            },
                            onSubmitted: (v) {
                              print(
                                'TodaySchedule: テキストフィールド送信 - ラベル: ${_scheduleLabels[i]}, 内容: $v',
                              );
                              // Enterキーで確定した場合はフォーカスを外す
                              FocusScope.of(context).unfocus();
                              _isEditing = false;
                            },
                            maxLines: 1,
                            style: TextStyle(
                              fontSize:
                                  18 *
                                  Provider.of<ThemeSettings>(
                                    context,
                                  ).fontSizeScale,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              filled: false,
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Provider.of<ThemeSettings>(
                                    context,
                                  ).buttonColor,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 10,
                              ),
                              isDense: true, // 高さを固定
                            ),
                          ),
                        )
                      : Container(
                          height: 50, // TextFieldと同じ高さに固定
                          padding: EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _scheduleContents[_scheduleLabels[i]] ?? '',
                              style: TextStyle(
                                fontSize:
                                    18 *
                                    Provider.of<ThemeSettings>(
                                      context,
                                    ).fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: Provider.of<ThemeSettings>(
                                  context,
                                ).fontColor1,
                              ),
                            ),
                          ),
                        ),
                ),
              if (isBetweenRange) Expanded(child: SizedBox.shrink()),

              // タイムライン（右端）
              SizedBox(width: 4),
              SizedBox(width: 18, child: Center(child: timelineIcon)),
            ],
          ),
        ),
      );
    }

    print(
      'TodaySchedule: _buildScheduleLabelWidgets完了 - 作成したウィジェット数: ${widgets.length}',
    );
    return widgets;
  }

  // ▲▲▲
}
