@echo off
chcp 65001 >nul

REM Firebase Firestoreセキュリティルールデプロイスクリプト（Windows版）
REM このスクリプトは、firestore.rulesファイルをFirebaseプロジェクトにデプロイします

echo 🔥 Firebase Firestoreセキュリティルールをデプロイ中...

REM Firebase CLIがインストールされているかチェック
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Firebase CLIがインストールされていません。
    echo 以下のコマンドでインストールしてください：
    echo npm install -g firebase-tools
    pause
    exit /b 1
)

REM firestore.rulesファイルが存在するかチェック
if not exist "firestore.rules" (
    echo ❌ firestore.rulesファイルが見つかりません。
    pause
    exit /b 1
)

REM Firebaseプロジェクトにログイン
echo 🔐 Firebaseにログイン中...
firebase login

REM セキュリティルールをデプロイ
echo 📤 セキュリティルールをデプロイ中...
firebase deploy --only firestore:rules

if %errorlevel% equ 0 (
    echo ✅ セキュリティルールのデプロイが完了しました！
    echo 🔒 データベースが保護されました。
) else (
    echo ❌ セキュリティルールのデプロイに失敗しました。
    pause
    exit /b 1
)

pause
