# RoastPlus ☕

**全国のBYSNで働く皆さんのための非公式記録アプリ**

RoastPlusは、コーヒー焙煎業務に従事する従業員のモチベーション向上と業務効率化を目的として開発されたFlutterアプリです。実際にBYSNで働いている従業員が、仕事の質向上のために開発しました。

## 🌟 主要機能

### 📱 焙煎管理
- **焙煎タイマー**: 精密な焙煎時間管理とアラーム機能
- **焙煎記録**: 豆の種類、重さ、焙煎度合い、時間、メモの記録
- **焙煎分析**: 過去の記録データから傾向を分析
- **焙煎スケジュール**: 作業スケジュールの自動作成と管理

### 📊 業務管理
- **TODOリスト**: タスク管理と通知機能
- **ドリップカウンター**: ドリップパックのカウントと統計
- **テイスティング記録**: コーヒーの試飲評価と感想記録
- **作業進捗管理**: 作業状況の記録と進捗率の可視化

### 👥 グループ機能
- **チーム共有**: 仲間とデータを共有して業務を効率化
- **リアルタイム同期**: メンバー間でのリアルタイムデータ同期
- **権限管理**: 管理者・メンバー権限による適切なアクセス制御
- **QRコード連携**: 簡単なグループ参加と招待

### 🎮 ゲーミフィケーション
- **バッジシステム**: 達成度に応じたバッジ獲得
- **統計ダッシュボード**: 個人・グループの活動統計
- **成長記録**: スキル向上の可視化

## 🚀 技術仕様

### プラットフォーム対応
- **Android**: ネイティブアプリ
- **iOS**: ネイティブアプリ
- **Web**: プログレッシブウェブアプリ（PWA）

### 主要技術スタック
- **フレームワーク**: Flutter 3.8.1+
- **バックエンド**: Firebase（Firestore、Authentication、Storage）
- **状態管理**: Provider
- **UI/UX**: Material Design 3
- **認証**: Google Sign-In、Firebase Auth
- **通知**: ローカル通知、プッシュ通知
- **データ同期**: リアルタイム同期、オフライン対応

### セキュリティ機能
- **暗号化ストレージ**: 機密データの安全な保存
- **セッション管理**: 自動ログアウトとセキュリティ監視
- **環境変数管理**: APIキーとシークレットの安全な管理

## 🔧 セットアップ

### 1. 環境変数の設定

プロジェクトのAPIキーとシークレットは`app_config.env`ファイルで管理されています。

`app_config.env` ファイルに必要な環境変数を設定すると、アプリ起動時に自動で読み込まれます。

### 2. 必要な環境変数

`app_config.env`ファイルに以下の設定が必要です：

- `FIREBASE_PROJECT_ID`: FirebaseプロジェクトID
- `FIREBASE_WEB_API_KEY`: Firebase Web APIキー
- `GOOGLE_SIGN_IN_CLIENT_ID`: Google Sign-InクライアントID
- `ADMOB_ANDROID_APP_ID`: Google AdMobアプリケーションID
- `KEYSTORE_PASSWORD`: Android署名用パスワード
- `KEY_PASSWORD`: Android署名用キーパスワード
- **ネットワークセキュリティ**: 通信の暗号化と検証

## 📱 インストール方法

### Android
1. Google Play Storeから「RoastPlus」を検索
2. インストールボタンをタップ
3. アプリを起動してGoogleアカウントでログイン

### iOS
1. App Storeから「RoastPlus」を検索
2. インストールボタンをタップ
3. アプリを起動してGoogleアカウントでログイン

### Web版
1. ブラウザで [https://roastplus.web.app](https://roastplus.web.app) にアクセス
2. 「ホーム画面に追加」でPWAとしてインストール可能

## 🎯 対象ユーザー

- **BYSN従業員**: コーヒー焙煎業務に従事するスタッフ
- **コーヒー愛好家**: 焙煎技術の向上を目指す方
- **チームリーダー**: 業務管理とチーム効率化を重視する方

## 🔧 開発者向け情報

### 開発環境セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/IKcoding-jp/Roast-Plus.git
cd roastplus

# 依存関係をインストール
flutter pub get

# アプリを実行
flutter run
```

### ビルド方法

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

### 主要ディレクトリ構成

```
lib/
├── pages/           # 画面コンポーネント
│   ├── roast/      # 焙煎関連画面
│   ├── business/   # 業務管理画面
│   ├── group/      # グループ機能画面
│   └── settings/   # 設定画面
├── services/        # ビジネスロジック
├── models/          # データモデル
├── widgets/         # 再利用可能なUIコンポーネント
└── utils/           # ユーティリティ関数
```

## 📄 ライセンス

このプロジェクトは非公式アプリです。BYSNとは一切関係ありません。

## 🤝 貢献

バグ報告や機能要望は、GitHubのIssuesページでお知らせください。

## 📞 サポート

- **アプリ内ヘルプ**: 設定 > 使い方ガイド
- **Webサイト**: [https://roastplus.web.app](https://roastplus.web.app)
- **プライバシーポリシー**: アプリ内で確認可能

---

**RoastPlus** - コーヒー焙煎業務を、もっと楽しく、もっと効率的に ☕✨
# Roast-Plus
