import 'package:cloud_firestore/cloud_firestore.dart';

class SaleTransaction {
  final String id;
  final double totalAmount;
  final String paymentMethod;
  final Timestamp transactionDate; // <--- PERUBAHAN TIPE DATA
  final String? tableNumber;
  final String? customerName;
  final double cashPaid;
  final double changeGiven;
  final String userId;
  final int isSynced;
  final String lastSyncAt;

  SaleTransaction({
    required this.id,
    required this.totalAmount,
    required this.paymentMethod,
    required this.transactionDate,
    this.tableNumber,
    this.customerName,
    required this.cashPaid,
    required this.changeGiven,
    required this.userId,
    this.isSynced = 0,
    required this.lastSyncAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'transaction_date': transactionDate,
      'table_number': tableNumber,
      'customer_name': customerName,
      'cash_paid': cashPaid,
      'change_given': changeGiven,
      'is_synced': isSynced,
      'last_sync_at': lastSyncAt,
      'user_id': userId,
    };
  }

  // Create from Firestore Map
  factory SaleTransaction.fromFirestoreMap(Map<String, dynamic> map) {
    return SaleTransaction(
      id: map['id'] ?? '',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] ?? '',
      transactionDate: map['transaction_date'] as Timestamp? ?? Timestamp.now(), // <--- Membaca sebagai Timestamp
      tableNumber: map['table_number'],
      customerName: map['customer_name'],
      cashPaid: (map['cash_paid'] as num?)?.toDouble() ?? 0.0,
      changeGiven: (map['change_given'] as num?)?.toDouble() ?? 0.0,
      userId: map['user_id'] ?? '',
      isSynced: (map['is_synced'] as int?) ?? 0,
      lastSyncAt: map['last_sync_at'] ?? DateTime.now().toIso8601String(),
    );
  }

  // Copy with method
  SaleTransaction copyWith({
    String? id,
    double? totalAmount,
    String? paymentMethod,
    Timestamp? transactionDate, // <--- PERUBAHAN KRUSIAL: Ubah dari String? menjadi Timestamp?
    String? tableNumber,
    String? customerName,
    double? cashPaid,
    double? changeGiven,
    String? userId,
    int? isSynced,
    String? lastSyncAt,
  }) {
    return SaleTransaction(
      id: id ?? this.id,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      tableNumber: tableNumber ?? this.tableNumber,
      customerName: customerName ?? this.customerName,
      cashPaid: cashPaid ?? this.cashPaid,
      changeGiven: changeGiven ?? this.changeGiven,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return 'SaleTransaction{id: $id, totalAmount: $totalAmount, paymentMethod: $paymentMethod, transactionDate: $transactionDate, tableNumber: $tableNumber, customerName: $customerName, cashPaid: $cashPaid, changeGiven: $changeGiven, isSynced: $isSynced, lastSyncAt: $lastSyncAt, userId: $userId}';
  }
}