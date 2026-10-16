import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_demantos/models/sale_transaction_model.dart';
import 'package:pos_demantos/models/sale_item_model.dart';
import 'package:pos_demantos/services/printer_manager_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  _TransactionDetailScreenState createState() => _TransactionDetailScreenState();
}

// di transaction_detail_screen.dart

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  String searchItem = ''; // Variabel state untuk filtering item
  final PrinterManagerService _printerService = PrinterManagerService();
  bool _isPrinting = false;

  Future<void> _reprintReceipt(SaleTransaction transaction, List<SaleItem> items) async {
    // Cek status printer
    if (_printerService.currentStatus != PrinterStatus.ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer tidak siap. Coba sambungkan ulang.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() { _isPrinting = true; }); // Tampilkan loading

    try {
      // Siapkan data untuk printer service (mirip _convertOrderItemsForPrint)
      final printData = {
          'transaction': transaction.toFirestoreMap(), // Kirim data transaksi lengkap
          'items': items.map((item) => { // Konversi SaleItem ke format Map sederhana untuk service
                'title': item.itemName,
                'price': item.unitPrice,
                'qty': item.quantity,
              }).toList(),
          // Data lain bisa diambil dari objek transaction jika diperlukan di service
          'total': transaction.totalAmount,
          'cashPaid': transaction.cashPaid,
          'changeGiven': transaction.changeGiven,
          'paymentMethod': transaction.paymentMethod,
          'tableNumber': transaction.tableNumber,
          'customerName': transaction.customerName,
      };

      // Panggil service cetak
      bool success = await _printerService.printReceipt(printData);

      // Tampilkan hasil
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Struk berhasil dicetak ulang.' : 'Gagal mencetak struk.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saat mencetak: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
        if(mounted) {
          setState(() { _isPrinting = false; }); // Sembunyikan loading
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hanya inisialisasi reference ke collection BARU (Karena collection lama dihapus)
    final DocumentReference transactionDocRef = FirebaseFirestore.instance
        .collection('sales_transactions_baru') // <--- HANYA COLLECTION BARU
        .doc(widget.transactionId);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        actions: [
          // 4. TAMBAHKAN TOMBOL PRINT DI APPBAR
          // Tombol ini akan aktif hanya jika FutureBuilder selesai memuat data transaksi
          FutureBuilder<DocumentSnapshot>(
            future: transactionDocRef.get(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                // Tampilkan tombol jika data ada
                return IconButton(
                  icon: _isPrinting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.print),
                  onPressed: _isPrinting ? null : () async {
                    // Ambil data item dari StreamBuilder di bawah (perlu cara untuk mengaksesnya)
                    // Cara termudah: Ambil ulang data item saat tombol ditekan
                    final itemsSnapshot = await transactionDocRef.collection('sale_items').get();
                    final saleItems = itemsSnapshot.docs.map((doc) => SaleItem.fromFirestoreMap(doc.data())).toList();
                    
                    // Ambil data transaksi dari snapshot FutureBuilder
                    final saleTransaction = SaleTransaction.fromFirestoreMap(snapshot.data!.data() as Map<String, dynamic>);
                    
                    // Panggil fungsi reprint
                    _reprintReceipt(saleTransaction, saleItems); 
                  },
                  tooltip: 'Cetak Ulang Struk',
                );
              } else {
                // Jangan tampilkan tombol jika data belum ada atau error
                return const SizedBox.shrink(); 
              }
            }
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // Hanya panggil get() pada reference baru
        future: transactionDocRef.get(), 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Transaksi tidak ditemukan'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final saleTransaction = SaleTransaction.fromFirestoreMap(data);
          final transactionDate = saleTransaction.transactionDate.toDate();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BAGIAN DETAIL TRANSAKSI UTAMA (DIKEMBALIKAN)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID Transaksi: ${widget.transactionId}', 
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Tanggal: ${transactionDate.toLocal().toString().split('.')[0]}'), 
                    Text('Pelanggan: ${saleTransaction.customerName ?? '-'}'), 
                    Text('Metode Pembayaran: ${saleTransaction.paymentMethod}'),
                    const SizedBox(height: 12),
                    Text('Total: Rp ${NumberFormat.decimalPattern('id_ID').format(saleTransaction.totalAmount)}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)), 
                    Text('Kembalian: Rp ${NumberFormat.decimalPattern('id_ID').format(saleTransaction.changeGiven)}'),
                  ],
                ),
              ),
              const Divider(),
              
              // // SEARCH BAR ITEM (DIKEMBALIKAN)
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              //   child: TextField(
              //     decoration: const InputDecoration(
              //       prefixIcon: Icon(Icons.search),
              //       hintText: 'Cari item menu...',
              //       border: OutlineInputBorder(),
              //     ),
              //     onChanged: (value) {
              //       setState(() {
              //         searchItem = value.toLowerCase();
              //       });
              //     },
              //   ),
              // ),
              
              // ITEM LIST
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: transactionDocRef.collection('sale_items').snapshots(), 
                  builder: (context, itemSnapshot) {
                    if (!itemSnapshot.hasData || itemSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Tidak ada item'));
                    }

                    final items = itemSnapshot.data!.docs.where((doc) {
                      final itemData = doc.data() as Map<String, dynamic>;
                      final saleItem = SaleItem.fromFirestoreMap(itemData);
                      return saleItem.itemName.toLowerCase().contains(searchItem);
                    }).toList();

                    if (items.isEmpty) {
                      return const Center(child: Text('Item tidak ditemukan'));
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final itemData = items[index].data() as Map<String, dynamic>;
                        final saleItem = SaleItem.fromFirestoreMap(itemData);

                        return ListTile(
                          title: Text(saleItem.itemName),
                          subtitle: Text('Qty: ${saleItem.quantity} x Rp ${NumberFormat.decimalPattern('id_ID').format(saleItem.unitPrice)}'),
                          trailing: Text('Rp ${NumberFormat.decimalPattern('id_ID').format(saleItem.totalPrice)}'),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}