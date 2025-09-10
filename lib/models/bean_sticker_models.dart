import 'package:flutter/material.dart';
import '../services/app_settings_firestore_service.dart';
import 'group_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class BeanSticker {
  final String id;
  final String beanName;
  final Color stickerColor;
  final DateTime createdAt;
  final DateTime updatedAt;

  BeanSticker({
    required this.id,
    required this.beanName,
    required this.stickerColor,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'beanName': beanName,
      'stickerColor': stickerColor.toARGB32(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BeanSticker.fromMap(Map<String, dynamic> map) {
    return BeanSticker(
      id: map['id'] ?? '',
      beanName: map['beanName'] ?? '',
      stickerColor: Color(map['stickerColor'] ?? Colors.grey.toARGB32()),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  BeanSticker copyWith({
    String? id,
    String? beanName,
    Color? stickerColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BeanSticker(
      id: id ?? this.id,
      beanName: beanName ?? this.beanName,
      stickerColor: stickerColor ?? this.stickerColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BeanStickerProvider extends ChangeNotifier {
  List<BeanSticker> _beanStickers = [];
  bool _isLoading = false;

  List<BeanSticker> get beanStickers => _beanStickers;
  bool get isLoading => _isLoading;

  // 豆の名前から色を取得
  Color? getStickerColor(String beanName) {
    final sticker = _beanStickers.firstWhere(
      (sticker) =>
          sticker.beanName.toLowerCase().trim() ==
          beanName.toLowerCase().trim(),
      orElse: () => BeanSticker(
        id: '',
        beanName: '',
        stickerColor: Colors.grey,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return sticker.beanName.isNotEmpty ? sticker.stickerColor : null;
  }

  // 豆の名前からBeanStickerを取得
  BeanSticker? getBeanSticker(String beanName) {
    try {
      return _beanStickers.firstWhere(
        (sticker) =>
            sticker.beanName.toLowerCase().trim() ==
            beanName.toLowerCase().trim(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> loadBeanStickers({String? groupId}) async {
    developer.log(
      'Loading bean stickers... groupId: $groupId',
      name: 'BeanStickerProvider',
    );
    _isLoading = true;
    notifyListeners();

    try {
      List<dynamic>? jsonList;
      if (groupId != null && groupId.isNotEmpty) {
        // グループ用API
        jsonList = await AppSettingsFirestoreService.getGroupBeanStickers(
          groupId,
        );
      } else {
        // 個人用API
        try {
          developer.log(
            'AppSettingsFirestoreServiceから豆ステッカーを読み込み中...',
            name: 'BeanStickerProvider',
          );
          jsonList = await AppSettingsFirestoreService.getBeanStickers();
          developer.log(
            'AppSettingsFirestoreServiceからの結果: $jsonList',
            name: 'BeanStickerProvider',
          );
        } catch (e) {
          developer.log(
            'Firebaseからの豆ステッカー読み込みエラー: $e',
            name: 'BeanStickerProvider',
          );
        }
      }

      if (jsonList != null) {
        developer.log(
          'jsonList is not null, length: ${jsonList.length}',
          name: 'BeanStickerProvider',
        );
        _beanStickers = jsonList
            .map((json) => BeanSticker.fromMap(json))
            .toList();
        // 作成日順にソート（新しい順）
        _beanStickers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        developer.log(
          'Loaded ${_beanStickers.length} bean stickers',
          name: 'BeanStickerProvider',
        );
      } else {
        _beanStickers = [];
        developer.log(
          'No bean stickers found in storage',
          name: 'BeanStickerProvider',
        );
      }
    } catch (e) {
      developer.log(
        'Error loading bean stickers: $e',
        name: 'BeanStickerProvider',
      );
      _beanStickers = [];
    } finally {
      _isLoading = false;
      developer.log('Loading completed', name: 'BeanStickerProvider');
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      developer.log(
        'Converting bean stickers to JSON...',
        name: 'BeanStickerProvider',
      );
      developer.log(
        'Saving to Firebase with AppSettingsFirestoreService',
        name: 'BeanStickerProvider',
      );
      await AppSettingsFirestoreService.saveBeanStickers(_beanStickers);
      developer.log(
        'Successfully saved to Firebase',
        name: 'BeanStickerProvider',
      );
    } catch (e) {
      developer.log(
        'Error saving bean stickers: $e',
        name: 'BeanStickerProvider',
      );
      rethrow;
    }
  }

  Future<void> saveBeanStickers({String? groupId}) async {
    try {
      if (groupId != null && groupId.isNotEmpty) {
        // グループ用API
        developer.log('グループ用APIで保存: $groupId', name: 'BeanStickerProvider');
        await AppSettingsFirestoreService.saveGroupBeanStickers(
          groupId,
          _beanStickers,
        );
      } else {
        // 個人用API
        developer.log('個人用APIで保存', name: 'BeanStickerProvider');
        await _saveToStorage();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final groupProvider = GroupProvider();
          if (groupProvider.groups.isEmpty) {
            await AppSettingsFirestoreService.saveBeanStickers(_beanStickers);
          }
        }
      }
    } catch (e) {
      developer.log(
        'Error saving bean stickers: $e',
        name: 'BeanStickerProvider',
      );
      rethrow;
    }
  }

  Future<void> addBeanSticker(
    BeanSticker beanSticker, {
    String? groupId,
  }) async {
    try {
      developer.log(
        'Adding bean sticker:  ${beanSticker.beanName}',
        name: 'BeanStickerProvider',
      );

      final newBeanSticker = beanSticker.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 同じ豆の名前が既に存在する場合は更新
      final existingIndex = _beanStickers.indexWhere(
        (sticker) =>
            sticker.beanName.toLowerCase().trim() ==
            newBeanSticker.beanName.toLowerCase().trim(),
      );

      if (existingIndex != -1) {
        developer.log(
          'Updating existing bean sticker at index: $existingIndex',
          name: 'BeanStickerProvider',
        );
        _beanStickers[existingIndex] = newBeanSticker.copyWith(
          id: _beanStickers[existingIndex].id,
          createdAt: _beanStickers[existingIndex].createdAt,
        );
      } else {
        developer.log('Adding new bean sticker', name: 'BeanStickerProvider');
        _beanStickers.insert(0, newBeanSticker);
      }

      // グループモードかどうかで保存方法を分岐
      if (groupId != null && groupId.isNotEmpty) {
        developer.log('グループモードで保存: $groupId', name: 'BeanStickerProvider');
        await AppSettingsFirestoreService.saveGroupBeanStickers(
          groupId,
          _beanStickers,
        );
      } else {
        developer.log('個人モードで保存', name: 'BeanStickerProvider');
        await _saveToStorage();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final groupProvider = GroupProvider();
          if (groupProvider.groups.isEmpty) {
            await AppSettingsFirestoreService.saveBeanStickers(_beanStickers);
          }
        }
      }

      developer.log(
        'Bean sticker operation completed successfully',
        name: 'BeanStickerProvider',
      );
      notifyListeners();
    } catch (e) {
      developer.log(
        'Error adding bean sticker: $e',
        name: 'BeanStickerProvider',
      );
      rethrow;
    }
  }

  Future<void> updateBeanSticker(
    BeanSticker beanSticker, {
    String? groupId,
  }) async {
    try {
      final index = _beanStickers.indexWhere(
        (sticker) => sticker.id == beanSticker.id,
      );
      if (index != -1) {
        _beanStickers[index] = beanSticker.copyWith(updatedAt: DateTime.now());

        // グループモードかどうかで保存方法を分岐
        if (groupId != null && groupId.isNotEmpty) {
          await AppSettingsFirestoreService.saveGroupBeanStickers(
            groupId,
            _beanStickers,
          );
        } else {
          await _saveToStorage();
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final groupProvider = GroupProvider();
            if (groupProvider.groups.isEmpty) {
              await AppSettingsFirestoreService.saveBeanStickers(_beanStickers);
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        'Error updating bean sticker: $e',
        name: 'BeanStickerProvider',
      );
      rethrow;
    }
  }

  Future<void> deleteBeanSticker(String id, {String? groupId}) async {
    try {
      _beanStickers.removeWhere((sticker) => sticker.id == id);

      // グループモードかどうかで保存方法を分岐
      if (groupId != null && groupId.isNotEmpty) {
        await AppSettingsFirestoreService.saveGroupBeanStickers(
          groupId,
          _beanStickers,
        );
      } else {
        await _saveToStorage();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final groupProvider = GroupProvider();
          if (groupProvider.groups.isEmpty) {
            await AppSettingsFirestoreService.saveBeanStickers(_beanStickers);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      developer.log(
        'Error deleting bean sticker: $e',
        name: 'BeanStickerProvider',
      );
      rethrow;
    }
  }

  // 豆の名前で削除
  Future<void> deleteBeanStickerByName(String beanName) async {
    try {
      _beanStickers.removeWhere(
        (sticker) =>
            sticker.beanName.toLowerCase().trim() ==
            beanName.toLowerCase().trim(),
      );
      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      developer.log(
        'Error deleting bean sticker by name: $e',
        name: 'BeanStickerProvider',
      );
      rethrow;
    }
  }
}
