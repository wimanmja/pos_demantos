import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_demantos/models/sale_transaction_model.dart';
import 'package:pos_demantos/models/sale_item_model.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  _TransactionDetailScreenState createState() => _TransactionDetailScreenState();
}

// di transaction_detail_screen.dart

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  String searchItem = ''; // Variabel state untuk filtering item

  @override
  Widget build(BuildContext context) {
    // Hanya inisialisasi reference ke collection BARU (Karena collection lama dihapus)
    final DocumentReference transactionDocRef = FirebaseFirestore.instance
        .collection('sales_transactions_baru') // <--- HANYA COLLECTION BARU
        .doc(widget.transactionId);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
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
                    Text('Total: Rp ${saleTransaction.totalAmount.toStringAsFixed(0)}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)), 
                    Text('Kembalian: Rp ${saleTransaction.changeGiven.toStringAsFixed(0)}'),
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
                          subtitle: Text('Qty: ${saleItem.quantity} x Rp ${saleItem.unitPrice.toStringAsFixed(0)}'),
                          trailing: Text('Rp ${saleItem.totalPrice.toStringAsFixed(0)}'),
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