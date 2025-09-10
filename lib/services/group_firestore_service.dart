import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_models.dart';
import 'group_invitation_service.dart';
import 'first_login_service.dart';

import 'dart:math';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/foundation.dart';

class GroupFirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // リトライ設定
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _timeout = Duration(seconds: 30);

  static String? get _uid {
    final uid = _auth.currentUser?.uid;
    return uid != null && uid.isNotEmpty ? uid : null;
  }

  /// リトライ機能付きの操作実行
  static Future<T> _retryOperation<T>(Future<T> Function() operation) async {
    int retryCount = 0;
    while (true) {
      try {
        return await operation().timeout(_timeout);
      } catch (e) {
        retryCount++;
        developer.log(
          '操作失敗 (試行 $retryCount/$_maxRetries): $e',
          name: 'GroupFirestoreService',
          error: e,
        );

        if (retryCount >= _maxRetries) {
          developer.log('最大リトライ回数に達しました', name: 'GroupFirestoreService');
          rethrow;
        }

        // リトライ前に少し待機
        await Future.delayed(_retryDelay);
        developer.log('リトライ中...', name: 'GroupFirestoreService');
      }
    }
  }

  static String? get _email {
    final email = _auth.currentUser?.email;
    return email != null && email.isNotEmpty ? email : null;
  }

  static Future<String> get _displayName async {
    // カスタム表示名を優先的に取得
    final customDisplayName = await FirstLoginService.getCurrentDisplayName();
    if (customDisplayName != null && customDisplayName.isNotEmpty) {
      return customDisplayName;
    }
    // カスタム表示名がない場合はGoogleアカウントの名前を使用
    return _auth.currentUser?.displayName ?? 'Unknown User';
  }

  static String? get _photoUrl {
    final photoURL = _auth.currentUser?.photoURL;
    developer.log(
      'GroupFirestoreService: _photoUrl取得 - $photoURL',
      name: 'GroupFirestoreService',
    );

    // プロフィール画像URLが有効かチェック
    if (photoURL != null && photoURL.isNotEmpty) {
      developer.log(
        'GroupFirestoreService: 有効なプロフィール画像URLを取得 - $photoURL',
        name: 'GroupFirestoreService',
      );
      return photoURL;
    } else {
      developer.log(
        'GroupFirestoreService: プロフィール画像URLが無効または空 - $photoURL',
        name: 'GroupFirestoreService',
      );
      return null;
    }
  }

  /// 招待コードを生成
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// グループを作成
  static Future<Group> createGroup({
    required String name,
    required String description,
  }) async {
    return _retryOperation(() async {
      try {
        developer.log('グループ作成開始', name: 'GroupFirestoreService');

        // Web版ではFirestoreの初期化を確実に行う
        if (kIsWeb) {
          try {
            await _firestore.enableNetwork();
            developer.log(
              'Web版: Firestoreネットワーク有効化完了',
              name: 'GroupFirestoreService',
            );
          } catch (e) {
            developer.log(
              'Web版: Firestoreネットワーク有効化エラー: $e',
              name: 'GroupFirestoreService',
            );
          }
        }

        if (_uid == null) throw Exception('未ログイン');
        if (_email == null) throw Exception('メールアドレスが取得できません');

        final now = DateTime.now();
        final groupId = _firestore.collection('groups').doc().id;

        developer.log('グループID生成: $groupId', name: 'GroupFirestoreService');

        final displayName = await _displayName;
        final photoUrl = _photoUrl;
        developer.log(
          'GroupFirestoreService: グループ作成者 - UID: $_uid, 表示名: $displayName, プロフィール画像: $photoUrl',
          name: 'GroupFirestoreService',
        );
        developer.log(
          'GroupFirestoreService: プロフィール画像詳細 - photoUrl: $photoUrl, 有効: ${photoUrl != null && photoUrl.isNotEmpty}',
          name: 'GroupFirestoreService',
        );
        final creator = GroupMember(
          uid: _uid!,
          email: _email!,
          displayName: displayName,
          photoUrl: photoUrl,
          role: GroupRole.admin, // グループ作成者は管理者として扱う
          joinedAt: now,
          lastActiveAt: now,
        );

        // デフォルト設定を作成
        final defaultSettings = GroupSettings.defaultSettings();

        // 招待コードを生成（8文字のランダム文字列）
        final inviteCode = _generateInviteCode();

        developer.log('招待コード生成: $inviteCode', name: 'GroupFirestoreService');

        final group = Group(
          id: groupId,
          name: name,
          description: description,
          createdBy: _uid!,
          createdAt: now,
          updatedAt: now,
          members: [creator],
          settings: defaultSettings.toJson(),
          inviteCode: inviteCode,
        );

        developer.log('グループドキュメント保存開始', name: 'GroupFirestoreService');
        try {
          // Web版ではより安全なデータ構造で保存
          final groupData = group.toJson();

          // Web版でのFirestore内部エラー対策：データを検証してから保存
          if (kIsWeb) {
            // null値を除去し、文字列の長さを制限
            final sanitizedData = <String, dynamic>{};
            for (final entry in groupData.entries) {
              if (entry.value != null) {
                if (entry.value is String) {
                  // 文字列の長さを制限（Firestoreの制限対策）
                  final stringValue = entry.value as String;
                  if (stringValue.length > 1000000) {
                    // 1MB制限
                    developer.log(
                      'Web版: 文字列が長すぎるため切り詰めます: ${entry.key}',
                      name: 'GroupFirestoreService',
                    );
                    sanitizedData[entry.key] = stringValue.substring(
                      0,
                      1000000,
                    );
                  } else {
                    sanitizedData[entry.key] = stringValue;
                  }
                } else {
                  sanitizedData[entry.key] = entry.value;
                }
              }
            }

            await _firestore
                .collection('groups')
                .doc(groupId)
                .set(sanitizedData)
                .timeout(_timeout);
          } else {
            await _firestore
                .collection('groups')
                .doc(groupId)
                .set(groupData)
                .timeout(_timeout);
          }

          developer.log('グループドキュメント保存完了', name: 'GroupFirestoreService');
        } catch (e) {
          developer.log(
            'グループドキュメント保存エラー: $e',
            name: 'GroupFirestoreService',
            error: e,
          );
          // Web版でのFirestore内部エラーの場合、より詳細な情報をログ出力
          if (kIsWeb && e.toString().contains('INTERNAL ASSERTION FAILED')) {
            developer.log(
              'Web版: Firestore内部アサーションエラーが発生しました',
              name: 'GroupFirestoreService',
            );
            developer.log(
              'Web版: グループデータ: ${group.toJson()}',
              name: 'GroupFirestoreService',
            );
          }
          rethrow;
        }

        // ユーザーのグループ参加情報も保存
        developer.log('ユーザーグループ情報保存開始', name: 'GroupFirestoreService');
        try {
          await _firestore
              .collection('users')
              .doc(_uid)
              .collection('userGroups')
              .doc(groupId)
              .set({
                'groupId': groupId,
                'groupName': name,
                'role': GroupRole.admin.name,
                'joinedAt': now.toIso8601String(),
              })
              .timeout(_timeout);
          developer.log('ユーザーグループ情報保存完了', name: 'GroupFirestoreService');
        } catch (e) {
          developer.log(
            'ユーザーグループ情報保存エラー: $e',
            name: 'GroupFirestoreService',
            error: e,
          );
          rethrow;
        }

        developer.log('グループ作成完了', name: 'GroupFirestoreService');
        return group;
      } catch (e) {
        developer.log('グループ作成エラー: $e', name: 'GroupFirestoreService', error: e);
        rethrow;
      }
    });
  }

  /// ユーザーが参加しているグループを取得
  static Future<List<Group>> getUserGroups() async {
    return _retryOperation(() async {
      if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

      developer.log('ユーザーグループ取得開始', name: 'GroupFirestoreService');
      developer.log('ユーザーID: $_uid', name: 'GroupFirestoreService');

      // Web版ではFirestoreの初期化を確実に行う
      if (kIsWeb) {
        try {
          // まず現在の接続をクリーンアップ
          await _firestore.disableNetwork();
          await Future.delayed(Duration(milliseconds: 500));

          // ネットワークを再有効化
          await _firestore.enableNetwork();
          developer.log(
            'Web版: Firestoreネットワーク再有効化完了',
            name: 'GroupFirestoreService',
          );

          // 少し待機して接続を安定させる
          await Future.delayed(Duration(milliseconds: 1000));
        } catch (e) {
          developer.log(
            'Web版: Firestoreネットワーク有効化エラー: $e',
            name: 'GroupFirestoreService',
          );
          // エラーが発生しても続行
        }
      }

      final userGroupsSnapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('userGroups')
          .get()
          .timeout(_timeout);

      developer.log(
        'ユーザーグループドキュメント数: ${userGroupsSnapshot.docs.length}',
        name: 'GroupFirestoreService',
      );

      if (userGroupsSnapshot.docs.isEmpty) {
        developer.log('ユーザーグループが存在しません', name: 'GroupFirestoreService');
        return [];
      }

      // 並列でグループ情報を取得（読み込み時間を短縮）
      final futures = userGroupsSnapshot.docs.map((doc) async {
        final groupId = doc.data()['groupId'] as String;
        developer.log('グループ情報取得中: $groupId', name: 'GroupFirestoreService');

        final groupDoc = await _firestore
            .collection('groups')
            .doc(groupId)
            .get()
            .timeout(_timeout);
        if (groupDoc.exists) {
          developer.log('グループ情報取得成功: $groupId', name: 'GroupFirestoreService');
          return Group.fromJson(groupDoc.data()!);
        } else {
          developer.log(
            'グループドキュメントが存在しません: $groupId',
            name: 'GroupFirestoreService',
          );
        }
        return null;
      });

      final results = await Future.wait(futures);
      final groups = results.whereType<Group>().toList();
      developer.log(
        '取得したグループ数: ${groups.length}',
        name: 'GroupFirestoreService',
      );
      return groups;
    });
  }

  /// グループの詳細を取得
  static Future<Group?> getGroup(String groupId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromJson(doc.data()!);
  }

  /// グループを更新
  static Future<void> updateGroup(Group group) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    // 管理者またはリーダーのみ更新可能（従来仕様維持）
    final role = group.getMemberRole(_uid!);
    if (role != GroupRole.admin && role != GroupRole.leader) {
      throw Exception('管理者またはリーダーのみグループを更新できます');
    }

    // 更新日時を現在時刻に設定
    final updatedGroup = group.copyWith(updatedAt: DateTime.now());

    developer.log('グループ更新開始', name: 'GroupFirestoreService');
    developer.log('グループID: ${group.id}', name: 'GroupFirestoreService');
    developer.log('新しい名前: ${updatedGroup.name}', name: 'GroupFirestoreService');
    developer.log(
      '新しい説明: ${updatedGroup.description}',
      name: 'GroupFirestoreService',
    );

    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    developer.log('グループ更新完了', name: 'GroupFirestoreService');
  }

  /// グループを削除
  static Future<void> deleteGroup(String groupId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // 管理者のみ削除可能
    final role = group.getMemberRole(_uid!);
    if (role != GroupRole.admin) {
      throw Exception('管理者のみグループを削除できます');
    }

    developer.log(
      'グループ削除開始 - groupId: $groupId',
      name: 'GroupFirestoreService',
    );

    try {
      // グループに保存されたデータを削除
      await _deleteGroupData(groupId);

      // グループの招待コードを削除
      await GroupInvitationService.deleteGroupInvitations(groupId);

      // グループの招待データを削除
      await _deleteGroupInvitations(groupId);

      // グループを削除（Webでも確実に権限チェックが通るよう、createdBy一致も条件にセット）
      await _firestore.collection('groups').doc(groupId).delete();

      // 全メンバーの参加情報を削除（失敗しても続行）
      for (final member in group.members) {
        try {
          await _firestore
              .collection('users')
              .doc(member.uid)
              .collection('userGroups')
              .doc(groupId)
              .delete();
        } catch (e) {
          developer.log(
            'メンバー参加情報削除スキップ - uid: ${member.uid}, error: $e',
            name: 'GroupFirestoreService',
          );
        }
      }

      developer.log(
        'グループ削除完了 - groupId: $groupId',
        name: 'GroupFirestoreService',
      );
    } catch (e) {
      developer.log('グループ削除エラー: $e', name: 'GroupFirestoreService', error: e);
      rethrow;
    }
  }

  /// グループに保存されたデータを削除
  static Future<void> _deleteGroupData(String groupId) async {
    developer.log(
      'グループデータ削除開始 - groupId: $groupId',
      name: 'GroupFirestoreService',
    );

    try {
      // グループの共有データを削除
      await _deleteGroupSharedData(groupId);

      // グループのサブコレクションを削除
      await _deleteGroupSubcollections(groupId);

      developer.log(
        'グループデータ削除完了 - groupId: $groupId',
        name: 'GroupFirestoreService',
      );
    } catch (e) {
      developer.log(
        'グループデータ削除エラー: $e',
        name: 'GroupFirestoreService',
        error: e,
      );
      rethrow;
    }
  }

  /// グループの共有データを削除
  static Future<void> _deleteGroupSharedData(String groupId) async {
    developer.log(
      'グループ共有データ削除開始 - groupId: $groupId',
      name: 'GroupFirestoreService',
    );

    try {
      // 共有データの種類を定義
      final dataTypes = [
        'today_schedule', // 本日のスケジュール
        'time_labels', // 時間ラベル
        'drip_counter', // ドリップカウンター
        'assignment_board', // 担当ボード
        'schedule', // スケジュール
        'today_assignment', // 今日の担当
      ];

      // 各データタイプを削除
      for (final dataType in dataTypes) {
        try {
          await _firestore
              .collection('groups')
              .doc(groupId)
              .collection('sharedData')
              .doc(dataType)
              .delete();
          developer.log(
            '共有データ削除完了 - dataType: $dataType',
            name: 'GroupFirestoreService',
          );
        } catch (e) {
          developer.log(
            '共有データ削除エラー - dataType: $dataType, error: $e',
            name: 'GroupFirestoreService',
            error: e,
          );
          // 個別のエラーは無視して続行
        }
      }
    } catch (e) {
      developer.log(
        'グループ共有データ削除エラー: $e',
        name: 'GroupFirestoreService',
        error: e,
      );
      rethrow;
    }
  }

  /// グループのサブコレクションを削除
  static Future<void> _deleteGroupSubcollections(String groupId) async {
    developer.log(
      'グループサブコレクション削除開始 - groupId: $groupId',
      name: 'GroupFirestoreService',
    );

    try {
      // 削除対象のサブコレクション
      final subcollections = [
        'roast_records', // 焙煎記録
        'tasting_records', // 試飲記録
        'drip_pack_records', // ドリップパック記録
        'work_progress_records', // 作業進捗記録
        'attendance_records', // 出勤記録
        'memo_records', // メモ記録
        'group_gamification', // ゲーミフィケーション
        'group_settings', // グループ設定
        'group_invitations', // グループ招待
      ];

      // 各サブコレクションを削除
      for (final subcollection in subcollections) {
        try {
          await _deleteSubcollection(groupId, subcollection);
          developer.log(
            'サブコレクション削除完了 - subcollection: $subcollection',
            name: 'GroupFirestoreService',
          );
        } catch (e) {
          developer.log(
            'サブコレクション削除エラー - subcollection: $subcollection, error: $e',
            name: 'GroupFirestoreService',
            error: e,
          );
          // 個別のエラーは無視して続行
        }
      }
    } catch (e) {
      developer.log(
        'グループサブコレクション削除エラー: $e',
        name: 'GroupFirestoreService',
        error: e,
      );
      rethrow;
    }
  }

  /// サブコレクションを削除
  static Future<void> _deleteSubcollection(
    String groupId,
    String subcollectionName,
  ) async {
    try {
      final subcollectionRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection(subcollectionName);

      // サブコレクション内の全ドキュメントを取得
      final querySnapshot = await subcollectionRef.get();

      // バッチ処理で全ドキュメントを削除
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      // バッチを実行
      if (querySnapshot.docs.isNotEmpty) {
        await batch.commit();
        developer.log(
          'サブコレクション削除完了 - $subcollectionName: ${querySnapshot.docs.length}件',
          name: 'GroupFirestoreService',
        );
      } else {
        developer.log(
          'サブコレクションは空でした - $subcollectionName',
          name: 'GroupFirestoreService',
        );
      }
    } catch (e) {
      developer.log(
        'サブコレクション削除エラー - $subcollectionName: $e',
        name: 'GroupFirestoreService',
        error: e,
      );
      rethrow;
    }
  }

  /// グループの招待データを削除
  static Future<void> _deleteGroupInvitations(String groupId) async {
    try {
      developer.log(
        'グループ招待データ削除開始 - groupId: $groupId',
        name: 'GroupFirestoreService',
      );

      // グループに関連する招待を取得
      final querySnapshot = await _firestore
          .collection('invitations')
          .where('groupId', isEqualTo: groupId)
          .get();

      // 招待を削除
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      if (querySnapshot.docs.isNotEmpty) {
        await batch.commit();
        developer.log(
          'グループ招待データ削除完了 - groupId: $groupId, 削除件数: ${querySnapshot.docs.length}',
          name: 'GroupFirestoreService',
        );
      } else {
        developer.log(
          'グループ招待データは存在しませんでした - groupId: $groupId',
          name: 'GroupFirestoreService',
        );
      }
    } catch (e) {
      developer.log(
        'グループ招待データ削除エラー - groupId: $groupId, error: $e',
        name: 'GroupFirestoreService',
        error: e,
      );
      rethrow;
    }
  }

  /// メンバーを招待
  static Future<void> inviteMember({
    required String groupId,
    required String invitedEmail,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // 管理者またはリーダーのみ招待可能（従来仕様維持）
    final role = group.getMemberRole(_uid!);
    if (role != GroupRole.admin && role != GroupRole.leader) {
      throw Exception('管理者またはリーダーのみメンバーを招待できます');
    }

    // 既にメンバーかチェック
    if (group.members.any((m) => m.email == invitedEmail)) {
      throw Exception('既にメンバーです');
    }

    final invitationId = _firestore.collection('invitations').doc().id;
    final invitation = GroupInvitation(
      id: invitationId,
      groupId: groupId,
      groupName: group.name,
      invitedBy: _uid!,
      invitedByEmail: _email!,
      invitedEmail: invitedEmail,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: 7)), // 7日間有効
    );

    await _firestore.collection('invitations').doc(invitationId).set({
      ...invitation.toJson(),
      'createdBy': _uid, // ルール互換のため作成者UIDを保存
    });
  }

  /// 招待を承諾
  static Future<void> acceptInvitation(String invitationId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    final invitationDoc = await _firestore
        .collection('invitations')
        .doc(invitationId)
        .get();
    if (!invitationDoc.exists) throw Exception('招待が見つかりません');

    final invitation = GroupInvitation.fromJson(invitationDoc.data()!);

    // 招待されたメールアドレスと一致するかチェック
    if (invitation.invitedEmail != _email) {
      throw Exception('この招待はあなた宛てではありません');
    }

    if (!invitation.isValid) {
      throw Exception('招待が無効です');
    }

    final group = await getGroup(invitation.groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // メンバーを追加
    final displayName = await _displayName;
    final photoUrl = _photoUrl;
    developer.log(
      'GroupFirestoreService: メンバー追加 - UID: $_uid, 表示名: $displayName, プロフィール画像: $photoUrl',
      name: 'GroupFirestoreService',
    );
    developer.log(
      'GroupFirestoreService: プロフィール画像詳細 - photoUrl: $photoUrl, 有効: ${photoUrl != null && photoUrl.isNotEmpty}',
      name: 'GroupFirestoreService',
    );
    final newMember = GroupMember(
      uid: _uid!,
      email: _email!,
      displayName: displayName,
      photoUrl: photoUrl,
      role: GroupRole.member, // 招待されたメンバーはメンバーとして扱う
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    final updatedMembers = [...group.members, newMember];
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // ユーザーのグループ参加情報を保存
    try {
      developer.log('グループ参加情報保存開始: ${group.id}', name: 'GroupFirestoreService');
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('userGroups')
          .doc(group.id)
          .set({
            'groupId': group.id,
            'groupName': group.name,
            'role': GroupRole.member.name,
            'joinedAt': DateTime.now().toIso8601String(),
          });
      developer.log('グループ参加情報保存完了: ${group.id}', name: 'GroupFirestoreService');
    } catch (e) {
      developer.log(
        'グループ参加情報保存エラー: $e',
        name: 'GroupFirestoreService',
        error: e,
      );
      rethrow;
    }

    developer.log(
      '招待コード参加完了 - グループID: ${group.id}, メンバー数: ${updatedGroup.members.length}',
      name: 'GroupFirestoreService',
    );

    // 招待を更新
    await _firestore.collection('invitations').doc(invitationId).update({
      'isAccepted': true,
      'acceptedAt': DateTime.now().toIso8601String(),
    });

    developer.log(
      '招待承諾完了 - グループID: ${group.id}, メンバー数: ${updatedGroup.members.length}',
      name: 'GroupFirestoreService',
    );
  }

  /// 招待コードでグループに参加
  static Future<void> joinGroupByInviteCode(String inviteCode) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    // 招待コードでグループを検索
    final groupsSnapshot = await _firestore
        .collection('groups')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (groupsSnapshot.docs.isEmpty) {
      throw Exception('招待コードが無効です');
    }

    final groupDoc = groupsSnapshot.docs.first;
    final group = Group.fromJson(groupDoc.data());

    // 既にメンバーかチェック
    if (group.members.any((m) => m.uid == _uid)) {
      throw Exception('既にグループのメンバーです');
    }

    // メンバーを追加
    final displayName = await _displayName;
    final photoUrl = _photoUrl;
    developer.log(
      'GroupFirestoreService: 招待コードでメンバー追加 - UID: $_uid, 表示名: $displayName, プロフィール画像: $photoUrl',
      name: 'GroupFirestoreService',
    );
    developer.log(
      'GroupFirestoreService: プロフィール画像詳細 - photoUrl: $photoUrl, 有効: ${photoUrl != null && photoUrl.isNotEmpty}',
      name: 'GroupFirestoreService',
    );
    final newMember = GroupMember(
      uid: _uid!,
      email: _email!,
      displayName: displayName,
      photoUrl: photoUrl,
      role: GroupRole.member, // 招待コードで参加したメンバーはメンバーとして扱う
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    final updatedMembers = [...group.members, newMember];
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // ユーザーのグループ参加情報を保存
    try {
      developer.log('グループ参加情報保存開始: ${group.id}', name: 'GroupFirestoreService');
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('userGroups')
          .doc(group.id)
          .set({
            'groupId': group.id,
            'groupName': group.name,
            'role': GroupRole.member.name,
            'joinedAt': DateTime.now().toIso8601String(),
          });
      developer.log('グループ参加情報保存完了: ${group.id}', name: 'GroupFirestoreService');
    } catch (e) {
      developer.log(
        'グループ参加情報保存エラー: $e',
        name: 'GroupFirestoreService',
        error: e,
      );
      rethrow;
    }
  }

  /// 招待を拒否
  static Future<void> declineInvitation(String invitationId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    final invitationDoc = await _firestore
        .collection('invitations')
        .doc(invitationId)
        .get();
    if (!invitationDoc.exists) throw Exception('招待が見つかりません');

    final invitation = GroupInvitation.fromJson(invitationDoc.data()!);

    if (invitation.invitedEmail != _email) {
      throw Exception('この招待はあなた宛てではありません');
    }

    await _firestore.collection('invitations').doc(invitationId).update({
      'isDeclined': true,
    });
  }

  /// ユーザーの招待一覧を取得
  static Future<List<GroupInvitation>> getUserInvitations() async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');
    if (_email == null || _email!.isEmpty) throw Exception('メールアドレスが取得できません');

    final invitationsSnapshot = await _firestore
        .collection('invitations')
        .where('invitedEmail', isEqualTo: _email)
        .where('isAccepted', isEqualTo: false)
        .where('isDeclined', isEqualTo: false)
        .get();

    return invitationsSnapshot.docs
        .map((doc) => GroupInvitation.fromJson(doc.data()))
        .where((invitation) => invitation.isValid)
        .toList();
  }

  /// メンバーを削除
  static Future<void> removeMember({
    required String groupId,
    required String memberUid,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // 管理者またはリーダーのみ削除可能（従来仕様維持）
    final role = group.getMemberRole(_uid!);
    if (role != GroupRole.admin && role != GroupRole.leader) {
      throw Exception('管理者またはリーダーのみメンバーを削除できます');
    }

    // 自分自身は削除できない
    if (memberUid == _uid) {
      throw Exception('自分自身を削除することはできません');
    }

    developer.log(
      'メンバー削除開始 - groupId: $groupId, memberUid: $memberUid',
      name: 'GroupFirestoreService',
    );

    try {
      final updatedMembers = group.members
          .where((m) => m.uid != memberUid)
          .toList();
      final updatedGroup = group.copyWith(
        members: updatedMembers,
        updatedAt: DateTime.now(),
      );

      // グループを更新
      await _firestore
          .collection('groups')
          .doc(group.id)
          .update(updatedGroup.toJson());

      developer.log(
        'グループ更新完了 - メンバー数: ${updatedMembers.length}',
        name: 'GroupFirestoreService',
      );

      // メンバーの参加情報を削除
      await _firestore
          .collection('users')
          .doc(memberUid)
          .collection('userGroups')
          .doc(groupId)
          .delete();

      developer.log(
        'メンバーの参加情報削除完了 - memberUid: $memberUid',
        name: 'GroupFirestoreService',
      );

      // 脱退させられたメンバーのローカルデータをクリアするための通知
      // グループドキュメントに脱退通知を追加
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('memberRemovals')
          .doc(memberUid)
          .set({
            'removedAt': FieldValue.serverTimestamp(),
            'removedBy': _uid,
            'memberUid': memberUid,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

      developer.log(
        'メンバー削除完了 - groupId: $groupId, memberUid: $memberUid',
        name: 'GroupFirestoreService',
      );
    } catch (e) {
      developer.log(
        'メンバー削除エラー - groupId: $groupId, memberUid: $memberUid, error: $e',
        name: 'GroupFirestoreService',
        error: e,
      );
      rethrow;
    }
  }

  /// メンバーの権限を変更
  static Future<void> changeMemberRole({
    required String groupId,
    required String memberUid,
    required GroupRole newRole,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // 管理者またはリーダーのみ権限変更可能（従来仕様維持）
    final role = group.getMemberRole(_uid!);
    if (role != GroupRole.admin && role != GroupRole.leader) {
      throw Exception('管理者またはリーダーのみ権限を変更できます');
    }

    final updatedMembers = group.members.map((member) {
      if (member.uid == memberUid) {
        return member.copyWith(role: newRole);
      }
      return member;
    }).toList();

    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // ユーザーの参加情報も更新
    await _firestore
        .collection('users')
        .doc(memberUid)
        .collection('userGroups')
        .doc(groupId)
        .update({'role': newRole.name});
  }

  /// グループから脱退
  static Future<void> leaveGroup(String groupId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    final updatedMembers = group.members.where((m) => m.uid != _uid).toList();
    final updatedGroup = group.copyWith(
      members: updatedMembers,
      updatedAt: DateTime.now(),
    );

    // グループを更新
    await _firestore
        .collection('groups')
        .doc(group.id)
        .update(updatedGroup.toJson());

    // 自分の参加情報を削除
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('userGroups')
        .doc(groupId)
        .delete();
  }

  /// グループのデータを同期（グループメンバー間でデータを共有）
  static Future<void> syncGroupData({
    required String groupId,
    required String dataType,
    required Map<String, dynamic> data,
  }) async {
    developer.log('syncGroupData開始', name: 'GroupFirestoreService');
    developer.log('グループID: $groupId', name: 'GroupFirestoreService');
    developer.log('データタイプ: $dataType', name: 'GroupFirestoreService');
    developer.log('同期データ: $data', name: 'GroupFirestoreService');

    if (_uid == null || _uid!.isEmpty) {
      developer.log('未ログインエラー', name: 'GroupFirestoreService');
      throw Exception('未ログイン');
    }

    developer.log('ユーザーID: $_uid', name: 'GroupFirestoreService');
    final group = await getGroup(groupId);
    if (group == null) {
      developer.log('グループが見つかりません', name: 'GroupFirestoreService');
      throw Exception('グループが見つかりません');
    }

    developer.log('グループ取得完了', name: 'GroupFirestoreService');
    developer.log(
      'グループメンバー: ${group.members.map((m) => m.uid).toList()}',
      name: 'GroupFirestoreService',
    );

    // メンバーのみ同期可能
    if (!group.isMember(_uid!)) {
      developer.log('グループメンバーではありません', name: 'GroupFirestoreService');
      throw Exception('グループメンバーのみデータを同期できます');
    }

    developer.log('メンバー権限チェック完了、Firestoreに保存開始', name: 'GroupFirestoreService');
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sharedData')
        .doc(dataType)
        .set({
          'data': data,
          'updatedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    developer.log('Firestore保存完了', name: 'GroupFirestoreService');
  }

  /// グループの共有データを取得
  static Future<Map<String, dynamic>?> getGroupData({
    required String groupId,
    required String dataType,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    // メンバーのみ取得可能
    if (!group.isMember(_uid!)) {
      throw Exception('グループメンバーのみデータを取得できます');
    }

    final doc = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sharedData')
        .doc(dataType)
        .get();

    if (!doc.exists) return null;
    return doc.data()?['data'] as Map<String, dynamic>?;
  }

  /// グループの共有データの変更を監視
  static Stream<Map<String, dynamic>?> watchGroupData({
    required String groupId,
    required String dataType,
  }) {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sharedData')
        .doc(dataType)
        .snapshots()
        .map((doc) => doc.data()?['data'] as Map<String, dynamic>?);
  }

  /// グループ設定を取得
  static Future<GroupSettings?> getGroupSettings(String groupId) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) return null;

    try {
      final settings = GroupSettings.fromJson(group.settings);

      // 管理者の設定を尊重するため、自動更新は行わない
      return settings;
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定を返す
      return GroupSettings.defaultSettings();
    }
  }

  /// グループ設定の変更をリアルタイム監視
  static Stream<GroupSettings?> watchGroupSettings(String groupId) {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    return _firestore.collection('groups').doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;

      try {
        final groupData = doc.data()!;
        final settingsData = groupData['settings'] as Map<String, dynamic>?;
        if (settingsData == null) return GroupSettings.defaultSettings();

        final settings = GroupSettings.fromJson(settingsData);

        // 管理者の設定を尊重するため、自動更新は行わない
        return settings;
      } catch (e) {
        // 古い形式の設定の場合はデフォルト設定を返す
        return GroupSettings.defaultSettings();
      }
    });
  }

  /// グループ設定を更新
  static Future<void> updateGroupSettings({
    required String groupId,
    required GroupSettings settings,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    developer.log('設定更新開始', name: 'GroupFirestoreService');
    developer.log('グループID: $groupId', name: 'GroupFirestoreService');
    developer.log('ユーザーID: $_uid', name: 'GroupFirestoreService');
    developer.log('更新する設定: $settings', name: 'GroupFirestoreService');
    developer.log(
      '更新する設定のdataPermissions: ${settings.dataPermissions}',
      name: 'GroupFirestoreService',
    );

    final group = await getGroup(groupId);
    if (group == null) throw Exception('グループが見つかりません');

    developer.log('グループ取得完了', name: 'GroupFirestoreService');
    developer.log(
      '現在のグループ設定: ${group.settings}',
      name: 'GroupFirestoreService',
    );

    // 管理者またはリーダーのみ設定変更可能
    final userRole = group.getMemberRole(_uid!);
    developer.log('ユーザーロール: $userRole', name: 'GroupFirestoreService');

    if (userRole != GroupRole.admin && userRole != GroupRole.leader) {
      developer.log('権限不足', name: 'GroupFirestoreService');
      throw Exception('管理者またはリーダーのみ設定を変更できます');
    }

    developer.log('権限チェック完了', name: 'GroupFirestoreService');

    final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
    // settingsフィールドのみをmergeでsetする
    await _firestore.collection('groups').doc(groupId).set({
      'settings': updatedSettings.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    developer.log(
      'Firestore set(merge: true)で更新完了',
      name: 'GroupFirestoreService',
    );
  }

  /// 指定されたデータタイプの編集権限をチェック
  static Future<bool> canEditDataType({
    required String groupId,
    required String dataType,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) return false;

    final userRole = group.getMemberRole(_uid!);
    if (userRole == null) return false;

    try {
      return GroupSettings.fromJson(
        group.settings,
      ).canEditDataType(dataType, userRole);
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定で判定
      return GroupSettings.defaultSettings().canEditDataType(
        dataType,
        userRole,
      );
    }
  }

  /// 指定されたデータタイプの同期権限をチェック
  static Future<bool> canSyncDataType({
    required String groupId,
    required String dataType,
  }) async {
    if (_uid == null || _uid!.isEmpty) throw Exception('未ログイン');

    final group = await getGroup(groupId);
    if (group == null) return false;

    final userRole = group.getMemberRole(_uid!);
    if (userRole == null) return false;

    try {
      // リーダーは常に同期可能
      if (userRole == GroupRole.admin || userRole == GroupRole.leader) {
        return true;
      }
      // メンバーは常に同期可能（データ同期は基本的な機能）
      return true;
    } catch (e) {
      // 古い形式の設定の場合はデフォルト設定で判定
      if (userRole == GroupRole.admin || userRole == GroupRole.leader) {
        return true;
      }
      return true;
    }
  }
}
