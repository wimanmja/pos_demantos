import 'package:flutter/material.dart';
import 'package:pos_demantos/models/category_model.dart';
import 'package:pos_demantos/models/menu_item_model.dart';
import 'package:pos_demantos/models/menu_option_model.dart';
import 'package:pos_demantos/services/menu_service.dart';
import 'package:uuid/uuid.dart';

class MenuManagementScreen extends StatefulWidget {
 const MenuManagementScreen({super.key});

 @override
 State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
 final MenuService _menuService = MenuService();
 List<Category> _categories = [];
 Category? _selectedCategory;
 List<MenuItem> _menuItems = [];
 List<MenuItem> _filteredMenuItems = []; 
 bool _isLoading = false;
 String? _errorMessage;
 final Uuid _uuid = const Uuid();
 String _searchQuery = ''; 

 @override
 void initState() {
  super.initState();
  _loadCategories();
 }

// ------------------------------------------------------------------
// LOGIKA UTAMA (FUNGSI ASYNCHRONOUS) - SEMUA FUNGSI HARUS ADA DI SINI
// ------------------------------------------------------------------

 void _filterMenuItems(String query) {
  setState(() {
   _searchQuery = query.toLowerCase();
   if (_searchQuery.isEmpty) {
    _filteredMenuItems = _menuItems;
   } else {
    _filteredMenuItems = _menuItems.where((item) {
     return item.name.toLowerCase().contains(_searchQuery);
    }).toList();
   }
  });
 }

 Future<void> _loadCategories() async {
  setState(() {
   _isLoading = true;
   _errorMessage = null;
  });
  try {
   final categories = await _menuService.getCategoriesFromFirestore();
    
   setState(() {
    _categories = categories;

    if (categories.isEmpty) {
     _selectedCategory = null;
    } else {
     Category? foundCategory;

     if (_selectedCategory != null) {
      try {
       foundCategory = categories.firstWhere(
        (cat) => cat.id == _selectedCategory!.id,
       );
      } catch (_) {
       foundCategory = null;
      }
     }
     
     _selectedCategory = foundCategory ?? categories.first;
    }

    if (_selectedCategory != null) {
     _loadMenuItems(_selectedCategory!.id);
    } else {
     _menuItems = [];
     _filteredMenuItems = [];
     _searchQuery = '';
    }
   });
  } catch (e) {
   setState(() {
    _errorMessage = 'Gagal memuat kategori: ${e.toString()}';
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
   _menuItems = [];
   _filteredMenuItems = []; 
  });
  try {
   final items = await _menuService.getMenuItemsFromFirestore(categoryId);
   setState(() {
    _menuItems = items;
    _filterMenuItems(_searchQuery); 
   });
  } catch (e) {
   setState(() {
    _errorMessage = 'Gagal memuat item menu: ${e.toString()}';
   });
  } finally {
   setState(() {
    _isLoading = false;
   });
  }
 }

 Future<void> _showCategoryFormDialog({Category? categoryToEdit}) async {
  final TextEditingController nameController = TextEditingController(text: categoryToEdit?.name);
  final isNewCategory = categoryToEdit == null;

  await showDialog(
   context: context,
   builder: (context) {
    return StatefulBuilder(
     builder: (context, setStateDialog) {
      bool isSaving = false;
      return AlertDialog(
       title: Text(isNewCategory ? 'Tambah Kategori Baru' : 'Edit Kategori'),
       content: TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Nama Kategori'),
       ),
       actions: [
        TextButton(
         onPressed: () => Navigator.pop(context),
         child: const Text('Batal'),
        ),
        ElevatedButton(
         onPressed: isSaving ? null : () async {
          if (nameController.text.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Nama kategori tidak boleh kosong!')));
           return;
          }
          setStateDialog(() { isSaving = true; }); 
          try {
           if (isNewCategory) {
            final newCategory = Category(
             id: _uuid.v4(),
             name: nameController.text,
             lastSyncAt: DateTime.now(),
            );
            await _menuService.saveCategory(newCategory);
           } else {
            final updatedCategory = categoryToEdit!.copyWith(
             name: nameController.text,
             lastSyncAt: DateTime.now(),
            );
            await _menuService.saveCategory(updatedCategory);
           }
           if (mounted) Navigator.pop(context);
           _loadCategories();
          } catch (e) {
           setStateDialog(() { _errorMessage = 'Gagal menyimpan kategori: ${e.toString()}'; });
          } finally {
           setStateDialog(() { isSaving = false; }); 
          }
         },
         child: isSaving ? const CircularProgressIndicator() : const Text('Simpan'), 
        ),
       ],
      );
     }
    );
   },
  );
 }

