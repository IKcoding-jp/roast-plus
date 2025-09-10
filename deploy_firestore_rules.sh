#!/bin/bash

# Firebase Firestoreセキュリティルールデプロイスクリプト
# このスクリプトは、firestore.rulesファイルをFirebaseプロジェクトにデプロイします

echo "🔥 Firebase Firestoreセキュリティルールをデプロイ中..."

# Firebase CLIがインストールされているかチェック
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLIがインストールされていません。"
    echo "以下のコマンドでインストールしてください："
    echo "npm install -g firebase-tools"
    exit 1
fi

# firestore.rulesファイルが存在するかチェック
if [ ! -f "firestore.rules" ]; then
    echo "❌ firestore.rulesファイルが見つかりません。"
    exit 1
fi

# Firebaseプロジェクトにログイン
echo "🔐 Firebaseにログイン中..."
firebase login

# セキュリティルールをデプロイ
echo "📤 セキュリティルールをデプロイ中..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ セキュリティルールのデプロイが完了しました！"
    echo "🔒 データベースが保護されました。"
else
    echo "❌ セキュリティルールのデプロイに失敗しました。"
    exit 1
fi
