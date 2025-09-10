import 'dart:io';
import 'dart:developer' as developer;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class GroupImageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  // アイコンサイズの定数
  static const int iconSize = 200; // 200x200ピクセル
  static const int iconQuality = 85; // JPEG品質

  /// 画像をアイコンサイズにリサイズ・クロップ
  static Uint8List _resizeImageForIcon(Uint8List imageBytes) {
    developer.log('画像リサイズ開始', name: 'GroupImageService');

    // 画像をデコード
    final img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      developer.log('画像デコードに失敗', name: 'GroupImageService', level: 900);
      return imageBytes;
    }

    developer.log(
      '元画像サイズ: ${originalImage.width}x${originalImage.height}',
      name: 'GroupImageService',
    );

    // 正方形にクロップ（中央部分を取得）
    img.Image croppedImage;
    if (originalImage.width > originalImage.height) {
      // 横長の画像の場合
      final int cropSize = originalImage.height;
      final int startX = (originalImage.width - cropSize) ~/ 2;
      croppedImage = img.copyCrop(
        originalImage,
        x: startX,
        y: 0,
        width: cropSize,
        height: cropSize,
      );
    } else if (originalImage.height > originalImage.width) {
      // 縦長の画像の場合
      final int cropSize = originalImage.width;
      final int startY = (originalImage.height - cropSize) ~/ 2;
      croppedImage = img.copyCrop(
        originalImage,
        x: 0,
        y: startY,
        width: cropSize,
        height: cropSize,
      );
    } else {
      // 既に正方形の場合
      croppedImage = originalImage;
    }

    developer.log(
      'クロップ後サイズ: ${croppedImage.width}x${croppedImage.height}',
      name: 'GroupImageService',
    );

    // アイコンサイズにリサイズ
    final img.Image resizedImage = img.copyResize(
      croppedImage,
      width: iconSize,
      height: iconSize,
      interpolation: img.Interpolation.cubic,
    );

    developer.log(
      'リサイズ後サイズ: ${resizedImage.width}x${resizedImage.height}',
      name: 'GroupImageService',
    );

    // JPEGとしてエンコード
    final Uint8List resizedBytes = Uint8List.fromList(
      img.encodeJpg(resizedImage, quality: iconQuality),
    );

    developer.log(
      'リサイズ完了、サイズ: ${resizedBytes.length} bytes',
      name: 'GroupImageService',
    );
    return resizedBytes;
  }

  /// 権限をチェックしてリクエスト
  static Future<bool> _checkAndRequestPermission(Permission permission) async {
    // Web版では権限チェックをスキップ
    if (kIsWeb) {
      developer.log('Web版では権限チェックをスキップ', name: 'GroupImageService');
      return true;
    }

    developer.log('権限チェック開始: $permission', name: 'GroupImageService');

    PermissionStatus status = await permission.status;
    developer.log('現在の権限状態: $status', name: 'GroupImageService');

    if (status.isGranted) {
      developer.log('権限は既に許可されています', name: 'GroupImageService');
      return true;
    }

    if (status.isDenied) {
      developer.log('権限をリクエストします', name: 'GroupImageService');
      status = await permission.request();
      developer.log('権限リクエスト結果: $status', name: 'GroupImageService');
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      developer.log('権限が永続的に拒否されています', name: 'GroupImageService', level: 900);
      return false;
    }

    return false;
  }

  /// 画像を選択してアップロード
  static Future<String?> pickAndUploadImage(String groupId) async {
    try {
      developer.log('画像選択を開始', name: 'GroupImageService');

      // ストレージ権限をチェック
      bool hasPermission = await _checkAndRequestPermission(Permission.storage);
      if (!hasPermission) {
        developer.log('ストレージ権限がありません', name: 'GroupImageService', level: 900);
        return null;
      }

      // 画像を選択（高解像度で取得）
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048, // より高解像度で取得
        maxHeight: 2048,
        imageQuality: 100, // 最高品質で取得
      );

      developer.log('画像選択結果: ${image?.path}', name: 'GroupImageService');

      if (image == null) {
        developer.log('画像が選択されませんでした', name: 'GroupImageService');
        return null;
      }

      // 画像を読み込んでリサイズ
      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final Uint8List resizedBytes = _resizeImageForIcon(imageBytes);

      // リサイズされた画像を一時ファイルとして保存
      final File resizedFile = File(
        '${imageFile.parent.path}/resized_${imageFile.uri.pathSegments.last}',
      );
      await resizedFile.writeAsBytes(resizedBytes);

      // アップロード
      developer.log('リサイズされた画像をアップロード開始', name: 'GroupImageService');
      final result = await uploadImage(resizedFile, groupId);
      developer.log('アップロード結果: $result', name: 'GroupImageService');

      // 一時ファイルを削除
      await resizedFile.delete();

      return result;
    } catch (e, s) {
      developer.log(
        '画像選択・アップロードエラー',
        name: 'GroupImageService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      return null;
    }
  }

  /// カメラで撮影してアップロード
  static Future<String?> takeAndUploadImage(String groupId) async {
    try {
      developer.log('カメラ撮影を開始', name: 'GroupImageService');

      // カメラ権限をチェック
      bool hasPermission = await _checkAndRequestPermission(Permission.camera);
      if (!hasPermission) {
        developer.log('カメラ権限がありません', name: 'GroupImageService', level: 900);
        return null;
      }

      // カメラで撮影（高解像度で取得）
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048, // より高解像度で取得
        maxHeight: 2048,
        imageQuality: 100, // 最高品質で取得
      );

      developer.log('カメラ撮影結果: ${image?.path}', name: 'GroupImageService');

      if (image == null) {
        developer.log('写真が撮影されませんでした', name: 'GroupImageService');
        return null;
      }

      // 画像を読み込んでリサイズ
      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final Uint8List resizedBytes = _resizeImageForIcon(imageBytes);

      // リサイズされた画像を一時ファイルとして保存
      final File resizedFile = File(
        '${imageFile.parent.path}/resized_${imageFile.uri.pathSegments.last}',
      );
      await resizedFile.writeAsBytes(resizedBytes);

      // アップロード
      developer.log('リサイズされた写真をアップロード開始', name: 'GroupImageService');
      final result = await uploadImage(resizedFile, groupId);
      developer.log('アップロード結果: $result', name: 'GroupImageService');

      // 一時ファイルを削除
      await resizedFile.delete();

      return result;
    } catch (e, s) {
      developer.log(
        'カメラ撮影・アップロードエラー',
        name: 'GroupImageService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      return null;
    }
  }

  /// 画像をFirebase Storageにアップロード
  static Future<String?> uploadImage(File imageFile, String groupId) async {
    try {
      developer.log('Firebase Storageアップロード開始', name: 'GroupImageService');
      developer.log('ファイルパス: ${imageFile.path}', name: 'GroupImageService');
      developer.log(
        'ファイル存在: ${await imageFile.exists()}',
        name: 'GroupImageService',
      );

      // ファイル名を生成
      final String fileName =
          'group_${groupId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      developer.log('ファイル名: $fileName', name: 'GroupImageService');

      final Reference storageRef = _storage.ref().child(
        'group_images/$fileName',
      );
      developer.log('Storage参照作成完了', name: 'GroupImageService');

      // アップロード
      developer.log('アップロードタスク開始', name: 'GroupImageService');
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      developer.log('アップロード完了', name: 'GroupImageService');

      // ダウンロードURLを取得
      developer.log('ダウンロードURL取得開始', name: 'GroupImageService');
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      developer.log('ダウンロードURL: $downloadUrl', name: 'GroupImageService');
      return downloadUrl;
    } catch (e, s) {
      developer.log(
        '画像アップロードエラー',
        name: 'GroupImageService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      return null;
    }
  }

  /// 古い画像を削除
  static Future<void> deleteOldImage(String? imageUrl) async {
    if (imageUrl == null) return;

    try {
      developer.log('古い画像削除開始: $imageUrl', name: 'GroupImageService');
      final Reference storageRef = _storage.refFromURL(imageUrl);
      await storageRef.delete();
      developer.log('古い画像削除完了', name: 'GroupImageService');
    } catch (e, s) {
      developer.log(
        '古い画像削除エラー',
        name: 'GroupImageService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
    }
  }

  /// 画像データをFirebase Storageにアップロード
  static Future<String?> uploadImageData(
    String groupId,
    Uint8List imageData,
  ) async {
    try {
      developer.log('画像データアップロード開始', name: 'GroupImageService');
      developer.log(
        'データサイズ: ${imageData.length} bytes',
        name: 'GroupImageService',
      );

      // ファイル名を生成
      final String fileName =
          'group_${groupId}_${DateTime.now().millisecondsSinceEpoch}.png';
      developer.log('ファイル名: $fileName', name: 'GroupImageService');

      final Reference storageRef = _storage.ref().child(
        'group_images/$fileName',
      );
      developer.log('Storage参照作成完了', name: 'GroupImageService');

      // アップロード
      developer.log('アップロードタスク開始', name: 'GroupImageService');
      final UploadTask uploadTask = storageRef.putData(imageData);
      final TaskSnapshot snapshot = await uploadTask;
      developer.log('アップロード完了', name: 'GroupImageService');

      // ダウンロードURLを取得
      developer.log('ダウンロードURL取得開始', name: 'GroupImageService');
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      developer.log('ダウンロードURL: $downloadUrl', name: 'GroupImageService');
      return downloadUrl;
    } catch (e, s) {
      developer.log(
        '画像データアップロードエラー',
        name: 'GroupImageService',
        error: e,
        stackTrace: s,
        level: 1000,
      );
      return null;
    }
  }
}
