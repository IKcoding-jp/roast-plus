#!/bin/bash
# 環境変数読み込みスクリプト（Linux/macOS用）

echo "config.envから環境変数を読み込み中..."

# config.envファイルが存在するかチェック
if [ ! -f "config.env" ]; then
    echo "エラー: config.envファイルが見つかりません"
    exit 1
fi

# config.envファイルから環境変数を読み込み
export $(grep -v '^#' config.env | grep -v '^$' | xargs)

echo "環境変数の読み込みが完了しました"
echo ""
echo "使用可能な環境変数:"
echo "- FIREBASE_PROJECT_ID"
echo "- FIREBASE_WEB_API_KEY"
echo "- GOOGLE_SIGN_IN_CLIENT_ID"
echo "- ADMOB_ANDROID_APP_ID"
echo "- KEYSTORE_PASSWORD"
echo "- KEY_PASSWORD"
echo ""
echo "ビルドを実行するには以下のコマンドを使用してください:"
echo "flutter build apk --release"
echo "または"
echo "flutter build appbundle --release"
