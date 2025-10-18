import 'package:flutter/material.dart';
import '../models/sale_item_model.dart';

class CartProvider extends ChangeNotifier {
  final List<SaleItem> _items = [];
  String? _customerName;
  String? _tableNumber;

  // Getter untuk items
  List<SaleItem> get items => List.unmodifiable(_items);
  
  // Getter totalAmount (Hanya satu definisi yang diperlukan)
  @override
  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  // Getter dan setter untuk info customer/meja
  String? get customerName => _customerName;
  String? get tableNumber => _tableNumber;

  void setCustomerInfo({String? customerName, String? tableNumber}) {
    _customerName = customerName;
    _tableNumber = tableNumber;
    notifyListeners();
  }

  // 1. Metode untuk MENAMBAH KUANTITAS (Increment)
  void incrementItemQuantity(String itemId) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      final item = _items[index];
      // Buat item baru dengan kuantitas yang bertambah
      _items[index] = item.copyWith(
        quantity: item.quantity + 1,
        // Hitung ulang total harga untuk item ini
        totalPrice: (item.unitPrice * (item.quantity + 1)),
      );
      notifyListeners();
    }
  }

  // 2. Metode untuk MENGURANGI KUANTITAS (Decrement/Remove by One)
  void removeItemByOne(String itemId) {
    final index = _items.indexWhere((item) => item.id == itemId);

    if (index >= 0) {
      final item = _items[index];
      if (item.quantity > 1) {
        // Jika kuantitas > 1, kurangi kuantitas
        _items[index] = item.copyWith(
          quantity: item.quantity - 1,
          // Hitung ulang total harga untuk item ini
          totalPrice: (item.unitPrice * (item.quantity - 1)),
        );
      } else {
        // Jika kuantitas = 1, hapus item tersebut dari daftar
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  // Tambah item ke cart
  void addItem(SaleItem item) {
    // Coba temukan item yang sudah ada di keranjang dengan ID unik yang sama.
    // Ini penting agar item yang sama namun dengan OPSI yang berbeda tidak digabung.
    final index = _items.indexWhere((i) => i.id == item.id);
    
    if (index >= 0) {
      final existing = _items[index];
      
      // Jika item sudah ada, cek apakah item baru memiliki ID unik yang sama
      // Jika ya, tambahkan kuantitasnya
      _items[index] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
        totalPrice: existing.totalPrice + item.totalPrice,
      );
    } else {
      // Jika item belum ada (atau memiliki ID unik baru/opsi baru), tambahkan
      _items.add(item);
    }
    notifyListeners();
  }
  
  // Hapus item berdasarkan id (menghapus item sepenuhnya)
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // Clear cart, tapi bisa pilih reset info customer/meja atau tidak
  void clearCart({bool resetCustomerInfo = true}) {
    _items.clear();
    if (resetCustomerInfo) {
      _customerName = null;
      _tableNumber = null;
    }
    notifyListeners();
  }

  // Reset transaksi baru: clear cart + update info customer/meja baru
  void startNewTransaction({String? customerName, String? tableNumber}) {
    clearCart(resetCustomerInfo: true);
    setCustomerInfo(customerName: customerName, tableNumber: tableNumber);
  }

  // Alias untuk clearCart, digunakan di order_confirmation_page.dart
  void clear() {
    _items.clear();
    notifyListeners();
  }
}