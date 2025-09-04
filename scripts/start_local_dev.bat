@echo off
echo ローストプラス - ローカル開発サーバー起動
echo =====================================

echo.
echo 1. Flutter Web アプリをビルド中...
call flutter build web --release --base-href /

if %ERRORLEVEL% neq 0 (
    echo エラー: Flutter ビルドに失敗しました
    pause
    exit /b 1
)

echo.
echo 2. Firebase Hosting ローカルサーバーを起動中...
echo ブラウザで http://localhost:5000 を開いてください
echo または https://roastplus-site.web.app でアクセス可能です
echo.

call firebase serve --only hosting --port 5000 --project roastplus-app

pause
