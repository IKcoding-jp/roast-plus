# Flutter iOSフレームワーク生成スクリプト (PowerShell版)
# iOSビルド用のネイティブフレームワーク（Flutter.framework / Flutter-ObjC.framework）を生成

param(
    [string]$Configuration = "Debug",
    [string]$OutputDir = "build/ios/frameworks"
)

Write-Host "Flutterフレームワーク生成を開始します..." -ForegroundColor Green

# 作業ディレクトリを設定
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$FrameworkOutputDir = Join-Path $ProjectRoot $OutputDir

# 出力ディレクトリを作成
if (!(Test-Path $FrameworkOutputDir)) {
    New-Item -ItemType Directory -Path $FrameworkOutputDir -Force | Out-Null
}

Write-Host "出力ディレクトリ: $FrameworkOutputDir" -ForegroundColor Yellow

# Flutterのキャッシュを更新
Write-Host "Flutterのキャッシュを更新中..." -ForegroundColor Cyan
flutter precache --ios

# iOSプロジェクトディレクトリに移動
$IOSDir = Join-Path $ProjectRoot "ios"
Set-Location $IOSDir

# Podfileが存在するか確認
if (!(Test-Path "Podfile")) {
    Write-Host "エラー: Podfileが見つかりません" -ForegroundColor Red
    exit 1
}

# CocoaPodsの依存関係をインストール
Write-Host "CocoaPodsの依存関係をインストール中..." -ForegroundColor Cyan
pod install --repo-update

# Flutter.frameworkを生成
Write-Host "Flutter.frameworkを生成中..." -ForegroundColor Cyan
flutter build ios --$Configuration --no-codesign

# フレームワークの場所を確認
$FlutterFrameworkSource = Join-Path $ProjectRoot "build/ios/$Configuration-iphoneos/Flutter.framework"
if (Test-Path $FlutterFrameworkSource) {
    Write-Host "Flutter.frameworkをコピー中..." -ForegroundColor Green
    Copy-Item -Path $FlutterFrameworkSource -Destination $FrameworkOutputDir -Recurse -Force
} else {
    Write-Host "警告: Flutter.frameworkが見つかりません: $FlutterFrameworkSource" -ForegroundColor Yellow
}

# Flutter-ObjC.frameworkを生成
Write-Host "Flutter-ObjC.frameworkを生成中..." -ForegroundColor Cyan
xcodebuild -workspace Runner.xcworkspace `
    -scheme Runner `
    -configuration $Configuration `
    -sdk iphoneos `
    -derivedDataPath build `
    -archivePath build/Runner.xcarchive `
    archive `
    CODE_SIGN_IDENTITY="" `
    CODE_SIGNING_REQUIRED=NO `
    CODE_SIGNING_ALLOWED=NO

# アーカイブからフレームワークを抽出
$ArchiveFrameworksDir = "build/Runner.xcarchive/Products/Applications/Runner.app/Frameworks"
if (Test-Path $ArchiveFrameworksDir) {
    Write-Host "アーカイブからフレームワークを抽出中..." -ForegroundColor Green
    Copy-Item -Path "$ArchiveFrameworksDir/*" -Destination $FrameworkOutputDir -Recurse -Force
} else {
    Write-Host "警告: アーカイブ内にフレームワークディレクトリが見つかりません: $ArchiveFrameworksDir" -ForegroundColor Yellow
}

# プロジェクトルートに戻る
Set-Location $ProjectRoot

# 生成されたフレームワークの内容を確認
Write-Host "生成されたフレームワークの内容:" -ForegroundColor Green
if (Test-Path $FrameworkOutputDir) {
    Get-ChildItem $FrameworkOutputDir | ForEach-Object {
        Write-Host "フレームワーク: $($_.Name)" -ForegroundColor Cyan
        if ($_.PSIsContainer) {
            $Size = (Get-ChildItem $_.FullName -Recurse | Measure-Object -Property Length -Sum).Sum
            Write-Host "  サイズ: $([math]::Round($Size / 1MB, 2)) MB" -ForegroundColor Yellow
            Write-Host "  内容:" -ForegroundColor Gray
            Get-ChildItem $_.FullName | ForEach-Object {
                Write-Host "    $($_.Name)" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "フレームワークディレクトリが存在しません" -ForegroundColor Red
}

Write-Host "Flutterフレームワークの生成が完了しました" -ForegroundColor Green
Write-Host "出力場所: $FrameworkOutputDir" -ForegroundColor Yellow
