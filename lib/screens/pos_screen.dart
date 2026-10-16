import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_demantos/models/category_model.dart';
import 'package:pos_demantos/models/menu_item_model.dart';
import 'package:pos_demantos/models/menu_option_model.dart';
import 'package:pos_demantos/models/sale_item_model.dart';
import 'package:pos_demantos/provider/cart_provider.dart';
import 'package:pos_demantos/screens/order_confirmation_page.dart';
import 'package:pos_demantos/screens/start_transaction_dialog.dart';
import 'package:pos_demantos/services/menu_service.dart';
import 'package:provider/provider.dart';

// Asumsi: Model Category, MenuItem, MenuOption, SaleItem, CartProvider, 
// OrderConfirmationPageUpdated, StartTransactionDialog, dan MenuService sudah ada.

class POSScreen extends StatefulWidget {
  final String? tableNumber;
  final String? customerName;

  const POSScreen({
    super.key,
    this.tableNumber,
    this.customerName,
  });

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final MenuService _menuService = MenuService();

  // --- CACHING GLOBAL (INTERNAL) ---
  // Variabel caching statis dihapus karena logikanya sudah dipindahkan ke MenuService
  // dan _menuService.loadAllDataGlobally() seharusnya menangani caching.

  // --- STATE LOKAL ---
  List<Category> _categories = [];
  Category? _selectedCategory;
  List<MenuItem> _menuItems = [];
  List<MenuItem> _allMenuItems = []; // Store all menu items for search
  bool _isLoading = false;
  String? _errorMessage;

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<MenuItem> _searchResults = [];
  Timer? _debounce; // <--- DEBOUNCER

  // Bill container height
  double _billContainerHeight = 180.0;
  final double _minBillHeight = 150.0;
  final double _maxBillHeight = 325.0;

  @override
  void initState() {
    super.initState();
    _billContainerHeight =
        _billContainerHeight.clamp(_minBillHeight, _maxBillHeight);

    // Memuat data secara kondisional
    _loadInitialData();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // Batalkan timer debounce
    super.dispose();
  }

  // --- LOGIC SEARCH & DATA LOADING (TIDAK BERUBAH SIGNIFIKAN) ---

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.toLowerCase().trim();

