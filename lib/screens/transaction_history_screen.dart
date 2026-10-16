import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction_detail_screen.dart';
import 'package:intl/intl.dart';

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
    _calculateTotals(); // Pastikan ini dipanggil
  }

  // Parse tanggal transaksi
  DateTime _parseTransactionDate(dynamic transactionDate) {
    if (transactionDate is Timestamp) return transactionDate.toDate();
    return DateTime.now(); 
  }

  // Parse total amount
  double _parseTotal(dynamic totalAmount) {
    if (totalAmount is int) return totalAmount.toDouble();
    if (totalAmount is double) return totalAmount;
    if (totalAmount is String) return double.tryParse(totalAmount) ?? 0;
    return 0;
  }

  Future<void> _calculateTotals() async {
    final newRef = FirebaseFirestore.instance.collection('sales_transactions_baru');
    final now = DateTime.now();
    
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfNextYear = DateTime(now.year + 1, 1, 1); 

    try {
      final yearlySnap = await newRef
          .where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('transaction_date', isLessThan: Timestamp.fromDate(endOfNextYear))
          .get();
          
      final allDocs = yearlySnap.docs; 

      double dailyTotal = 0;
      double monthlyTotal = 0;
      double yearlyTotal = 0;
      final today = DateTime(now.year, now.month, now.day);
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (var doc in allDocs) {
          final data = doc.data();
          final total = _parseTotal(data['total_amount']);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOMBOL FILTER TANGGAL
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
                // Tombol Reset Filter (Opsional tapi berguna)
                if (selectedDateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() => selectedDateRange = null),
                  )
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 2. TAMPILAN TOTAL GLOBAL (Selalu Tampil)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Hari Ini: Rp ${NumberFormat.decimalPattern('id_ID').format(totalToday)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('Total Bulan Ini: Rp ${NumberFormat.decimalPattern('id_ID').format(totalMonth)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('Total Tahun Ini: Rp ${NumberFormat.decimalPattern('id_ID').format(totalYear)}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          const Divider(height: 24, thickness: 1),

          // 3. LIST TRANSAKSI & HASIL FILTER DINAMIS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                Query transactionsQuery = FirebaseFirestore.instance
                    .collection('sales_transactions_baru')
                    .orderBy('transaction_date', descending: true);
                
                if (selectedDateRange != null) {
                  final startDate = selectedDateRange!.start;
                  final endDate = selectedDateRange!.end.add(const Duration(days: 1)); 

                  transactionsQuery = transactionsQuery
                      .where('transaction_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                      .where('transaction_date', isLessThan: Timestamp.fromDate(endDate)); 
                }
                return transactionsQuery.snapshots();
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error memuat data: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Tidak ada transaksi'));
                }

                final transactions = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final customerNameStr = (data['customer_name'] ?? '').toString().toLowerCase();
                  return customerNameStr.contains(searchCustomer);
                }).toList();

                if (transactions.isEmpty) {
                  return const Center(child: Text('Transaksi tidak ditemukan'));
                }

                // Hitung total dari transaksi yang tampil di list (berguna saat difilter)
                double filteredTotal = transactions.fold(0.0, (sum, doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return sum + _parseTotal(data['total_amount']);
                });
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HANYA TAMPIL JIKA FILTER TANGGAL AKTIF
                    if (selectedDateRange != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                        child: Text(
                          'Total Hasil Filter: Rp ${NumberFormat.decimalPattern('id_ID').format(filteredTotal)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                        ),
                      ),
                      
                    Expanded(
                      child: ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final data = transactions[index].data() as Map<String, dynamic>;
                          final date = _parseTransactionDate(data['transaction_date']);
                          final total = _parseTotal(data['total_amount']);

                          return ListTile(
                            title: Text(data['customer_name'] ?? 'Pelanggan Umum'),
                            subtitle: Text(
                                'Tanggal: ${date.toLocal().toString().split(' ')[0]} ${date.toLocal().toString().split(' ')[1].split('.')[0]}'),
                            trailing: Text('Rp ${NumberFormat.decimalPattern('id_ID').format(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      )
    );
  }
}