 Future<void> _deleteCategory(String categoryId) async {
  final bool? confirm = await showDialog<bool>(
   context: context,
   builder: (context) => AlertDialog(
    title: const Text('Konfirmasi Hapus'),
    content: const Text('Menghapus kategori akan menghapus semua item menu di dalamnya. Lanjutkan?'),
    actions: [
     TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
     TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
    ],
   ),
  );

  if (confirm == true) {
   setState(() { _isLoading = true; });
   try {
    await _menuService.deleteCategory(categoryId);
    _loadCategories();
   } catch (e) {
    setState(() { _errorMessage = 'Gagal menghapus kategori: ${e.toString()}'; });
   } finally {
    setState(() { _isLoading = false; });
   }
  }
 }

 Future<void> _showMenuItemFormDialog({MenuItem? itemToEdit}) async {
  final TextEditingController nameController = TextEditingController(text: itemToEdit?.name);
  final TextEditingController priceController = TextEditingController(text: itemToEdit?.price.toString());
  final TextEditingController descriptionController = TextEditingController(text: itemToEdit?.description);
  bool isAvailable = itemToEdit?.isAvailable ?? true;
  final isNewItem = itemToEdit == null;

  await showDialog(
   context: context,
   builder: (dialogContext) {
    return StatefulBuilder(
     builder: (context, setStateDialog) {
      bool isSaving = false;
      return AlertDialog(
       title: Text(isNewItem ? 'Tambah Item Menu Baru' : 'Edit Item Menu'),
       content: SingleChildScrollView(
        child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
          TextField(
           controller: nameController,
           decoration: const InputDecoration(labelText: 'Nama Item', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
           controller: priceController,
           decoration: const InputDecoration(labelText: 'Harga', border: OutlineInputBorder()),
           keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
           controller: descriptionController,
           decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()),
           maxLines: 3,
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
           title: const Text('Tersedia'),
           value: isAvailable,
           onChanged: (value) {
            setStateDialog(() {
             isAvailable = value ?? true;
            });
           },
          ),
         ],
        ),
       ),
       actions: [
        TextButton(
         onPressed: () => Navigator.pop(dialogContext),
         child: const Text('Batal'),
        ),
        ElevatedButton(
         onPressed: isSaving ? null : () async {
          if (nameController.text.isEmpty || priceController.text.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Nama & Harga tidak boleh kosong!')));
           return;
          }
          setStateDialog(() { isSaving = true; });
          try {
           final price = double.tryParse(priceController.text);
           if (price == null) {
            throw Exception('Harga harus berupa angka valid.');
           }
           if (_selectedCategory == null) {
            throw Exception('Pilih kategori terlebih dahulu.');
           }

           if (isNewItem) {
            final newItem = MenuItem(
             id: _uuid.v4(),
             categoryId: _selectedCategory!.id,
             name: nameController.text,
             price: price,
             description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
             isAvailable: isAvailable,
             lastSyncAt: DateTime.now(),
             imageUrl: itemToEdit?.imageUrl,
            );
            await _menuService.saveMenuItem(newItem);
           } else {
            final updatedItem = itemToEdit!.copyWith(
             name: nameController.text,
             price: price,
             description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
             isAvailable: isAvailable,
             lastSyncAt: DateTime.now(),
            );
            await _menuService.saveMenuItem(updatedItem);
           }
           if (dialogContext.mounted) Navigator.pop(dialogContext);
           _loadMenuItems(_selectedCategory!.id);
          } catch (e) {
           setStateDialog(() { _errorMessage = 'Gagal menyimpan item menu: ${e.toString()}'; });
          } finally {
           setStateDialog(() { isSaving = false; });
          }
         },
         child: isSaving ? const CircularProgressIndicator() : const Text('Simpan'),
        ),
       ],
      );
     },
    );
   },
  );
 }
 
 Future<void> _deleteMenuItem(String itemId) async {
  final bool? confirm = await showDialog<bool>(
   context: context,
   builder: (context) => AlertDialog(
    title: const Text('Konfirmasi Hapus'),
    content: const Text('Apakah Anda yakin ingin menghapus item menu ini?'),
    actions: [
     TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
     TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
    ],
   ),
  );

  if (confirm == true) {
   setState(() { _isLoading = true; });
   try {
    await _menuService.deleteMenuItem(itemId);
    if (_selectedCategory != null) {
     _loadMenuItems(_selectedCategory!.id);
    }
   } catch (e) {
    setState(() { _errorMessage = 'Gagal menghapus item menu: ${e.toString()}'; });
   } finally {
    setState(() { _isLoading = false; });
   }
  }
 }

