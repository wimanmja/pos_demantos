import 'dart:async'; // <--- IMPORT WAJIB UNTUK TIMER
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pos_demantos/models/category_model.dart';
import 'package:pos_demantos/models/menu_item_model.dart';
import 'package:pos_demantos/models/menu_option_model.dart';
import 'package:pos_demantos/models/sale_item_model.dart';
import 'package:pos_demantos/provider/cart_provider.dart';
import 'package:pos_demantos/screens/order_confirmation_page.dart';
import 'package:pos_demantos/screens/start_transaction_dialog.dart';
import 'package:pos_demantos/services/menu_service.dart';
import 'package:provider/provider.dart';

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
  static bool _isMenuDataCached = false;
  static List<Category> _cachedCategories = [];
  static List<MenuItem> _cachedAllMenuItems = [];

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

  // Mengubah _onSearchChanged untuk menggunakan Debouncing (Koreksi error Timer)
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
        _searchResults = _performAdvancedSearch(query); // <--- Koreksi error undefined_method
      });
    });
  }

  // FUNGSI PENCARIAN ADVANCED (DIKEMBALIKAN)
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

  void _clearSearch() { // <--- Koreksi error undefined_identifier
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
  
  Future<void> _loadCategoriesFromFirestore() async {
     final snapshot =
        await FirebaseFirestore.instance.collection('categories').get();
     _categories = snapshot.docs.map((doc) => Category.fromMap(doc.data())).toList();
  }

  // Implementasi Parallel Fetching untuk item dan opsi (Opsi A)
  Future<void> _loadAllMenuItemsParallel() async {
    List<MenuItem> allItems = [];
    
    List<Future<List<MenuItem>>> itemFutures = _categories.map((category) {
      return _menuService.getMenuItemsFromFirestore(category.id);
    }).toList();

    List<List<MenuItem>> results = await Future.wait(itemFutures);
    for (var itemList in results) {
      allItems.addAll(itemList);
    }

    List<Future<List<MenuOption>>> optionFutures = allItems.map((item) {
      return _menuService.getMenuOptionsFromFirestore(item.id);
    }).toList();

    List<List<MenuOption>> optionResults = await Future.wait(optionFutures);

    List<MenuItem> itemsWithOption = [];
    for (int i = 0; i < allItems.length; i++) {
      itemsWithOption.add(allItems[i].copyWith(options: optionResults[i]));
    }

    _allMenuItems = itemsWithOption;
  }
  
  // Mengganti _loadMenuItems lama menjadi fungsi filter dari cache
  Future<void> _loadMenuItems(String categoryId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Filtering dari data yang sudah ada di memori
    final items = _allMenuItems.where((item) => item.categoryId == categoryId).toList();
    
    // Perbarui state lokal
    setState(() {
      _menuItems = items;
      _isLoading = false;
    });
  }
  
  // Fungsi refresh di AppBar memuat ulang data menu dari Firestore
  Future<void> _refreshData() async {
    _isMenuDataCached = false; // Reset cache flag untuk memicu fetch ulang
    _cachedCategories.clear();
    _cachedAllMenuItems.clear(); // Menggunakan .clear() lebih aman
    await _loadInitialData();
  }
  
  Future<void> _loadCategories() => _refreshData(); // Tombol refresh memanggil ini

  // FUNGSI _addItemToOrder (DIKEMBALIKAN)
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

  // FUNGSI _showMenuOptionDialog (DIKEMBALIKAN)
  Future<void> _showMenuOptionDialog(MenuItem item) async { // <--- Koreksi error undefined_method
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
                              '${option.name} (+Rp ${option.priceAdjustment.toStringAsFixed(0)})'),
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
                            _selectedOptionsForDialog.add(
                                tempOptions.firstWhere((o) => o.id == value));
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

  // FUNGSI _buildMenuGrid (DIKEMBALIKAN)
  Widget _buildMenuGrid(List<MenuItem> items) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
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
                                fontWeight: FontWeight.bold, fontSize: 11)),
                        const Spacer(),
                        Text('Rp ${item.price.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem POS'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _refreshData), // Menggunakan _refreshData
        ],
      ),
      body: Column(
        children: [
          // Header: customer info + search + kategori (Tidak ada perubahan di sini)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Row(
                  children: [
                    if (widget.tableNumber != null) ...[
                      const Icon(Icons.table_restaurant, size: 18),
                      const SizedBox(width: 4),
                      Text("Meja: ${widget.tableNumber}"),
                      const SizedBox(width: 12),
                    ],
                    if (widget.customerName != null) ...[
                      const Icon(Icons.person, size: 18),
                      const SizedBox(width: 4),
                      Text("Pelanggan: ${widget.customerName}"),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
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
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                if (!_isSearching)
                  DropdownButton<Category>(
                    value: _selectedCategory,
                    isExpanded: true,
                    hint: const Text("Pilih kategori"),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (cat) {
                      if (cat != null) {
                        setState(() => _selectedCategory = cat);
                        _loadMenuItems(cat.id);
                      }
                    },
                  ),
              ],
            ),
          ),

          // Menu grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                    ? _buildMenuGrid(_searchResults)
                    : _buildMenuGrid(_menuItems),
          ),

          // Divider draggable (Tidak ada perubahan)
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
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          // Bill container
          Container(
            height: _billContainerHeight,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Keranjang",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        "Total: Rp ${cart.totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, i) {
                      final item = cart.items[i];
                      return ListTile(
                        title: Text(item.itemName),
                        subtitle: Text("Rp ${item.unitPrice.toStringAsFixed(0)} / pcs"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // TOMBOL KURANG (DECREMENT)
                            IconButton(
                              icon: Icon(
                                item.quantity > 1 ? Icons.remove_circle_outline : Icons.delete,
                                color: item.quantity > 1 ? Colors.orange : Colors.red,
                              ),
                              onPressed: () {
                                cart.removeItemByOne(item.id);
                              },
                            ),
                            // KUANTITAS
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            // TOMBOL TAMBAH (INCREMENT)
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () {
                                cart.incrementItemQuantity(item.id);
                              },
                            ),
                            // TOTAL HARGA ITEM
                            const SizedBox(width: 8),
                            Text(
                              "Rp ${item.totalPrice.toStringAsFixed(0)}",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: cart.items.isEmpty
                      ? null
                      : () async {
                          // Menyimpan hasil dari navigasi
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

                          // Cek apakah hasil navigasi adalah TRUE (transaksi sukses)
                          if (result == true) {
                            StartTransactionDialog.show(context);
                          }
                        },
                  child: const Text("Checkout"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}