import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String id;
  final String transactionId;
  final String menuItemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime createdAt;

  SaleItem({
    required this.id,
    required this.transactionId,
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.createdAt,
  });

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'menu_item_id': menuItemId,
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'menu_item_id': menuItemId,
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  // // Create from SQLite Map
  // factory SaleItem.fromMap(Map<String, dynamic> map) {
  //   return SaleItem(
  //     id: map['id'] ?? '',
  //     transactionId: map['transaction_id'] ?? '',
  //     menuItemId: map['menu_item_id'] ?? '',
  //     itemName: map['item_name'] ?? '',
  //     quantity: (map['quantity'] as num?)?.toInt() ?? 0,
  //     unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
  //     totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
  //     createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
  //   );
  // }

  // Create from Firestore Map
  factory SaleItem.fromFirestoreMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] ?? '',
      transactionId: map['transaction_id'] ?? '',
      menuItemId: map['menu_item_id'] ?? '',
      itemName: map['item_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Copy with method
  SaleItem copyWith({
    String? id,
    String? transactionId,
    String? menuItemId,
    String? itemName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    DateTime? createdAt,
  }) {
    return SaleItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      menuItemId: menuItemId ?? this.menuItemId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'SaleItem{id: $id, transactionId: $transactionId, menuItemId: $menuItemId, itemName: $itemName, quantity: $quantity, unitPrice: $unitPrice, totalPrice: $totalPrice, createdAt: $createdAt}';
  }
}