      if (query.isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
        });
        return;
      }

      setState(() {
        _isSearching = true;
        _searchResults = _performAdvancedSearch(query);
      });
    });
  }

  List<MenuItem> _performAdvancedSearch(String query) {
    return _allMenuItems.where((item) {
      return _itemMatchesQuery(item, query);
    }).toList()
      ..sort((a, b) {
        int scoreA = _calculateRelevanceScore(a, query);
        int scoreB = _calculateRelevanceScore(b, query);
        return scoreB.compareTo(scoreA);
      });
  }

  bool _itemMatchesQuery(MenuItem item, String query) {
    final lowerQuery = query.toLowerCase();

    if (item.name.toLowerCase().contains(lowerQuery)) return true;
    if (item.description != null &&
        item.description!.toLowerCase().contains(lowerQuery)) return true;

    final category = _categories.firstWhere(
      (cat) => cat.id == item.categoryId,
      orElse: () => Category(id: '', name: ''),
    );
    if (category.name.toLowerCase().contains(lowerQuery)) return true;

    if (item.options != null) {
      for (var option in item.options!) {
        if (option.name.toLowerCase().contains(lowerQuery) ||
            option.type.toLowerCase().contains(lowerQuery)) return true;
      }
    }

    return false;
  }

  int _calculateRelevanceScore(MenuItem item, String query) {
    int score = 0;
    final lowerQuery = query.toLowerCase();

    if (item.name.toLowerCase() == lowerQuery)
      score += 100;
    else if (item.name.toLowerCase().startsWith(lowerQuery))
      score += 80;
    else if (item.name.toLowerCase().contains(lowerQuery)) score += 60;

    if (item.description != null &&
        item.description!.toLowerCase().contains(lowerQuery)) score += 40;

    final category = _categories.firstWhere(
      (cat) => cat.id == item.categoryId,
      orElse: () => Category(id: '', name: ''),
    );
    if (category.name.toLowerCase().contains(lowerQuery)) score += 30;

    if (item.options != null) {
      for (var option in item.options!) {
        if (option.name.toLowerCase().contains(lowerQuery)) score += 20;
        if (option.type.toLowerCase().contains(lowerQuery)) score += 15;
      }
    }

    if (item.isAvailable) score += 10;

    return score;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults.clear();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Panggil fungsi di Service. Service yang akan memutuskan apakah menggunakan cache atau Firestore.
      await _menuService.loadAllDataGlobally();

      // 2. Ambil data dari cache service setelah dimuat
      _categories = _menuService.getAllCategories();
      _allMenuItems = _menuService.getAllItems();

      // 3. Terapkan filter kategori awal
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
        _menuItems = _allMenuItems
            .where((item) => item.categoryId == _selectedCategory!.id)
            .toList();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data menu: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMenuItems(String categoryId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Filtering dari data yang sudah ada di memori
    final items =
        _allMenuItems.where((item) => item.categoryId == categoryId).toList();

    // Perbarui state lokal
    setState(() {
      _menuItems = items;
      _isLoading = false;
    });
  }

  Future<void> _refreshData() async {
    // Memaksa service untuk memuat ulang data dari Firestore
    _menuService.clearCache(); 
    await _loadInitialData();
  }

  // --- LOGIC CART & DIALOG (TIDAK BERUBAH) ---

  void _addItemToOrder(MenuItem item, {List<MenuOption>? selectedOptions}) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    double itemPrice = item.price;
    String optionText = '';
    if (selectedOptions != null) {
      for (var option in selectedOptions) {
        itemPrice += option.priceAdjustment;
        optionText += '${option.name}, ';
      }
      if (optionText.isNotEmpty) {
        optionText = optionText.substring(0, optionText.length - 2);
      }
    }

    cart.addItem(
      SaleItem(
        id: UniqueKey().toString(),
        transactionId: '',
        menuItemId: item.id,
        itemName:
            '${item.name} ${optionText.isNotEmpty ? "($optionText)" : ""}',
        quantity: 1,
        unitPrice: itemPrice,
        totalPrice: itemPrice,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _showMenuOptionDialog(MenuItem item) async {
    if (item.options == null || item.options!.isEmpty) {
      _addItemToOrder(item);
      return;
    }

    List<MenuOption> _selectedOptionsForDialog = [];
    String? _selectedSizeId;
    String? _selectedTemperatureId;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final List<MenuOption> sizeOptions =
                item.options!.where((o) => o.type == 'size').toList();
            final List<MenuOption> tempOptions =
                item.options!.where((o) => o.type == 'temperature').toList();

            return AlertDialog(
              title: Text('Pilih Opsi untuk ${item.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sizeOptions.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedSizeId,
                      hint: const Text('Ukuran'),
                      items: sizeOptions.map((option) {
                        return DropdownMenuItem(
                          value: option.id,
                          child: Text(
                              '${option.name} (+Rp ${NumberFormat.decimalPattern('id_ID').format(option.priceAdjustment)})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedSizeId = value;
                          _selectedOptionsForDialog
                              .removeWhere((o) => o.type == 'size');
                          if (value != null) {
                            _selectedOptionsForDialog.add(
                                sizeOptions.firstWhere((o) => o.id == value));
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 10),
                  if (tempOptions.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedTemperatureId,
                      hint: const Text('Panas/Dingin'),
                      items: tempOptions.map((option) {
                        return DropdownMenuItem(
                          value: option.id,
                          child: Text(option.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedTemperatureId = value;
                          _selectedOptionsForDialog
                              .removeWhere((o) => o.type == 'temperature');
                          if (value != null) {
                            _selectedOptionsForDialog.add(tempOptions
                                .firstWhere((o) => o.id == value));
                          }
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addItemToOrder(item,
                        selectedOptions: _selectedOptionsForDialog);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Tambahkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FUNGSI _buildMenuGrid (TIDAK BERUBAH) ---

  Widget _buildMenuGrid(List<MenuItem> items) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65, // Dibuat lebih tinggi agar item terlihat
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: item.isAvailable ? () => _showMenuOptionDialog(item) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.grey[200],
                    child: Stack(
                      children: [
                        Center(
                          child:
                              item.imageUrl != null && item.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      item.imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  : const Icon(Icons.restaurant_menu,
                                      size: 40, color: Colors.grey),
                        ),
                        if (!item.isAvailable)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Text(
                                'HABIS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)), // Sedikit diperbesar
                        const Spacer(),
                        Text('Rp ${NumberFormat.decimalPattern('id_ID').format(item.price)}',
                            style: TextStyle(
                                fontSize: 12, // Sedikit diperbesar
                                fontWeight: FontWeight.w700,
                                color: item.isAvailable
                                    ? Colors.green[700]
                                    : Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI BUILDER (MODERNISASI APLIKASI) ---

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem POS', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blue[700], // Biru yang lebih dalam
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: Column(
        children: [
          // Header: customer info + search + kategori
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white, // Pindahkan warna latar ke body jika perlu
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Pelanggan
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      if (widget.tableNumber != null) ...[
                        Icon(Icons.table_restaurant, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text("Meja: ${widget.tableNumber}", style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                      ],
                      if (widget.customerName != null) ...[
                        const Icon(Icons.person, size: 18, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text("Pelanggan: ${widget.customerName}", style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Cari menu...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100], // Warna isian yang lebih kalem
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none), // Borderless look
                  ),
                ),
                const SizedBox(height: 12),

                // Kategori dengan ChoiceChip (Modernisasi)
                if (!_isSearching && _categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = cat.id == _selectedCategory?.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat.name, 
                              style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87, 
                                  fontWeight: FontWeight.w500
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.blue[700], // Warna chip saat dipilih
                            backgroundColor: Colors.grey[200],
                            onSelected: (_) {
                              if (!isSelected) { // Cegah reload jika kategori sama
                                setState(() => _selectedCategory = cat);
                                _loadMenuItems(cat.id);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Menu grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      )
                    : _isSearching
                        ? _buildMenuGrid(_searchResults)
                        : _buildMenuGrid(_menuItems),
          ),

          // Divider draggable
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _billContainerHeight -= details.delta.dy;
                _billContainerHeight =
                    _billContainerHeight.clamp(_minBillHeight, _maxBillHeight);
              });
            },
            child: Container(
              height: 8,
              color: Colors.grey[300],
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          // Bill container
          Container(
            height: _billContainerHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header Keranjang
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange[50], // Warna yang lebih lembut
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Keranjang",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        "Total: Rp ${NumberFormat.decimalPattern('id_ID').format(cart.totalAmount)}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: cart.items.isEmpty
                      ? Center(
                          child: Text("Keranjang kosong. Silahkan tambahkan menu.",
                            style: TextStyle(color: Colors.grey[600])),
                        )
                      : ListView.builder(
                          itemCount: cart.items.length,
                          itemBuilder: (context, i) {
                            final item = cart.items[i];
                            return ListTile(
                              title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                              subtitle: Text("Rp ${NumberFormat.decimalPattern('id_ID').format(item.unitPrice)} / pcs", style: const TextStyle(fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // TOMBOL KURANG (DECREMENT)
                                  IconButton(
                                    icon: Icon(
                                      item.quantity > 1
                                          ? Icons.remove_circle_outline
                                          : Icons.delete,
                                      color: item.quantity > 1
                                          ? Colors.orange
                                          : Colors.red,
                                    ),
                                    onPressed: () {
                                      cart.removeItemByOne(item.id);
                                    },
                                  ),
                                  // KUANTITAS
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    constraints: const BoxConstraints(minWidth: 24),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  // TOMBOL TAMBAH (INCREMENT)
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        color: Colors.green),
                                    onPressed: () {
                                      cart.incrementItemQuantity(item.id);
                                    },
                                  ),
                                  // TOTAL HARGA ITEM
                                  const SizedBox(width: 8),
                                  Text(
                                    "Rp ${NumberFormat.decimalPattern('id_ID').format(item.totalPrice)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                // Tombol Checkout (MODERNISASI)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700], // Warna Aksi yang kuat
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // Sudut membulat
                      ),
                      minimumSize: const Size(double.infinity, 50),
                      elevation: 5,
                    ),
                    onPressed: cart.items.isEmpty
                        ? null
                        : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderConfirmationPageUpdated(
                                  orderItems: List<SaleItem>.from(cart.items),
                                  customerName: widget.customerName,
                                  totalAmount: cart.totalAmount,
                                  tableNumber: widget.tableNumber,
                                ),
                              ),
                            );

                            if (result == true) {
                              StartTransactionDialog.show(context);
                            }
                          },
                    child: Text(
                      "Checkout (Rp ${NumberFormat.decimalPattern('id_ID').format(cart.totalAmount)})", // Tampilkan total di tombol
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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