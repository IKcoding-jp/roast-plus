# App Store Connect APIキー設定ガイド

## 概要
このドキュメントでは、CodemagicでApp Store Connectに自動アップロードするために必要なAPIキーの設定手順を説明します。

## 前提条件
- Apple Developer Programに登録済み
- App Store Connectにアクセス権限がある
- 管理者またはApp Manager権限がある

## 1. App Store ConnectでAPIキーを作成

### ステップ1: App Store Connectにログイン
1. [App Store Connect](https://appstoreconnect.apple.com)にログイン
2. 「Users and Access」をクリック
3. 左サイドバーで「Keys」を選択
4. 「App Store Connect API」をクリック

### ステップ2: APIキーを生成
1. 「Generate API Key」ボタンをクリック
2. キー名を入力（例：「Codemagic iOS Upload」）
3. アクセス権限を設定：
   - **App Manager**: アプリの管理権限
   - **Developer**: 開発者権限
4. 「Generate」をクリック

### ステップ3: キー情報を記録
生成されたキーの情報を安全な場所に保存：
- **Key ID**: 例：ABC123DEF4
- **Issuer ID**: 例：57246b42-0d85-47b3-8e80-f3d2b83846c9
- **API Key**: ダウンロードした.p8ファイル

## 2. APIキーファイルの準備

### ステップ1: ダウンロードした.p8ファイルをbase64エンコード
```bash
# macOSの場合
base64 -i AuthKey_ABC123DEF4.p8 | pbcopy

# Windowsの場合（PowerShell）
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_ABC123DEF4.p8"))
```

### ステップ2: エンコード結果を保存
生成されたbase64文字列を安全な場所に保存してください。

## 3. Codemagicで環境変数を設定

### ステップ1: Codemagicプロジェクトにアクセス
1. [Codemagic](https://codemagic.io)にログイン
2. プロジェクトを選択
3. 「Settings」→「Environment variables」をクリック

### ステップ2: 環境変数を追加
以下の環境変数を追加してください：

| 変数名 | 値 | 説明 |
|--------|-----|------|
| `APP_STORE_CONNECT_API_KEY_ID` | ABC123DEF4 | 生成されたKey ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | 57246b42-0d85-47b3-8e80-f3d2b83846c9 | 発行者ID |
| `APP_STORE_CONNECT_API_KEY` | [base64エンコードされた.p8ファイル] | base64エンコードされたAPIキー |
| `APP_STORE_CONNECT_APP_ID` | 1234567890 | App Store ConnectのアプリID |

### ステップ3: セキュリティ設定
- すべての環境変数に「Secure」チェックボックスをオンにする
- 「Group」を「App Store Connect」などに設定

## 4. App Store Connectでアプリを作成

### ステップ1: 新しいアプリを追加
1. App Store Connectで「My Apps」をクリック
2. 「+」ボタンをクリック
3. 「New App」を選択

### ステップ2: アプリ情報を入力
- **Platform**: iOS
- **Name**: アプリ名（例：「ローストプラス」）
- **Primary language**: 日本語
- **Bundle ID**: `com.example.roastplus`（codemagic.yamlと一致させる）
- **SKU**: 一意の識別子（例：roastplus2024）

### ステップ3: アプリIDを取得
作成されたアプリのIDを取得して`APP_STORE_CONNECT_APP_ID`に設定

## 5. トラブルシューティング

### よくある問題と解決方法

#### 1. base64デコードエラー
```
base64: stdin: (null): error decoding base64 input stream
```
**原因**: APIキーが正しくbase64エンコードされていない
**解決方法**: 
- .p8ファイルを再度base64エンコード
- 改行文字や余分な文字が含まれていないか確認

#### 2. IPAファイルが見つからない
```
エラー: IPAファイルが見つかりません
```
**原因**: ビルドプロセスでIPAファイルが生成されていない
**解決方法**:
- コード署名設定を確認
- エクスポートオプションファイルを確認
- ビルドログで詳細なエラーを確認

#### 3. 認証エラー
```
Authentication failed
```
**原因**: APIキーの権限が不足している
**解決方法**:
- App Store ConnectでAPIキーの権限を確認
- アプリへのアクセス権限を確認

#### 4. Bundle ID不一致
```
Bundle ID does not match
```
**原因**: codemagic.yamlのBundle IDとApp Store ConnectのBundle IDが一致していない
**解決方法**:
- `CM_BUNDLE_ID`を実際のBundle IDに更新
- App Store Connectのアプリ設定を確認

## 6. セキュリティのベストプラクティス

### APIキーの管理
- APIキーは定期的に更新する（推奨：90日ごと）
- 不要になったAPIキーは削除する
- APIキーは安全な場所に保管する

### 環境変数の管理
- 本番環境とテスト環境で異なるAPIキーを使用
- 環境変数は暗号化して保存
- アクセス権限を最小限に設定

## 7. テスト手順

### ステップ1: デバッグビルドでテスト
1. `ios_debug`ワークフローを実行
2. ビルドが成功することを確認

### ステップ2: リリースビルドでテスト
1. `ios_release`ワークフローを実行
2. IPAファイルが生成されることを確認

### ステップ3: App Store Connectアップロードでテスト
1. `ios_appstore`ワークフローを実行
2. App Store Connectに正常にアップロードされることを確認

## 8. 参考リンク

- [App Store Connect API Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
- [Codemagic iOS Documentation](https://docs.codemagic.io/yaml-basic-configuration/building-for-ios/)
- [Apple Developer Program](https://developer.apple.com/programs/)
