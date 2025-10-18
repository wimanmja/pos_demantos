class Category {
  final String id;
  final String name;
  final DateTime? lastSyncAt;

  Category({
    required this.id,
    required this.name,
    this.lastSyncAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.parse(map['last_sync_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'last_sync_at': lastSyncAt?.toIso8601String(),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    DateTime? lastSyncAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name)';
  }
}