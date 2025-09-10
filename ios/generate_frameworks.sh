#!/bin/bash

# Flutterフレームワーク生成スクリプト
# iOSビルド用のネイティブフレームワーク（Flutter.framework / Flutter-ObjC.framework）を生成

set -e

echo "Flutterフレームワーク生成を開始します..."

# 作業ディレクトリを設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRAMEWORK_OUTPUT_DIR="$PROJECT_ROOT/build/ios/frameworks"

# 出力ディレクトリを作成
mkdir -p "$FRAMEWORK_OUTPUT_DIR"

echo "出力ディレクトリ: $FRAMEWORK_OUTPUT_DIR"

# Flutterのキャッシュを更新
echo "Flutterのキャッシュを更新中..."
flutter precache --ios

# iOSプロジェクトディレクトリに移動
cd "$SCRIPT_DIR"

# Podfileが存在するか確認
if [ ! -f "Podfile" ]; then
    echo "エラー: Podfileが見つかりません"
    exit 1
fi

# CocoaPodsの依存関係をインストール
echo "CocoaPodsの依存関係をインストール中..."
pod install --repo-update

# Flutter.frameworkを生成
echo "Flutter.frameworkを生成中..."
flutter build ios --debug --no-codesign

# フレームワークの場所を確認
FLUTTER_FRAMEWORK_SOURCE="$PROJECT_ROOT/build/ios/Debug-iphoneos/Flutter.framework"
if [ -d "$FLUTTER_FRAMEWORK_SOURCE" ]; then
    echo "Flutter.frameworkをコピー中..."
    cp -R "$FLUTTER_FRAMEWORK_SOURCE" "$FRAMEWORK_OUTPUT_DIR/"
else
    echo "警告: Flutter.frameworkが見つかりません: $FLUTTER_FRAMEWORK_SOURCE"
fi

# Flutter-ObjC.frameworkを生成
echo "Flutter-ObjC.frameworkを生成中..."
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Debug \
    -sdk iphoneos \
    -derivedDataPath build \
    -archivePath build/Runner.xcarchive \
    archive \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# アーカイブからフレームワークを抽出
ARCHIVE_FRAMEWORKS_DIR="build/Runner.xcarchive/Products/Applications/Runner.app/Frameworks"
if [ -d "$ARCHIVE_FRAMEWORKS_DIR" ]; then
    echo "アーカイブからフレームワークを抽出中..."
    cp -R "$ARCHIVE_FRAMEWORKS_DIR"/* "$FRAMEWORK_OUTPUT_DIR/"
else
    echo "警告: アーカイブ内にフレームワークディレクトリが見つかりません: $ARCHIVE_FRAMEWORKS_DIR"
fi

# 生成されたフレームワークの内容を確認
echo "生成されたフレームワークの内容:"
if [ -d "$FRAMEWORK_OUTPUT_DIR" ]; then
    ls -la "$FRAMEWORK_OUTPUT_DIR"
    
    # フレームワークの詳細情報を表示
    for framework in "$FRAMEWORK_OUTPUT_DIR"/*.framework; do
        if [ -d "$framework" ]; then
            echo "フレームワーク: $(basename "$framework")"
            echo "  サイズ: $(du -sh "$framework" | cut -f1)"
            echo "  内容:"
            ls -la "$framework"
        fi
    done
else
    echo "フレームワークディレクトリが存在しません"
fi

echo "Flutterフレームワークの生成が完了しました"
echo "出力場所: $FRAMEWORK_OUTPUT_DIR"
