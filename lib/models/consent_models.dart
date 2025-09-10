/// 同意の種類を定義する列挙型
enum ConsentType {
  // 基本同意
  basicDataCollection('basic_data_collection', '基本データ収集'),
  authentication('authentication', '認証情報'),

  // 機能別同意
  businessData('business_data', '業務データ'),
  groupFeatures('group_features', 'グループ機能'),
  gamification('gamification', 'ゲーミフィケーション'),

  // 分析・統計
  usageAnalytics('usage_analytics', '利用統計'),
  errorLogging('error_logging', 'エラーログ'),
  performanceMonitoring('performance_monitoring', 'パフォーマンス監視'),

  // マーケティング
  marketing('marketing', 'マーケティング'),
  notifications('notifications', '通知'),

  // 第三者サービス
  googleServices('google_services', 'Googleサービス'),
  admob('admob', '広告配信'),
  analytics('analytics', '分析ツール');

  const ConsentType(this.id, this.displayName);

  final String id;
  final String displayName;
}

/// 同意の状態を定義する列挙型
enum ConsentStatus {
  notRequested('not_requested', '未要求'),
  pending('pending', '保留中'),
  granted('granted', '同意済み'),
  denied('denied', '拒否'),
  withdrawn('withdrawn', '撤回済み');

  const ConsentStatus(this.id, this.displayName);

  final String id;
  final String displayName;
}

/// 同意記録のデータモデル
class ConsentRecord {
  final String id;
  final String userId;
  final ConsentType type;
  final ConsentStatus status;
  final DateTime timestamp;
  final String? version; // 同意ポリシーのバージョン
  final Map<String, dynamic>? metadata; // 追加情報
  final String? ipAddress; // IPアドレス（オプション）
  final String? userAgent; // ユーザーエージェント（オプション）

  const ConsentRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.timestamp,
    this.version,
    this.metadata,
    this.ipAddress,
    this.userAgent,
  });

  /// Firestore用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.id,
      'status': status.id,
      'timestamp': timestamp.toIso8601String(),
      'version': version,
      'metadata': metadata,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }

  /// FirestoreのMapからオブジェクトを作成
  factory ConsentRecord.fromMap(Map<String, dynamic> map) {
    return ConsentRecord(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: ConsentType.values.firstWhere(
        (e) => e.id == map['type'],
        orElse: () => ConsentType.basicDataCollection,
      ),
      status: ConsentStatus.values.firstWhere(
        (e) => e.id == map['status'],
        orElse: () => ConsentStatus.notRequested,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      version: map['version'],
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
      ipAddress: map['ipAddress'],
      userAgent: map['userAgent'],
    );
  }

  /// コピーを作成（状態変更用）
  ConsentRecord copyWith({
    String? id,
    String? userId,
    ConsentType? type,
    ConsentStatus? status,
    DateTime? timestamp,
    String? version,
    Map<String, dynamic>? metadata,
    String? ipAddress,
    String? userAgent,
  }) {
    return ConsentRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
    );
  }
}

/// 同意要求のデータモデル
class ConsentRequest {
  final String id;
  final ConsentType type;
  final String title;
  final String description;
  final String? detailedDescription;
  final bool isRequired; // 必須同意かどうか
  final List<ConsentType> dependencies; // 依存する同意
  final String version; // 同意ポリシーのバージョン
  final DateTime createdAt;
  final DateTime? expiresAt; // 有効期限（オプション）

  const ConsentRequest({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.detailedDescription,
    required this.isRequired,
    this.dependencies = const [],
    required this.version,
    required this.createdAt,
    this.expiresAt,
  });

  /// 有効期限が切れているかチェック
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 必須同意かどうか
  bool get isMandatory => isRequired;

  /// Firestore用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.id,
      'title': title,
      'description': description,
      'detailedDescription': detailedDescription,
      'isRequired': isRequired,
      'dependencies': dependencies.map((e) => e.id).toList(),
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  /// FirestoreのMapからオブジェクトを作成
  factory ConsentRequest.fromMap(Map<String, dynamic> map) {
    return ConsentRequest(
      id: map['id'] ?? '',
      type: ConsentType.values.firstWhere(
        (e) => e.id == map['type'],
        orElse: () => ConsentType.basicDataCollection,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      detailedDescription: map['detailedDescription'],
      isRequired: map['isRequired'] ?? false,
      dependencies:
          (map['dependencies'] as List<dynamic>?)
              ?.map(
                (e) => ConsentType.values.firstWhere(
                  (type) => type.id == e,
                  orElse: () => ConsentType.basicDataCollection,
                ),
              )
              .toList() ??
          [],
      version: map['version'] ?? '1.0',
      createdAt: DateTime.parse(map['createdAt']),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'])
          : null,
    );
  }
}

/// 同意設定のデータモデル
class ConsentSettings {
  final String userId;
  final Map<ConsentType, ConsentStatus> consents;
  final DateTime lastUpdated;
  final String policyVersion;

  const ConsentSettings({
    required this.userId,
    required this.consents,
    required this.lastUpdated,
    required this.policyVersion,
  });

  /// 特定の同意が許可されているかチェック
  bool hasConsent(ConsentType type) {
    return consents[type] == ConsentStatus.granted;
  }

  /// 必須同意がすべて許可されているかチェック
  bool hasRequiredConsents(List<ConsentType> requiredTypes) {
    return requiredTypes.every((type) => hasConsent(type));
  }

  /// 同意を更新
  ConsentSettings updateConsent(ConsentType type, ConsentStatus status) {
    final updatedConsents = Map<ConsentType, ConsentStatus>.from(consents);
    updatedConsents[type] = status;

    return ConsentSettings(
      userId: userId,
      consents: updatedConsents,
      lastUpdated: DateTime.now(),
      policyVersion: policyVersion,
    );
  }

  /// Firestore用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'consents': consents.map((key, value) => MapEntry(key.id, value.id)),
      'lastUpdated': lastUpdated.toIso8601String(),
      'policyVersion': policyVersion,
    };
  }

  /// FirestoreのMapからオブジェクトを作成
  factory ConsentSettings.fromMap(Map<String, dynamic> map) {
    final consentsMap = <ConsentType, ConsentStatus>{};
    if (map['consents'] != null) {
      final consents = Map<String, dynamic>.from(map['consents']);
      for (final entry in consents.entries) {
        final type = ConsentType.values.firstWhere(
          (e) => e.id == entry.key,
          orElse: () => ConsentType.basicDataCollection,
        );
        final status = ConsentStatus.values.firstWhere(
          (e) => e.id == entry.value,
          orElse: () => ConsentStatus.notRequested,
        );
        consentsMap[type] = status;
      }
    }

    return ConsentSettings(
      userId: map['userId'] ?? '',
      consents: consentsMap,
      lastUpdated: DateTime.parse(map['lastUpdated']),
      policyVersion: map['policyVersion'] ?? '1.0',
    );
  }
}
