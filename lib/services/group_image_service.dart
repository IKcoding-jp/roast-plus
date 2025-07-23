import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class GroupImageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  // アイコンサイズの定数
  static const int ICON_SIZE = 200; // 200x200ピクセル
  static const int ICON_QUALITY = 85; // JPEG品質

  /// 画像をアイコンサイズにリサイズ・クロップ
  static Uint8List _resizeImageForIcon(Uint8List imageBytes) {
    print('GroupImageService: 画像リサイズ開始');

    // 画像をデコード
    final img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      print('GroupImageService: 画像デコードに失敗');
      return imageBytes;
    }

    print(
      'GroupImageService: 元画像サイズ: ${originalImage.width}x${originalImage.height}',
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

    print(
      'GroupImageService: クロップ後サイズ: ${croppedImage.width}x${croppedImage.height}',
    );

    // アイコンサイズにリサイズ
    final img.Image resizedImage = img.copyResize(
      croppedImage,
      width: ICON_SIZE,
      height: ICON_SIZE,
      interpolation: img.Interpolation.cubic,
    );

    print(
      'GroupImageService: リサイズ後サイズ: ${resizedImage.width}x${resizedImage.height}',
    );

    // JPEGとしてエンコード
    final Uint8List resizedBytes = Uint8List.fromList(
      img.encodeJpg(resizedImage, quality: ICON_QUALITY),
    );

    print('GroupImageService: リサイズ完了、サイズ: ${resizedBytes.length} bytes');
    return resizedBytes;
  }

  /// 権限をチェックしてリクエスト
  static Future<bool> _checkAndRequestPermission(Permission permission) async {
    print('GroupImageService: 権限チェック開始: $permission');

    PermissionStatus status = await permission.status;
    print('GroupImageService: 現在の権限状態: $status');

    if (status.isGranted) {
      print('GroupImageService: 権限は既に許可されています');
      return true;
    }

    if (status.isDenied) {
      print('GroupImageService: 権限をリクエストします');
      status = await permission.request();
      print('GroupImageService: 権限リクエスト結果: $status');
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      print('GroupImageService: 権限が永続的に拒否されています');
      return false;
    }

    return false;
  }

  /// 画像を選択してアップロード
  static Future<String?> pickAndUploadImage(String groupId) async {
    try {
      print('GroupImageService: 画像選択を開始');

      // ストレージ権限をチェック
      bool hasPermission = await _checkAndRequestPermission(Permission.storage);
      if (!hasPermission) {
        print('GroupImageService: ストレージ権限がありません');
        return null;
      }

      // 画像を選択（高解像度で取得）
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048, // より高解像度で取得
        maxHeight: 2048,
        imageQuality: 100, // 最高品質で取得
      );

      print('GroupImageService: 画像選択結果: ${image?.path}');

      if (image == null) {
        print('GroupImageService: 画像が選択されませんでした');
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
      print('GroupImageService: リサイズされた画像をアップロード開始');
      final result = await uploadImage(resizedFile, groupId);
      print('GroupImageService: アップロード結果: $result');

      // 一時ファイルを削除
      await resizedFile.delete();

      return result;
    } catch (e) {
      print('画像選択・アップロードエラー: $e');
      return null;
    }
  }

  /// カメラで撮影してアップロード
  static Future<String?> takeAndUploadImage(String groupId) async {
    try {
      print('GroupImageService: カメラ撮影を開始');

      // カメラ権限をチェック
      bool hasPermission = await _checkAndRequestPermission(Permission.camera);
      if (!hasPermission) {
        print('GroupImageService: カメラ権限がありません');
        return null;
      }

      // カメラで撮影（高解像度で取得）
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048, // より高解像度で取得
        maxHeight: 2048,
        imageQuality: 100, // 最高品質で取得
      );

      print('GroupImageService: カメラ撮影結果: ${image?.path}');

      if (image == null) {
        print('GroupImageService: 写真が撮影されませんでした');
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
      print('GroupImageService: リサイズされた写真をアップロード開始');
      final result = await uploadImage(resizedFile, groupId);
      print('GroupImageService: アップロード結果: $result');

      // 一時ファイルを削除
      await resizedFile.delete();

      return result;
    } catch (e) {
      print('カメラ撮影・アップロードエラー: $e');
      return null;
    }
  }

  /// 画像をFirebase Storageにアップロード
  static Future<String?> uploadImage(File imageFile, String groupId) async {
    try {
      print('GroupImageService: Firebase Storageアップロード開始');
      print('GroupImageService: ファイルパス: ${imageFile.path}');
      print('GroupImageService: ファイル存在: ${await imageFile.exists()}');

      // ファイル名を生成
      final String fileName =
          'group_${groupId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('GroupImageService: ファイル名: $fileName');

      final Reference storageRef = _storage.ref().child(
        'group_images/$fileName',
      );
      print('GroupImageService: Storage参照作成完了');

      // アップロード
      print('GroupImageService: アップロードタスク開始');
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      print('GroupImageService: アップロード完了');

      // ダウンロードURLを取得
      print('GroupImageService: ダウンロードURL取得開始');
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('GroupImageService: ダウンロードURL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('画像アップロードエラー: $e');
      return null;
    }
  }

  /// 古い画像を削除
  static Future<void> deleteOldImage(String? imageUrl) async {
    if (imageUrl == null) return;

    try {
      print('GroupImageService: 古い画像削除開始: $imageUrl');
      final Reference storageRef = _storage.refFromURL(imageUrl);
      await storageRef.delete();
      print('GroupImageService: 古い画像削除完了');
    } catch (e) {
      print('古い画像削除エラー: $e');
    }
  }

  /// 画像データをFirebase Storageにアップロード
  static Future<String?> uploadImageData(
    String groupId,
    Uint8List imageData,
  ) async {
    try {
      print('GroupImageService: 画像データアップロード開始');
      print('GroupImageService: データサイズ: ${imageData.length} bytes');

      // ファイル名を生成
      final String fileName =
          'group_${groupId}_${DateTime.now().millisecondsSinceEpoch}.png';
      print('GroupImageService: ファイル名: $fileName');

      final Reference storageRef = _storage.ref().child(
        'group_images/$fileName',
      );
      print('GroupImageService: Storage参照作成完了');

      // アップロード
      print('GroupImageService: アップロードタスク開始');
      final UploadTask uploadTask = storageRef.putData(imageData);
      final TaskSnapshot snapshot = await uploadTask;
      print('GroupImageService: アップロード完了');

      // ダウンロードURLを取得
      print('GroupImageService: ダウンロードURL取得開始');
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('GroupImageService: ダウンロードURL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('画像データアップロードエラー: $e');
      return null;
    }
  }
}
