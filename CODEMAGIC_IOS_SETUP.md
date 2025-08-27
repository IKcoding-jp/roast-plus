# Codemagic iOS ビルド設定ガイド

## 概要
このドキュメントでは、Windows環境からCodemagicを使用してiOSアプリをビルドし、App Store Connectにアップロードする手順を説明します。

## 必要な設定

### 1. Apple Developer Program アカウント
- Apple Developer Programに登録済みである必要があります
- 有効な証明書とプロビジョニングプロファイルが必要です
- App Store Connect APIキーが必要です

### 2. Codemagicでの環境変数設定

Codemagicのプロジェクト設定で以下の環境変数を設定してください：

#### 必須環境変数（iOS署名用）
- `CM_CERTIFICATE`: iOS Distribution証明書（base64エンコード）
- `CM_CERTIFICATE_PASSWORD`: 証明書のパスワード
- `CM_PROVISIONING_PROFILE`: プロビジョニングプロファイル（base64エンコード）
- `CM_TEAM_ID`: Apple Developer Team ID
- `CM_BUNDLE_ID`: アプリのBundle ID（例：com.yourcompany.roastplus）

#### App Store Connect用環境変数
- `APP_STORE_CONNECT_API_KEY_ID`: App Store Connect APIキーID
- `APP_STORE_CONNECT_API_ISSUER_ID`: App Store Connect API発行者ID
- `APP_STORE_CONNECT_API_KEY`: App Store Connect APIキー（base64エンコード）
- `APP_STORE_CONNECT_APP_ID`: App Store ConnectのアプリID

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

#### App Store Connect APIキーの準備
1. App Store ConnectでAPIキーを作成
2. ダウンロードしたAPIキーファイル（.p8）をbase64エンコード：
   ```bash
   base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
   ```

### 4. Bundle IDの設定

`codemagic.yaml`の`CM_BUNDLE_ID`を実際のBundle IDに変更してください：

```yaml
CM_BUNDLE_ID: "com.yourcompany.roastplus"
```

### 5. App Store Connectでのアプリ設定

1. App Store Connectにログイン
2. 新しいアプリを作成（Bundle IDが一致していることを確認）
3. アプリ情報を設定（名前、説明、スクリーンショットなど）
4. アプリIDを取得して`APP_STORE_CONNECT_APP_ID`に設定

## ビルドワークフロー

### ios_debug
- デバッグビルド（コード署名なし）
- テスト用に使用

### ios_release
- リリースビルド（コード署名あり）
- 手動でApp Store Connectにアップロード

### ios_appstore
- リリースビルド（コード署名あり）
- **自動でApp Store Connectにアップロード**
- App Store配布用

### ios_test
- テスト実行とデバッグビルド
- CI/CD用

## ビルド手順

### 通常のリリースビルド
1. Codemagicにプロジェクトを接続
2. 環境変数を設定
3. `ios_release`ワークフローを実行
4. 生成されたIPAファイルを手動でApp Store Connectにアップロード

### 自動App Store Connectアップロード
1. Codemagicにプロジェクトを接続
2. 環境変数を設定（App Store Connect用を含む）
3. `ios_appstore`ワークフローを実行
4. 自動的にApp Store Connectにアップロードされる

## App Store Connect APIキーの設定

### 1. App Store ConnectでAPIキーを作成
1. App Store Connectにログイン
2. 「Users and Access」→「Keys」→「App Store Connect API」
3. 「Generate API Key」をクリック
4. キー名を入力し、アクセス権限を設定
5. キーをダウンロード（.p8ファイル）

### 2. 環境変数に設定
- `APP_STORE_CONNECT_API_KEY_ID`: キーID（例：ABC123DEF4）
- `APP_STORE_CONNECT_API_ISSUER_ID`: 発行者ID（例：57246b42-0d85-47b3-8e80-f3d2b83846c9）
- `APP_STORE_CONNECT_API_KEY`: ダウンロードした.p8ファイルをbase64エンコード

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

4. **App Store Connectアップロードエラー**
   - APIキーが正しく設定されているか確認
   - アプリIDが正しいか確認
   - Bundle IDがApp Store Connectのアプリと一致しているか確認

### ログの確認
Codemagicのビルドログで詳細なエラー情報を確認できます。

## 注意事項

- iOSビルドはmacOS環境でのみ実行可能です
- コード署名には有効な証明書が必要です
- Bundle IDは一意である必要があります
- プロビジョニングプロファイルはBundle IDと一致している必要があります
- App Store Connect APIキーは定期的に更新する必要があります
- 初回アップロード時は、App Store Connectでアプリ情報を手動で設定する必要があります
