import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sale_transaction_model.dart';
import '../models/sale_item_model.dart';

class SaleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save complete sale transaction with items to Firebase
  Future<void> saveCompleteSale(SaleTransaction transaction, List<SaleItem> saleItems) async {
    try {
      print('🔥 Starting Firebase save process...');
      
      // Ensure user is authenticated
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('🔐 No authenticated user, signing in anonymously...');
        await _auth.signInAnonymously();
        currentUser = _auth.currentUser;
      }
      
      if (currentUser == null) {
        throw Exception('Failed to authenticate user');
      }

      // Use batch write for atomic operation
      WriteBatch batch = _firestore.batch();

      // Add transaction with user ID
      DocumentReference transactionRef = _firestore
          .collection('sales_transactions')
          .doc(transaction.id);
      
      Map<String, dynamic> transactionData = transaction.toFirestoreMap();
      transactionData['user_id'] = currentUser.uid;
      transactionData['created_at'] = FieldValue.serverTimestamp();
      transactionData['updated_at'] = FieldValue.serverTimestamp();
      
      batch.set(transactionRef, transactionData);
      print('📝 Saving transaction: ${transaction.id}');
      print('📊 Transaction data: $transactionData');

      // Add all sale items to batch
      for (SaleItem item in saleItems) {
        DocumentReference itemRef = _firestore
            .collection('sale_items')
            .doc(item.id);
        
        Map<String, dynamic> itemData = item.toFirestoreMap();
        itemData['user_id'] = currentUser.uid;
        itemData['transaction_id'] = transaction.id;
        itemData['created_at'] = FieldValue.serverTimestamp();
        
        batch.set(itemRef, itemData);
        print('📦 Adding item to batch: ${item.itemName} x${item.quantity}');
      }

      // Commit the batch
      await batch.commit();
      print('✅ Firebase batch write completed successfully');

      // Verify the data was saved
      await _verifyDataSaved(transaction.id, saleItems.length);

    } catch (e) {
      print('❌ Firebase save error: $e');
      throw Exception('Failed to save transaction to Firebase: $e');
    }
  }

  // Verify data was actually saved to Firebase
  Future<void> _verifyDataSaved(String transactionId, int expectedItemCount) async {
    try {
      // Check if transaction exists
      DocumentSnapshot transactionDoc = await _firestore
          .collection('sales_transactions')
          .doc(transactionId)
          .get();
      
      if (!transactionDoc.exists) {
        throw Exception('Transaction not found after save');
      }
      
      // Check if all items exist
      QuerySnapshot itemsQuery = await _firestore
          .collection('sale_items')
          .where('transaction_id', isEqualTo: transactionId)
          .get();
      
      if (itemsQuery.docs.length != expectedItemCount) {
        throw Exception('Item count mismatch: expected $expectedItemCount, found ${itemsQuery.docs.length}');
      }
      
      print('✅ Data verification completed - all data saved successfully');
    } catch (e) {
      print('⚠️ Data verification failed: $e');
      throw Exception('Data verification failed: $e');
    }
  }

  // Get sales transactions from Firebase
  Future<List<SaleTransaction>> getSalesTransactions({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection('sales_transactions')
          .orderBy('transaction_date', descending: true);

      if (startDate != null) {
        query = query.where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('transaction_date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      QuerySnapshot snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return SaleTransaction.fromFirestoreMap(data);
      }).toList();
    } catch (e) {
      print('Error getting sales transactions: $e');
      throw Exception('Failed to get sales transactions: $e');
    }
  }

  // Get sale items for a specific transaction
  Future<List<SaleItem>> getSaleItemsForTransaction(String transactionId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('sale_items')
          .where('transaction_id', isEqualTo: transactionId)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return SaleItem.fromFirestoreMap(data);
      }).toList();
    } catch (e) {
      print('Error getting sale items: $e');
      throw Exception('Failed to get sale items: $e');
    }
  }

  // Get today's sales summary
  Future<Map<String, dynamic>> getTodaysSalesSummary() async {
    try {
      DateTime today = DateTime.now();
      DateTime startOfDay = DateTime(today.year, today.month, today.day);
      DateTime endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      QuerySnapshot snapshot = await _firestore
          .collection('sales_transactions')
          .where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('transaction_date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      double totalSales = 0;
      int totalTransactions = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalSales += (data['total_amount'] as num).toDouble();
      }

      return {
        'totalSales': totalSales,
        'totalTransactions': totalTransactions,
        'averageTransaction': totalTransactions > 0 ? totalSales / totalTransactions : 0,
      };
    } catch (e) {
      print('Error getting today\'s sales summary: $e');
      throw Exception('Failed to get today\'s sales summary: $e');
    }
  }

  // Legacy methods for backward compatibility
  Future<void> saveSaleTransaction(SaleTransaction transaction, List<SaleItem> items) async {
    await saveCompleteSale(transaction, items);
  }

  Future<List<SaleTransaction>> getSaleTransactions({DateTime? startDate, DateTime? endDate}) async {
    return await getSalesTransactions(startDate: startDate, endDate: endDate);
  }

  Future<List<SaleItem>> getSaleItems(String transactionId) async {
    return await getSaleItemsForTransaction(transactionId);
  }

  Future<double> getTotalSalesToday() async {
    final summary = await getTodaysSalesSummary();
    return summary['totalSales'] ?? 0.0;
  }

  Future<int> getTransactionCountToday() async {
    final summary = await getTodaysSalesSummary();
    return summary['totalTransactions'] ?? 0;
  }

  Future<void> deleteSaleTransaction(String transactionId) async {
    final batch = _firestore.batch();
    
    // Delete sale items
    final itemsQuery = await _firestore
        .collection('sale_items')
        .where('transaction_id', isEqualTo: transactionId)
        .get();
    
    for (final doc in itemsQuery.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete transaction
    batch.delete(_firestore.collection('sales_transactions').doc(transactionId));
    
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getSalesStatistics({DateTime? startDate, DateTime? endDate}) async {
    // This would require more complex aggregation queries in Firestore
    // For now, return empty list - can be implemented with Cloud Functions if needed
    return [];
  }
}
