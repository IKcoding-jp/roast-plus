# RoastPlus アプリ セキュリティ対策まとめ

## 概要

RoastPlusアプリは、コーヒー焙煎業務管理を目的としたFlutterアプリケーションです。本ドキュメントでは、アプリケーションに実装されている包括的なセキュリティ対策について詳細に説明します。

## 1. 認証・認可システム

### 1.1 Google認証の実装
- **Firebase Authentication**を使用したGoogleサインイン
- セキュアなトークン管理（IDトークン、アクセストークン、リフレッシュトークン）
- プラットフォーム別の認証フロー対応（Web版：ポップアップ/リダイレクト、ネイティブ版：プロバイダー認証）

### 1.2 セキュアな認証サービス
- **SecureAuthService**による認証状態の管理
- トークンの有効性検証と自動更新
- 認証セッションの監視とセキュリティイベントの記録
- 無効なトークンの自動削除

### 1.3 Firestoreセキュリティルール
```javascript
// ユーザー認証チェック
function isAuthenticated() {
  return request.auth != null;
}

// ユーザーが自分のデータにアクセスしているかチェック
function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}

// グループメンバーかどうかチェック
function isGroupMember(groupId) {
  return isAuthenticated() &&
    exists(/databases/$(database)/documents/users/$(request.auth.uid)/userGroups/$(groupId));
}
```

## 2. データ暗号化・保護

### 2.1 セキュアストレージ
- **FlutterSecureStorage**を使用した機密情報の保存
- プラットフォーム別の実装（Web版：SharedPreferences、ネイティブ版：FlutterSecureStorage）
- 暗号化されたトークン保存と復号化

### 2.2 暗号化設定
- **SecurityConfig**による暗号化キー管理
- SHA-256ハッシュ化によるパスワード保護
- Base64エンコーディングによるトークン暗号化
- セキュアなランダムキー生成

### 2.3 暗号化されたローカルストレージ
- **EncryptedLocalStorageService**による全データの暗号化
- SharedPreferencesの代替として使用
- 自動的な暗号化・復号化処理

## 3. Firebase設定のセキュリティ

### 3.1 暗号化されたFirebase設定
- **EncryptedFirebaseConfigService**による設定管理
- 環境変数からの暗号化された設定値の取得
- ハードコードされたAPIキーの完全削除
- プラットフォーム別の設定管理

### 3.2 設定の検証
- 必須設定項目の存在確認
- 設定値の復号化テスト
- エラー時の詳細なログ出力

## 4. ネットワークセキュリティ

### 4.1 HTTPS通信の強制
- **NetworkSecurityService**によるネットワーク監視
- HTTP通信のブロック設定
- プラットフォーム別のHTTPS強制設定

### 4.2 Android用ネットワークセキュリティ設定
```xml
<network-security-config>
    <!-- デフォルト設定：HTTPS通信のみ許可 -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">firebase.googleapis.com</domain>
        <domain includeSubdomains="true">firestore.googleapis.com</domain>
        <!-- その他のFirebaseドメイン -->
    </domain-config>
    
    <!-- 開発環境でのみHTTP通信を許可 -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
    </domain-config>
</network-security-config>
```

### 4.3 iOS用App Transport Security設定
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSMinimumTLSVersion</key>
    <string>TLSv1.2</string>
    <key>NSRequiresCertificateTransparency</key>
    <true/>
</dict>
```

### 4.4 証明書検証
- 無効な証明書の拒否設定
- 証明書ピニングの準備（現在は無効化）
- 定期的な証明書有効性チェック

## 5. セキュリティ監視・監査

### 5.1 セキュリティ監視サービス
- **SecurityMonitorService**によるリアルタイム監視
- 30分間隔でのセキュリティチェック
- トークン有効性の検証
- セキュアストレージの可用性チェック

### 5.2 セキュリティイベントの記録
- 認証状態の変更ログ
- セキュリティ違反の検出と記録
- ネットワークセキュリティ違反の監視
- 詳細なエラーログの記録

### 5.3 セキュリティレポート
- セキュリティ状態の定期レポート生成
- 最近の違反履歴の取得
- ネットワークセキュリティ統計の更新

## 6. プライバシー保護・同意管理

### 6.1 同意管理システム
- **ConsentService**による包括的な同意管理
- 個人情報保護法およびGDPR準拠
- 必須同意とオプション同意の分類

### 6.2 同意の種類
- **必須同意**：基本データ収集、認証情報、業務データ、Googleサービス
- **オプション同意**：グループ機能、ゲーミフィケーション、利用統計、エラーログ、パフォーマンス監視、マーケティング、通知、広告配信、分析ツール

### 6.3 同意記録・管理
- 同意履歴の完全な記録
- 同意の撤回機能
- 同意統計情報の提供
- ポリシーバージョン管理

## 7. アプリケーションセキュリティ

### 7.1 署名設定
- リリース用の署名設定
- 環境変数による署名情報の管理
- キーストアファイルの保護

### 7.2 ビルド設定
- リリースビルドでのコード難読化
- ProGuardルールの適用
- デバッグ情報の削除

### 7.3 権限管理
- 最小権限の原則に基づく権限設定
- 必要な権限のみの要求
- 権限使用の明確な説明

## 8. ログ・監査機能

### 8.1 セキュリティログ
- 認証イベントの記録
- セキュリティ違反の検出と記録
- ネットワークセキュリティイベントの記録
- エラーログの詳細記録

### 8.2 監査証跡
- ユーザーアクションの追跡
- データアクセスの記録
- セキュリティイベントの時系列記録

## 9. エラーハンドリング・例外処理

### 9.1 セキュアなエラーハンドリング
- 機密情報の漏洩防止
- 適切なエラーメッセージの提供
- エラーログの安全な記録

### 9.2 例外処理
- 認証エラーの適切な処理
- ネットワークエラーの処理
- セキュリティ違反時の対応

## 10. 継続的セキュリティ改善

### 10.1 定期的なセキュリティチェック
- 自動化されたセキュリティ監視
- 定期的な脆弱性評価
- セキュリティ設定の検証

### 10.2 セキュリティ更新
- 依存関係の定期的な更新
- セキュリティパッチの適用
- 新しい脅威への対応

## 11. コンプライアンス・法的要件

### 11.1 個人情報保護法対応
- 適切な同意取得
- データの最小化
- データの適切な管理

### 11.2 GDPR準拠
- データ主体の権利の尊重
- 同意の明確な取得
- データの削除権の実装

## 12. セキュリティベストプラクティス

### 12.1 実装されているベストプラクティス
- 最小権限の原則
- 多層防御の実装
- セキュアなデフォルト設定
- 定期的なセキュリティ監視
- 適切なエラーハンドリング

### 12.2 推奨事項
- 定期的なセキュリティ監査の実施
- セキュリティトレーニングの実施
- インシデント対応計画の策定
- セキュリティテストの定期実行

## 結論

RoastPlusアプリは、認証・認可、データ暗号化、ネットワークセキュリティ、プライバシー保護、監視・監査など、多層的なセキュリティ対策を実装しています。これらの対策により、ユーザーのデータとプライバシーを保護し、セキュアなアプリケーション環境を提供しています。

継続的なセキュリティ改善と最新の脅威への対応により、アプリケーションのセキュリティレベルを維持・向上させることが重要です。

---

**作成日**: 2025年9月
**バージョン**: 0.6.27
**対象アプリ**: RoastPlus v0.6.27
