import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_demantos/models/sale_item_model.dart';
import 'package:pos_demantos/models/sale_transaction_model.dart';
import 'package:pos_demantos/provider/cart_provider.dart';
import 'package:pos_demantos/services/sale_service.dart'; // Diperlukan jika SaleService digunakan di tempat lain
import 'package:pos_demantos/services/printer_manager_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

// Asumsi: Enum PrinterStatus didefinisikan di printer_manager_service.dart
// Asumsi: StartTransactionDialog.show() tersedia

class OrderConfirmationPageUpdated extends StatefulWidget {
  final List<SaleItem> orderItems;
  final String? tableNumber;
  final String? customerName;
  final double totalAmount;

  const OrderConfirmationPageUpdated({
    Key? key,
    required this.orderItems,
    this.tableNumber,
    this.customerName,
    required this.totalAmount,
  }) : super(key: key);

  @override
  State<OrderConfirmationPageUpdated> createState() =>
      _OrderConfirmationPageUpdatedState();
}

class _OrderConfirmationPageUpdatedState
    extends State<OrderConfirmationPageUpdated> {
  final SaleService _saleService = SaleService(); // Jika tidak terpakai, bisa dihapus
  final PrinterManagerService _printerService = PrinterManagerService();
  final TextEditingController _cashPaidController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  // Variabel State
  String _paymentMethod = 'tunai';
  double _cashPaid = 0.0;
  double _changeGiven = 0.0;
  bool _isProcessing = false;
  PrinterStatus _printerStatus = PrinterStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _cashPaidController.addListener(_updateChange);
    _initializePrinterStatus();
  }

  // --- PRINTER STATUS & INIT ---
  void _initializePrinterStatus() {
    // Ambil status awal
    _printerStatus = _printerService.currentStatus;

    // Listen to printer status changes
    _printerService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _printerStatus = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _cashPaidController.dispose();
    super.dispose();
  }

  // --- LOGIC PERHITUNGAN ---
  void _updateChange() {
    setState(() {
      _cashPaid = double.tryParse(_cashPaidController.text) ?? 0.0;
      _changeGiven = _cashPaid - widget.totalAmount;
    });
  }
  
  // Menghitung total kuantitas item yang dipesan
  int _getTotalItemCount() {
    return widget.orderItems.fold(0, (sum, item) => sum + item.quantity);
  }

  // --- LOGIC PEMROSESAN TRANSAKSI ---
  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });
    
    // Validasi pembayaran tunai
    if (_paymentMethod == 'tunai' && _changeGiven < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uang tunai yang diberikan tidak cukup.')),
          );
        }
        setState(() => _isProcessing = false);
        return;
    }

    try {
      // 1️⃣ Buat objek transaksi
      final transaction = SaleTransaction(
        id: const Uuid().v4(),
        totalAmount: widget.totalAmount,
        paymentMethod: _paymentMethod,
        transactionDate: Timestamp.fromDate(DateTime.now()), 
        tableNumber: widget.tableNumber,
        customerName: widget.customerName,
        cashPaid: _cashPaid,
        changeGiven: _changeGiven,
        userId: currentUser?.uid ?? 'unknown_user',
        lastSyncAt: DateTime.now().toIso8601String(),
      );

      // 2️⃣ Buat reference Firestore (ke collection BARU)
      final transactionRef = FirebaseFirestore.instance
          .collection('sales_transactions_baru')
          .doc(transaction.id);

      // 3️⃣ Simpan dokumen transaksi utama
      await transactionRef.set(transaction.toFirestoreMap());

      // 4️⃣ Simpan semua sale items di subcollection
      final items = widget.orderItems.map((sale) {
        return sale.copyWith(
          id: '${transaction.id}_${sale.menuItemId}_${DateTime.now().millisecondsSinceEpoch}', // ID yang lebih unik
          transactionId: transaction.id,
          totalPrice: sale.unitPrice * sale.quantity,
          createdAt: DateTime.now(),
        );
      }).toList();

      final batch = FirebaseFirestore.instance.batch();
      for (var item in items) {
        final itemRef = transactionRef.collection('sale_items').doc(item.id);
        batch.set(itemRef, item.toFirestoreMap());
      }
      await batch.commit();

      // 5️⃣ Reset cart HANYA setelah transaksi sukses
      final cart = Provider.of<CartProvider>(context, listen: false);
      cart.clear();

      // 6️⃣ LOGIKA PENCETAKAN DAN POP-UP SUKSES
      bool printSuccess = false;
      String printMessage;

      if (_printerService.currentStatus == PrinterStatus.ready) {
          // TUNGGU SAMPAI PENCETAKAN SELESAI
          printSuccess = await _printReceipt(transaction, items);
          printMessage = printSuccess 
              ? 'Struk berhasil dicetak ✅' 
              : 'Gagal mencetak struk. Transaksi berhasil disimpan.';
      } else {
          // Status printer tidak siap
          printMessage = 'Gagal mencetak struk (Printer ${_getPrinterStatusText().toLowerCase()}).';
          printSuccess = false;
      }

      // Tampilkan dialog sukses HANYA SETELAH PENCETAKAN SELESAI
      await _showSuccessDialog(
          printSuccess,
          printMessage,
          transaction.id
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  // Fungsi yang hanya mengirim data ke service dan mengembalikan status cetak
  Future<bool> _printReceipt(
    SaleTransaction transaction,
    List<SaleItem> items,
  ) async {
    try {
      // Panggil _convertOrderItemsForPrint() untuk mendapatkan MAP data yang siap cetak.
      final printData = _convertOrderItemsForPrint(); 

      // Panggil service cetak
      bool success = await _printerService.printReceipt(printData); // Mengembalikan boolean
      
      return success; 
    } catch (e) {
      debugPrint("❌ Gagal cetak struk: $e");
      return false;
    }
  }

  // --- UI DIALOG ---
  Future<void> _showSuccessDialog(
      bool printSuccess, String printMessage, String transactionId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600]),
              const SizedBox(width: 8),
              const Text('Pembayaran Berhasil'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total: Rp ${NumberFormat.decimalPattern('id_ID').format(widget.totalAmount)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (_paymentMethod == 'tunai') ...[
                Text('Tunai: Rp ${NumberFormat.decimalPattern('id_ID').format(_cashPaid)}'),
                Text('Kembalian: Rp ${NumberFormat.decimalPattern('id_ID').format(_changeGiven)}'),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    printSuccess ? Icons.print : Icons.print_disabled,
                    color: printSuccess ? Colors.green[600] : Colors.red[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      printMessage,
                      style: TextStyle(
                        color:
                            printSuccess ? Colors.green[600] : Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (!printSuccess && _printerStatus != PrinterStatus.ready) ...[
                const SizedBox(height: 8),
                Text(
                  'Transaksi telah disimpan. Anda dapat mencetak ulang dari menu laporan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!printSuccess && _printerStatus != PrinterStatus.ready)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _printerService.retryConnection();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Mencoba menghubungkan printer...')),
                    );
                  }
                },
                child: const Text('Retry Print'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Tutup dialog
                // Pop halaman OrderConfirmationPage dan kirim hasil 'true'
                Navigator.of(context).pop(true); // Kembali ke POSScreen & memicu dialog baru
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Selesai'),
            ),
          ],
        );
      },
    );
  }

  // Fungsi yang menyiapkan data item untuk dikirim ke PrinterManagerService
  Map<String, dynamic> _convertOrderItemsForPrint() {
    List<Map<String, dynamic>> printData = [];

    for (var sale in widget.orderItems) {
      printData.add({
        'title': sale.itemName,
        'price': sale.unitPrice,
        'qty': sale.quantity,
      });
    }

    return {
      'items': printData,
      'total': widget.totalAmount,
      'cashPaid': _cashPaid,
      'changeGiven': _changeGiven,
      'paymentMethod': _paymentMethod,
      'tableNumber': widget.tableNumber,
      'customerName': widget.customerName,
      'totalItemsCount': _getTotalItemCount(), // TAMBAHAN: Jumlah total item
    };
  }

  // --- HELPER UI ---
  String _getPrinterStatusText() {
    switch (_printerStatus) {
      case PrinterStatus.ready: return "Ready";
      case PrinterStatus.searching: return "Searching";
      case PrinterStatus.connecting: return "Connecting";
      case PrinterStatus.printing: return "Printing";
      case PrinterStatus.notFound: return "Not Found";
      case PrinterStatus.connectionFailed: return "Failed";
      case PrinterStatus.bluetoothOff: return "BT Off";
      case PrinterStatus.bluetoothUnavailable: return "No BT";
      case PrinterStatus.error: return "Error";
      default: return "Offline";
    }
  }

  Color _getPrinterStatusColor() {
    switch (_printerStatus) {
      case PrinterStatus.ready: return Colors.green;
      case PrinterStatus.searching:
      case PrinterStatus.connecting:
      case PrinterStatus.printing: return Colors.orange;
      default: return Colors.red;
    }
  }

  IconData _getPrinterStatusIcon() {
    switch (_printerStatus) {
      case PrinterStatus.ready: return Icons.print;
      case PrinterStatus.searching:
      case PrinterStatus.connecting: return Icons.bluetooth_searching;
      case PrinterStatus.printing: return Icons.print;
      default: return Icons.print_disabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Pembayaran', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // Printer Status Indicator (Diperbarui agar lebih ringkas)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getPrinterStatusColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getPrinterStatusColor()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getPrinterStatusIcon(), size: 16, color: _getPrinterStatusColor()),
                const SizedBox(width: 4),
                Text(_getPrinterStatusText(), style: TextStyle( fontSize: 12, color: _getPrinterStatusColor(), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Printer Warning Banner (Diperbarui)
          if (_printerStatus != PrinterStatus.ready)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[800], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Printer ${_getPrinterStatusText().toLowerCase()}. Transaksi tersimpan, struk tidak dicetak.',
                      style: TextStyle( color: Colors.orange[800], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _printerService.retryConnection(),
                    child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Order Summary Header (Lebih Rapi)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ringkasan Pesanan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    // TAMBAHAN: Tampilkan Jumlah Item
                    Text('Total Item: ${_getTotalItemCount()}', style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.tableNumber != null)
                      Row(
                        children: [
                          const Icon(Icons.table_restaurant, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text('Meja: ${widget.tableNumber}', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    if (widget.customerName != null)
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text('Pelanggan: ${widget.customerName}', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Order Items List (Lebih Ringkas)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: widget.orderItems.length,
              itemBuilder: (context, index) {
                final SaleItem sale = widget.orderItems[index];
                final String itemName = sale.itemName;
                final int quantity = sale.quantity;
                final double totalItemPrice = sale.totalPrice;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kuantitas
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue, width: 0.5)
                        ),
                        child: Text('$quantity x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                      ),
                      const SizedBox(width: 10),
                      // Item details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(itemName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            Text('Rp ${NumberFormat.decimalPattern('id_ID').format(sale.unitPrice)} / unit', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                      // Total price
                      Text('Rp ${NumberFormat.decimalPattern('id_ID').format(totalItemPrice)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                );
              },
            ),
          ),

          // Payment Section (Footer)
          Container(
            padding: const EdgeInsets.all(10.1),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                const BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL TAGIHAN:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Rp ${NumberFormat.decimalPattern('id_ID').format(widget.totalAmount)}', style: const TextStyle( fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
                const SizedBox(height: 16),

                // Payment Method
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration( 
                    labelText: 'Metode Pembayaran', 
                    prefixIcon: Icon(Icons.payment),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'tunai', child: Text('Tunai')),
                    DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _paymentMethod = value ?? 'tunai';
                      // Reset cash paid saat ganti metode
                      if (_paymentMethod != 'tunai') {
                          _cashPaidController.clear();
                      }
                    });
                  },
                ),

                if (_paymentMethod == 'tunai') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cashPaidController,
                    decoration: const InputDecoration( 
                      labelText: 'Uang Diterima', 
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))), 
                      prefixText: 'Rp ',
                      suffixText: 'Wajib Diisi'
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kembalian:', style: TextStyle(fontSize: 16)),
                      Text(
                        'Rp ${NumberFormat.decimalPattern('id_ID').format(_changeGiven)}', 
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _changeGiven >= 0 ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ],

                if (_paymentMethod == 'qris') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code, color: Colors.orange[700]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bayar melalui QRIS. Total: Rp ${NumberFormat.decimalPattern('id_ID').format(widget.totalAmount)}',
                            style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Pay Button (Lebih Menonjol)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing || (_paymentMethod == 'tunai' && _changeGiven < 0) ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: _isProcessing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Memproses Transaksi...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getPrinterStatusIcon(), size: 22),
                              const SizedBox(width: 10),
                              Text(
                                _paymentMethod == 'tunai'
                                    ? 'Bayar & Cetak'
                                    : 'Bayar QRIS & Cetak',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}