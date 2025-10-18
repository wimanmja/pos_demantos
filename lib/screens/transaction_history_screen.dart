import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  _TransactionHistoryScreenState createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String searchCustomer = '';
  String filterCashier = '';
  DateTimeRange? selectedDateRange;

  double totalToday = 0;
  double totalMonth = 0;
  double totalYear = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotals();
  }

  // Parse tanggal transaksi (lebih sederhana)
  DateTime _parseTransactionDate(dynamic transactionDate) {
    if (transactionDate is Timestamp) {
      return transactionDate.toDate();
    }
    // Jika tidak ada data lama, ini adalah fallback yang aman
    return DateTime.now(); 
  }

  // Parse total amount agar aman dari int, double, String, null
  double _parseTotal(dynamic totalAmount) {
    if (totalAmount is int) return totalAmount.toDouble();
    if (totalAmount is double) return totalAmount;
    if (totalAmount is String) return double.tryParse(totalAmount) ?? 0;
    return 0;
  }

  Future<void> _calculateTotals() async {
    // Hanya gunakan collection BARU
    final newRef = FirebaseFirestore.instance.collection('sales_transactions_baru');
    final now = DateTime.now();
    
    // Ambil semua dokumen dari awal tahun untuk perhitungan klien yang efisien
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfNextYear = DateTime(now.year + 1, 1, 1); 

    try {
      // Query Data BARU (Timestamp) - Filter di Firestore untuk efisiensi
      final yearlySnap = await newRef
          .where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('transaction_date', isLessThan: Timestamp.fromDate(endOfNextYear))
          .get();
          
      final allDocs = yearlySnap.docs; // Hanya dari satu sumber
      
      // ... (sisa logika perhitungan dailyTotal, monthlyTotal, yearlyTotal tetap sama)

      double dailyTotal = 0;
      double monthlyTotal = 0;
      double yearlyTotal = 0;
      final today = DateTime(now.year, now.month, now.day);
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (var doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final total = _parseTotal(data['total_amount']);
          // Karena semua data baru sudah Timestamp, parsing lebih aman
          final date = (data['transaction_date'] as Timestamp).toDate(); 
          
          yearlyTotal += total;

          if (date.isAfter(startOfMonth.subtract(const Duration(milliseconds: 1)))) {
            monthlyTotal += total;
          }
          
          if (date.isAfter(today.subtract(const Duration(milliseconds: 1))) && date.isBefore(today.add(const Duration(days: 1)))) {
            dailyTotal += total;
          }
      }

      if (mounted) {
        setState(() {
          totalToday = dailyTotal;
          totalMonth = monthlyTotal;
          totalYear = yearlyTotal;
        });
      }
    } catch (e) {
      debugPrint('Error calculating totals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    CollectionReference transactionsRef =
        FirebaseFirestore.instance.collection('sales_transactions');

    Query transactionsQuery =
        transactionsRef.orderBy('transaction_date', descending: true);

    // Apply date filter
    if (selectedDateRange != null) {
      // Tanggal mulai (termasuk)
      final startDate = selectedDateRange!.start;
      
      // Tanggal akhir (eksklusif) - tambah 1 hari
      // Ini memastikan semua transaksi pada tanggal akhir yang dipilih akan disertakan.
      final endDate = selectedDateRange!.end.add(const Duration(days: 1)); 

      transactionsQuery = transactionsQuery
          .where('transaction_date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate)) // <--- Menggunakan startDate lokal
          .where('transaction_date',
              isLessThan: Timestamp.fromDate(endDate)); // <--- Menggunakan endDate lokal dan operator isLessThan
      // Perbaikan ini menghilangkan unused_local_variable dan memperbaiki logika filter
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histori Transaksi'),
      ),
      body: Column(
        children: [
          // FILTER TANGGAL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDateRange = picked;
                        });
                      }
                    },
                    child: Text(selectedDateRange == null
                        ? 'Filter Tanggal'
                        : '${selectedDateRange!.start.toLocal().toString().split(' ')[0]} - ${selectedDateRange!.end.toLocal().toString().split(' ')[0]}'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // TOTAL PENJUALAN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Hari Ini: Rp ${totalToday.toStringAsFixed(0)}'),
                Text('Total Bulan Ini: Rp ${totalMonth.toStringAsFixed(0)}'),
                Text('Total Tahun Ini: Rp ${totalYear.toStringAsFixed(0)}'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // LIST TRANSAKSI
          Expanded(
            child: StreamBuilder<QuerySnapshot>( // Kembali ke StreamBuilder
              stream: () {
                // 1. Inisialisasi query ke collection BARU
                Query transactionsQuery = FirebaseFirestore.instance
                    .collection('sales_transactions_baru')
                    .orderBy('transaction_date', descending: true);
                
                // 2. Terapkan Filter Tanggal
                if (selectedDateRange != null) {
                  final startDate = selectedDateRange!.start;
                  final endDate = selectedDateRange!.end.add(const Duration(days: 1)); 

                  transactionsQuery = transactionsQuery
                      .where('transaction_date',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                      .where('transaction_date',
                          isLessThan: Timestamp.fromDate(endDate)); 
                }
                return transactionsQuery.snapshots();
              }(), // Panggil fungsi anonim ini untuk mendapatkan stream
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Jika Anda ingin menangani error (opsional)
                if (snapshot.hasError) {
                  return Center(child: Text('Error memuat data: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Tidak ada transaksi'));
                }

                // Filter di klien (Pelanggan/Kasir)
                final transactions = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final customer_name = (data['customer_name'] ?? '').toString().toLowerCase();
                  
                  return customer_name.contains(searchCustomer);
                }).toList();

                if (transactions.isEmpty) {
                  return const Center(child: Text('Item tidak ditemukan'));
                }
                
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final data = transactions[index].data() as Map<String, dynamic>;
                    final date = _parseTransactionDate(data['transaction_date']);
                    final total = _parseTotal(data['total_amount']);

                    return ListTile(
                      title: Text(data['customer_name'] ?? '-'),
                      subtitle: Text(
                          'Tanggal: ${date.toLocal().toString().split(' ')[0]} ${date.toLocal().toString().split(' ')[1].split('.')[0]}'),
                      trailing: Text('Rp ${total.toStringAsFixed(0)}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionDetailScreen(
                                transactionId: transactions[index].id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}