// ------------------------------------------------------------------
// UI LAYOUT
// ------------------------------------------------------------------
 
 @override
 Widget build(BuildContext context) {
  return Scaffold(
   appBar: AppBar(
    title: const Text('Manajemen Menu'),
    actions: [
     IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: _loadCategories,
      tooltip: 'Refresh Data',
     ),
    ],
   ),
   body: _isLoading && _categories.isEmpty
     ? const Center(child: CircularProgressIndicator())
     : _errorMessage != null
       ? Center(
         child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
           _errorMessage!,
           style: const TextStyle(color: Colors.red, fontSize: 16),
           textAlign: TextAlign.center,
          ),
         ),
        )
       : LayoutBuilder(
         builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
           return _buildDesktopLayout();
          } else {
           return _buildMobileLayout();
          }
         },
        ),
    
    // FAB dinamis sekarang dihilangkan dari Scaffold utama
    // dan dipindahkan ke dalam _buildMobileLayout()
 );
 }

 Widget _buildDesktopLayout() {
  return Row(
   children: [
    // Sidebar Kategori (kiri)
    Container(
     width: 250,
     decoration: BoxDecoration(
      border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
     ),
     child: Column(
      children: [
       Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
         onPressed: () => _showCategoryFormDialog(),
         icon: const Icon(Icons.add),
         label: const Text('Tambah Kategori'),
         style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
         ),
        ),
       ),
       Expanded(
        child: _categories.isEmpty
          ? const Center(child: Text('Belum ada kategori'))
          : ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
             final category = _categories[index];
             final isSelected = _selectedCategory?.id == category.id;
             return InkWell(
              onTap: () {
               setState(() {
                _selectedCategory = category;
                _searchQuery = '';
               });
               _loadMenuItems(category.id);
              },
              child: Container(
               color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                 Text(
                  category.name,
                  style: TextStyle(
                   fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                   color: isSelected ? Theme.of(context).primaryColor : null,
                   fontSize: 16
                  ),
                 ),
                 if (isSelected)
                  Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                    IconButton(
                     icon: const Icon(Icons.edit, size: 20),
                     onPressed: () => _showCategoryFormDialog(categoryToEdit: category),
                     tooltip: 'Edit Kategori',
                    ),
                    IconButton(
                     icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                     onPressed: () => _deleteCategory(category.id),
                     tooltip: 'Hapus Kategori',
                    ),
                   ],
                  ),
                ],
               ),
              ),
             );
            },
           ),
       ),
      ],
     ),
    ),
    // Konten Item Menu (kanan)
    Expanded(
     child: Column(
      children: [
       // Search Bar di Desktop
       Padding(
        padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
        child: TextField(
         decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Cari item menu...',
          border: OutlineInputBorder(),
         ),
         onChanged: _filterMenuItems,
        ),
       ),
       Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
         onPressed: _selectedCategory == null
           ? null
           : () => _showMenuItemFormDialog(),
         icon: const Icon(Icons.add),
         label: Text(_selectedCategory == null ? 'Pilih Kategori Dulu' : 'Tambah Item Menu'),
         style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
         ),
        ),
       ),
       Expanded(
        child: _selectedCategory == null
          ? const Center(child: Text('Pilih kategori untuk melihat item menu.'))
          : _filteredMenuItems.isEmpty
            ? Center(child: Text(_searchQuery.isNotEmpty 
                            ? 'Item "${_searchQuery}" tidak ditemukan.'
                            : 'Tidak ada item menu di kategori ini.'))
            : GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
               maxCrossAxisExtent: 250, 
               childAspectRatio: 0.7,
               crossAxisSpacing: 16,
               mainAxisSpacing: 16,
              ),
              padding: const EdgeInsets.all(16),
              itemCount: _filteredMenuItems.length, 
              itemBuilder: (context, index) {
               final item = _filteredMenuItems[index];
               return _buildMenuItemCard(item);
              },
             ),
       ),
      ],
     ),
    ),
   ],
  );
 }

 Widget _buildMobileLayout() {
  return DefaultTabController(
   length: 2,
   child: Builder(
    builder: (context) {
     // Akses DefaultTabController dengan aman di sini
     final tabController = DefaultTabController.of(context);
     final currentTabIndex = tabController.index; 
     
     return Scaffold(
      // FAB di dalam Scaffold, anak dari DefaultTabController
      floatingActionButton: currentTabIndex == 0
        ? FloatingActionButton.extended(
          onPressed: () => _showCategoryFormDialog(),
          label: const Text('Tambah Kategori'),
          icon: const Icon(Icons.add),
         )
        : currentTabIndex == 1 && _selectedCategory != null
          ? FloatingActionButton.extended(
            onPressed: () => _showMenuItemFormDialog(),
            label: const Text('Tambah Item'),
            icon: const Icon(Icons.add),
           )
          : const SizedBox.shrink(),
      body: Column(
       children: [
        TabBar(
         tabs: const [
          Tab(text: 'Kategori'),
          Tab(text: 'Menu Item'),
         ],
         labelColor: Theme.of(context).primaryColor,
         unselectedLabelColor: Colors.grey,
         indicatorColor: Theme.of(context).primaryColor,
        ),
        Expanded(
         child: TabBarView(
          children: [
           // Halaman Kategori
           _categories.isEmpty
             ? const Center(child: Text('Belum ada kategori'))
             : ListView.builder(
               itemCount: _categories.length,
               itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory?.id == category.id;
                return ListTile(
                 title: Text(category.name),
                 selected: isSelected,
                 onTap: () {
                  setState(() {
                   _selectedCategory = category;
                   _searchQuery = '';
                  });
                  _loadMenuItems(category.id);
                  DefaultTabController.of(context).animateTo(1);
                 },
                 trailing: isSelected
                   ? Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                      IconButton(
                       icon: const Icon(Icons.edit, size: 20),
                       onPressed: () => _showCategoryFormDialog(categoryToEdit: category),
                       tooltip: 'Edit',
                      ),
                      IconButton(
                       icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                       onPressed: () => _deleteCategory(category.id),
                       tooltip: 'Hapus',
                      ),
                     ],
                    )
                   : null,
                );
               },
             ),

           // Halaman Item Menu
           Column( 
            children: [
             // Search Bar di Mobile
             Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
               decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari item menu...',
                border: OutlineInputBorder(),
               ),
               onChanged: _filterMenuItems,
              ),
             ),
             Expanded(
              child: _selectedCategory == null
                ? const Center(child: Text('Pilih kategori untuk melihat item menu.'))
                : _filteredMenuItems.isEmpty
                  ? Center( 
                    child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                      Text(_searchQuery.isNotEmpty 
                                                ? 'Item "${_searchQuery}" tidak ditemukan.'
                                                : 'Tidak ada item menu di kategori ini.'),
                      const SizedBox(height: 10),
                      if (_searchQuery.isEmpty)
                        ElevatedButton.icon(
                       onPressed: () => _showMenuItemFormDialog(),
                       icon: const Icon(Icons.add),
                       label: const Text('Tambah Item Menu'),
                      ),
                     ],
                    )
                   )
                  : ListView.builder(
                    itemCount: _filteredMenuItems.length, 
                    itemBuilder: (context, index) {
                     final item = _filteredMenuItems[index];
                     return _buildMenuItemListTile(item);
                    },
                   ),
                ),
               ],
              ),
             ],
            ),
           ),
          ],
         ),
       );
      }
   ),
  );
 }

 Widget _buildMenuItemCard(MenuItem item) {
  // Membuat seluruh Card dapat diklik untuk Edit
  return InkWell(
   onTap: () => _showMenuItemFormDialog(itemToEdit: item),
   child: Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    clipBehavior: Clip.antiAlias,
    child: Stack(
     children: [
      Column(
       crossAxisAlignment: CrossAxisAlignment.stretch,
       children: [
        Expanded(
         child: Container(
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: item.imageUrl != null && item.imageUrl!.isNotEmpty
            ? Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
             )
            : const Icon(Icons.restaurant_menu, size: 50, color: Colors.grey),
         ),
        ),
        Padding(
         padding: const EdgeInsets.all(8.0),
         child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
           ),
           const SizedBox(height: 4),
           Text(
            'Rp ${item.price.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary),
           ),
           const SizedBox(height: 4),
           Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
             color: item.isAvailable ? Colors.green[100] : Colors.red[100],
             borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
             item.isAvailable ? 'Tersedia' : 'Habis',
             style: TextStyle(
              color: item.isAvailable ? Colors.green[700] : Colors.red[700],
              fontSize: 10,
              fontWeight: FontWeight.bold
             ),
            ),
           ),
          ],
         ),
        ),
       ],
      ),
      Positioned(
       top: 8,
       right: 8,
       child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
         IconButton(
          iconSize: 20,
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: () => _showMenuItemFormDialog(itemToEdit: item),
          tooltip: 'Edit Item',
          style: IconButton.styleFrom(
           backgroundColor: Colors.blue.withOpacity(0.8),
           padding: EdgeInsets.zero,
          ),
         ),
         const SizedBox(width: 8),
         IconButton(
          iconSize: 20,
          icon: const Icon(Icons.delete, color: Colors.white),
          onPressed: () => _deleteMenuItem(item.id),
          tooltip: 'Hapus Item',
          style: IconButton.styleFrom(
           backgroundColor: Colors.red.withOpacity(0.8),
           padding: EdgeInsets.zero,
          ),
         ),
        ],
       ),
      ),
     ],
    ),
   ),
  );
 }

 Widget _buildMenuItemListTile(MenuItem item) {
  return ListTile(
   // Membuat ListTile dapat diklik untuk Edit
   onTap: () => _showMenuItemFormDialog(itemToEdit: item),
   leading: item.imageUrl != null && item.imageUrl!.isNotEmpty
     ? ClipRRect(
       borderRadius: BorderRadius.circular(8.0),
       child: Image.network(
        item.imageUrl!,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (c, o, s) => const Icon(Icons.broken_image, size: 40),
       ),
      )
     : const Icon(Icons.restaurant_menu, size: 40),
   title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
   subtitle: Text('Rp ${item.price.toStringAsFixed(0)}'),
   trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
     IconButton(
      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
      onPressed: () => _deleteMenuItem(item.id),
      tooltip: 'Hapus',
     ),
    ],
   ),
  );
 }
}