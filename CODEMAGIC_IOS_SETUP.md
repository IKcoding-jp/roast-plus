# Codemagic iOS ビルド設定ガイド

## 概要
このドキュメントでは、Windows環境からCodemagicを使用してiOSアプリをビルドする手順を説明します。

## 必要な設定

### 1. Apple Developer Program アカウント
- Apple Developer Programに登録済みである必要があります
- 有効な証明書とプロビジョニングプロファイルが必要です

### 2. Codemagicでの環境変数設定

Codemagicのプロジェクト設定で以下の環境変数を設定してください：

#### 必須環境変数
- `CM_CERTIFICATE`: iOS Distribution証明書（base64エンコード）
- `CM_CERTIFICATE_PASSWORD`: 証明書のパスワード
- `CM_PROVISIONING_PROFILE`: プロビジョニングプロファイル（base64エンコード）
- `CM_TEAM_ID`: Apple Developer Team ID
- `CM_BUNDLE_ID`: アプリのBundle ID（例：com.yourcompany.roastplus）

### 3. 証明書とプロビジョニングプロファイルの準備

#### 証明書の準備
1. Keychain AccessでiOS Distribution証明書をエクスポート
2. 証明書をbase64エンコード：
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```

#### プロビジョニングプロファイルの準備
1. Apple Developer Portalからプロビジョニングプロファイルをダウンロード
2. プロファイルをbase64エンコード：
   ```bash
   base64 -i profile.mobileprovision | pbcopy
   ```

### 4. Bundle IDの設定

`codemagic.yaml`の`CM_BUNDLE_ID`を実際のBundle IDに変更してください：

```yaml
CM_BUNDLE_ID: "com.yourcompany.roastplus"
```

## ビルドワークフロー

### ios_debug
- デバッグビルド（コード署名なし）
- テスト用に使用

### ios_release
- リリースビルド（コード署名あり）
- App Store配布用

### ios_test
- テスト実行とデバッグビルド
- CI/CD用

## ビルド手順

1. Codemagicにプロジェクトを接続
2. 環境変数を設定
3. 適切なワークフローを選択してビルド実行
4. ビルド成果物をダウンロード

## トラブルシューティング

### よくある問題

1. **証明書エラー**
   - 証明書が有効期限切れでないか確認
   - 正しくbase64エンコードされているか確認

2. **プロビジョニングプロファイルエラー**
   - Bundle IDが一致しているか確認
   - プロファイルが有効か確認

3. **CocoaPodsエラー**
   - `ios/Podfile`が正しく設定されているか確認
   - 依存関係が解決されているか確認

### ログの確認
Codemagicのビルドログで詳細なエラー情報を確認できます。

## 注意事項

- iOSビルドはmacOS環境でのみ実行可能です
- コード署名には有効な証明書が必要です
- Bundle IDは一意である必要があります
- プロビジョニングプロファイルはBundle IDと一致している必要があります
