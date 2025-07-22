# アプリデータのクラウド同期機能

このアプリでは、アプリ全体のデータをGoogleアカウントに保存し、複数のデバイス間で同期できる機能を提供しています。

## 機能概要

### 1. クラウド保存
- テーマ設定（色、フォント、レイアウトなど）をFirebase Firestoreに保存
- アプリ設定（パスコード、タイマー設定など）をクラウドにバックアップ
- カスタムテーマも含めてクラウドにバックアップ
- ユーザーごとに独立したデータ保存

### 2. 自動同期
- テーマ設定を変更すると自動的にクラウドに保存
- アプリ起動時にクラウドから設定を読み込み
- 複数デバイス間で設定が自動的に同期

### 3. 手動同期
- アカウント情報ページから全データを手動でアップロード/ダウンロード
- 設定、テーマ、カスタムテーマなど全てのデータを一括同期

## 使用方法

### 1. Googleアカウントでログイン
クラウド同期機能を使用するには、まずGoogleアカウントにログインする必要があります。

### 2. 自動同期
- テーマ設定を変更すると自動的にクラウドに保存されます
- アプリを再起動すると、クラウドから最新の設定が読み込まれます
- 他のデバイスでも同じGoogleアカウントでログインすると、設定が自動的に同期されます

### 3. 手動同期
1. 設定 → アプリ設定 → アカウント情報 に移動
2. ログイン済みの場合、「データ同期」セクションが表示されます
3. 「アップロード」ボタン：現在の全データをクラウドに保存
4. 「ダウンロード」ボタン：クラウドから全データを取得して適用

## 技術実装

### ファイル構成
```
lib/
├── services/
│   ├── theme_cloud_service.dart    # テーマ設定のクラウド同期サービス
│   └── data_sync_service.dart      # 全データ同期サービス
└── models/
    └── theme_settings.dart         # テーマ設定モデル（クラウド連携追加）
```

### 主要クラス

#### ThemeCloudService
Firebase Firestoreを使用してテーマ設定をクラウドに保存・取得するサービス

**主要メソッド:**
- `saveThemeToCloud()`: テーマ設定をクラウドに保存
- `getThemeFromCloud()`: クラウドからテーマ設定を取得
- `saveCustomThemesToCloud()`: カスタムテーマをクラウドに保存
- `getCustomThemesFromCloud()`: クラウドからカスタムテーマを取得

#### DataSyncService
アプリ全体のデータを同期するサービス

**主要メソッド:**
- `uploadAllData()`: 全データをクラウドにアップロード
- `downloadAllData()`: 全データをクラウドからダウンロード
- `getSyncStatus()`: 同期状態をチェック
- `resolveConflicts()`: データの競合を解決
- `createBackup()`: データのバックアップを作成

### データ構造

#### Firestore コレクション構造
```
users/
  {userId}/
    settings/
      theme/
        themeData: {
          appBarColor: int,
          backgroundColor: int,
          buttonColor: int,
          // ... その他の色設定
        }
        lastUpdated: timestamp
      custom_themes/
        customThemes: {
          "カスタム1": {
            appBarColor: int,
            backgroundColor: int,
            // ... その他の色設定
          }
        }
        lastUpdated: timestamp
      app_settings/
        preheatMinutes: int,
        passcode_lock_enabled: bool,
        passcode: string,
        developerMode: bool,
        lastSync: timestamp
      schedule_settings/
        scheduleData: string,
        lastSync: timestamp
    backups/
      backup_{timestamp}/
        timestamp: timestamp,
        description: string,
        data: object
```

### エラーハンドリング
- ネットワークエラーやFirebase接続エラーを適切に処理
- クラウド保存に失敗してもローカル保存は継続
- ユーザーに分かりやすいエラーメッセージを表示

## セキュリティ

- Firebase Authenticationを使用したユーザー認証
- ユーザーごとに独立したデータ保存
- 適切なFirestoreセキュリティルールの設定が必要

## 依存関係

以下のパッケージが必要です：
```yaml
dependencies:
  firebase_core: ^2.30.0
  firebase_auth: ^4.17.8
  cloud_firestore: ^4.15.8
  google_sign_in: ^6.1.5
```

## 設定手順

### 1. Firebase プロジェクトの設定
1. Firebase Consoleでプロジェクトを作成
2. AuthenticationでGoogleサインインを有効化
3. Firestore Databaseを作成
4. 適切なセキュリティルールを設定

### 2. アプリの設定
1. `google-services.json`（Android）と`GoogleService-Info.plist`（iOS）を追加
2. Firebase初期化コードを追加

### 3. Firestore セキュリティルール
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## トラブルシューティング

### よくある問題

1. **ログインできない**
   - Google Sign-Inの設定を確認
   - SHA-1フィンガープリントの設定を確認

2. **クラウド保存に失敗する**
   - ネットワーク接続を確認
   - Firebaseプロジェクトの設定を確認
   - Firestoreセキュリティルールを確認

3. **同期が正しく動作しない**
   - ログイン状態を確認
   - アプリを再起動して再試行

### ログの確認
デバッグ時は以下のログを確認してください：
- Firebase接続エラー
- クラウド保存/取得エラー
- 認証エラー

## 今後の拡張予定

- テーマ設定の共有機能
- バックアップと復元機能
- オフライン対応の改善 