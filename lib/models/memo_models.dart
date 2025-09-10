
/// メモアイテム
class MemoItem {
  final String id;
  String title;
  String content;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  String? category;

  MemoItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'category': category,
    };
  }

  factory MemoItem.fromJson(Map<String, dynamic> json) {
    return MemoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
      category: json['category'] as String?,
    );
  }

  MemoItem copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    String? category,
  }) {
    return MemoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      category: category ?? this.category,
    );
  }
}

/// メモカテゴリ
class MemoCategory {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;

  MemoCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MemoCategory.fromJson(Map<String, dynamic> json) {
    return MemoCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
