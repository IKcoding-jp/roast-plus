# ローストプラス - ローカル開発サーバー起動スクリプト
Write-Host "ローストプラス - ローカル開発サーバー起動" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

Write-Host ""
Write-Host "1. Flutter Web アプリをビルド中..." -ForegroundColor Yellow
flutter build web --release --base-href /

if ($LASTEXITCODE -ne 0) {
    Write-Host "エラー: Flutter ビルドに失敗しました" -ForegroundColor Red
    Read-Host "Enterキーを押して終了"
    exit 1
}

Write-Host ""
Write-Host "2. Firebase Hosting ローカルサーバーを起動中..." -ForegroundColor Yellow
Write-Host "ブラウザで http://localhost:5000 を開いてください" -ForegroundColor Cyan
Write-Host "または https://roastplus-site.web.app でアクセス可能です" -ForegroundColor Cyan
Write-Host ""

firebase serve --only hosting --port 5000 --project roastplus-app

Read-Host "Enterキーを押して終了"
