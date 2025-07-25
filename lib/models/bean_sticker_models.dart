import 'package:flutter/material.dart';
import '../services/app_settings_firestore_service.dart';
import 'group_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_settings_firestore_service.dart';

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
      'stickerColor': stickerColor.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BeanSticker.fromMap(Map<String, dynamic> map) {
    return BeanSticker(
      id: map['id'] ?? '',
      beanName: map['beanName'] ?? '',
      stickerColor: Color(map['stickerColor'] ?? Colors.grey.value),
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
  static const String _storageKey = 'bean_stickers';

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
    print('Loading bean stickers...');
    _isLoading = true;
    // notifyListeners();

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
          final jsonString = await UserSettingsFirestoreService.getSetting(
            _storageKey,
          );
          if (jsonString != null) {
            jsonList = jsonString;
          }
        } catch (e) {
          print('Firebaseからの豆ステッカー読み込みエラー: $e');
        }
      }

      if (jsonList != null) {
        _beanStickers = jsonList
            .map((json) => BeanSticker.fromMap(json))
            .toList();
        // 作成日順にソート（新しい順）
        _beanStickers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        print('Loaded ${_beanStickers.length} bean stickers');
      } else {
        _beanStickers = [];
        print('No bean stickers found in storage');
      }
    } catch (e) {
      print('Error loading bean stickers: $e');
      _beanStickers = [];
    } finally {
      _isLoading = false;
      print('Loading completed');
      // notifyListeners()を無効化
    }
  }

  Future<void> _saveToStorage() async {
    try {
      print('Converting bean stickers to JSON...');
      final jsonString = _beanStickers.map((bs) => bs.toMap()).toList();
      print('Saving to Firebase with key: $_storageKey');
      await UserSettingsFirestoreService.saveSetting(_storageKey, jsonString);
      print('Successfully saved to Firebase');
    } catch (e) {
      print('Error saving bean stickers: $e');
      rethrow;
    }
  }

  Future<void> saveBeanStickers({String? groupId}) async {
    try {
      if (groupId != null && groupId.isNotEmpty) {
        // グループ用API
        await AppSettingsFirestoreService.saveGroupBeanStickers(
          groupId,
          _beanStickers,
        );
      } else {
        // 個人用API
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
      print('Error saving bean stickers: $e');
      rethrow;
    }
  }

  Future<void> addBeanSticker(BeanSticker beanSticker) async {
    try {
      print('Adding bean sticker:  ${beanSticker.beanName}');

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
        print('Updating existing bean sticker at index: $existingIndex');
        _beanStickers[existingIndex] = newBeanSticker.copyWith(
          id: _beanStickers[existingIndex].id,
          createdAt: _beanStickers[existingIndex].createdAt,
        );
      } else {
        print('Adding new bean sticker');
        _beanStickers.insert(0, newBeanSticker);
      }

      print('Saving to storage...');
      await _saveToStorage();
      print('Bean sticker operation completed successfully');

      // Firestoreにも保存（グループ未参加時のみ）
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final groupProvider = GroupProvider();
        if (groupProvider.groups.isEmpty) {
          await AppSettingsFirestoreService.saveBeanStickers(_beanStickers);
        }
      }
      // notifyListeners()を無効化
    } catch (e) {
      print('Error adding bean sticker: $e');
      rethrow;
    }
  }

  Future<void> updateBeanSticker(BeanSticker beanSticker) async {
    try {
      final index = _beanStickers.indexWhere(
        (sticker) => sticker.id == beanSticker.id,
      );
      if (index != -1) {
        _beanStickers[index] = beanSticker.copyWith(updatedAt: DateTime.now());
        await _saveToStorage();
        // Firestoreにも保存（グループ未参加時のみ）
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final groupProvider = GroupProvider();
          if (groupProvider.groups.isEmpty) {
            await AppSettingsFirestoreService.saveBeanStickers(_beanStickers);
          }
        }
        // notifyListeners()を無効化
      }
    } catch (e) {
      print('Error updating bean sticker: $e');
      rethrow;
    }
  }

  Future<void> deleteBeanSticker(String id) async {
    try {
      _beanStickers.removeWhere((sticker) => sticker.id == id);
      await _saveToStorage();
      // Firestoreにも保存（グループ未参加時のみ）
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final groupProvider = GroupProvider();
        if (groupProvider.groups.isEmpty) {
          await AppSettingsFirestoreService.saveBeanStickers(_beanStickers);
        }
      }
      // notifyListeners()を無効化
    } catch (e) {
      print('Error deleting bean sticker: $e');
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
      // notifyListeners()を無効化
    } catch (e) {
      print('Error deleting bean sticker by name: $e');
      rethrow;
    }
  }
}
