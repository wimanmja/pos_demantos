class MenuOption {
  final String id;
  final String menuItemId;
  final String type; // 'size', 'temperature', 'addon'
  final String name;
  final double priceAdjustment; // Adjustment to base item price
  final DateTime? lastSyncAt;

  MenuOption({
    required this.id,
    required this.menuItemId,
    required this.type,
    required this.name,
    required this.priceAdjustment,
    this.lastSyncAt,
  });

  factory MenuOption.fromMap(Map<String, dynamic> map) {
    return MenuOption(
      id: map['id'] as String,
      menuItemId: map['menu_item_id'] as String,
      type: map['type'] as String,
      name: map['name'] as String,
      priceAdjustment: map['price_adjustment'] as double,
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.parse(map['last_sync_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'type': type,
      'name': name,
      'price_adjustment': priceAdjustment,
      'last_sync_at': lastSyncAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'MenuOption(id: $id, type: $type, name: $name, priceAdj: $priceAdjustment)';
  }
}