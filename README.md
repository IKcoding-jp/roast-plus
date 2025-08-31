# roastplus

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## iOS フレームワーク生成

このプロジェクトでは、iOSビルド用のネイティブフレームワーク（Flutter.framework / Flutter-ObjC.framework）を生成できます。

### 自動生成（Codemagic）

Codemagicを使用してCI/CDパイプラインでフレームワークを自動生成する場合：

1. `codemagic.yaml`ファイルが設定済みです
2. iOSワークフローが実行されると、自動的にフレームワークが生成されます
3. 生成されたフレームワークは`build/ios/frameworks/`ディレクトリに保存されます

### 手動生成

#### Windows環境（PowerShell）

```powershell
# デバッグビルド用フレームワークを生成
.\scripts\generate_ios_frameworks.ps1

# リリースビルド用フレームワークを生成
.\scripts\generate_ios_frameworks.ps1 -Configuration Release

# カスタム出力ディレクトリを指定
.\scripts\generate_ios_frameworks.ps1 -OutputDir "custom/frameworks"
```

#### macOS/Linux環境（Bash）

```bash
# スクリプトに実行権限を付与
chmod +x ios/generate_frameworks.sh

# フレームワークを生成
./ios/generate_frameworks.sh
```

### 生成されるフレームワーク

- `Flutter.framework`: Flutterエンジンのコアフレームワーク
- `Flutter-ObjC.framework`: FlutterのObjective-Cブリッジフレームワーク

### 注意事項

- フレームワーク生成にはXcodeが必要です
- iOSプロジェクトの依存関係（CocoaPods）が正しくインストールされている必要があります
- 生成されたフレームワークは、iOSアプリの開発や配布に使用できます
