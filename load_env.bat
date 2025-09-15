@echo off
REM 環境変数読み込みスクリプト（Windows用）

echo app_config.envから環境変数を読み込み中...

REM app_config.envファイルが存在するかチェック
if not exist "app_config.env" (
    echo エラー: app_config.envファイルが見つかりません
    exit /b 1
)

REM app_config.envファイルから環境変数を読み込み
for /f "usebackq tokens=1,2 delims==" %%a in ("app_config.env") do (
    if not "%%a"=="" if not "%%a:~0,1%"=="#" (
        set "%%a=%%b"
        echo 環境変数設定: %%a=%%b
    )
)

echo 環境変数の読み込みが完了しました
echo.
echo 使用可能な環境変数:
echo - FIREBASE_PROJECT_ID
echo - FIREBASE_WEB_API_KEY
echo - GOOGLE_SIGN_IN_CLIENT_ID
echo - ADMOB_ANDROID_APP_ID
echo - KEYSTORE_PASSWORD
echo - KEY_PASSWORD
echo.
echo ビルドを実行するには以下のコマンドを使用してください:
echo flutter build apk --release
echo または
echo flutter build appbundle --release
