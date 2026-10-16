import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos_demantos/models/category_model.dart';
import 'package:pos_demantos/models/menu_item_model.dart';
import 'package:pos_demantos/models/menu_option_model.dart';
import 'package:pos_demantos/services/database_helper.dart'; // Untuk sync ke SQLite

class MenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<MenuItem> _cachedAllMenuItems = [];
  List<Category> _cachedCategories = [];
  bool _isDataLoaded = false;

  // Fungsi baru untuk memuat semua data secara paralel dan menyimpannya di cache
  Future<void> loadAllDataGlobally() async {
    if (_isDataLoaded) {
      print('⚡ Menu data already loaded in cache.');
      return; // JANGAN MUAT ULANG JIKA SUDAH ADA
    }

    try {
      print('⏳ Starting parallel data loading from Firestore...');

      // 1. Ambil semua kategori
      _cachedCategories = await getCategoriesFromFirestore();

      List<MenuItem> allItems = [];

      // 2. Ambil SEMUA daftar item menu dari SEMUA kategori secara paralel
      List<Future<List<MenuItem>>> itemFutures =
          _cachedCategories.map((category) {
        // Menggunakan fungsi yang sudah ada
        return getMenuItemsFromFirestore(category.id);
      }).toList();

      // Tunggu semua daftar item selesai dimuat
      List<List<MenuItem>> results = await Future.wait(itemFutures);
      for (var itemList in results) {
        allItems.addAll(itemList);
      }

      // 3. Ambil SEMUA opsi menu untuk SEMUA item secara paralel
      List<Future<List<MenuOption>>> optionFutures = allItems.map((item) {
        // Menggunakan fungsi yang sudah ada
        return getMenuOptionsFromFirestore(item.id);
      }).toList();

      List<List<MenuOption>> optionResults = await Future.wait(optionFutures);

      // 4. Gabungkan opsi kembali ke item yang sesuai
      List<MenuItem> itemsWithOption = [];
      for (int i = 0; i < allItems.length; i++) {
        itemsWithOption.add(allItems[i].copyWith(options: optionResults[i]));
      }

      // 5. Simpan hasil akhir di cache
      _cachedAllMenuItems =
          itemsWithOption; // <--- itemsWithOption kini didefinisikan!
      _isDataLoaded = true;
      print('✅ All menu data loaded and cached successfully.');
    } catch (e) {
      print('❌ Error loading global menu data: $e');
      // Jika gagal, pastikan state reset agar mencoba lagi di lain waktu
      _isDataLoaded = false;
      throw Exception('Failed to load menu data: $e');
    }
  }

  List<MenuItem> getAllItems() => _cachedAllMenuItems;
  List<Category> getAllCategories() => _cachedCategories;

  // --- KATEGORI ---

  // Menambahkan/Memperbarui Kategori di Firestore
  Future<void> saveCategory(Category category) async {
    await _firestore
        .collection('categories')
        .doc(category.id)
        .set(category.toMap());
    await _databaseHelper.insertCategory(category); // Sync to local
  }

  // Mendapatkan semua Kategori dari Firestore
  Future<List<Category>> getCategoriesFromFirestore() async {
    QuerySnapshot querySnapshot =
        await _firestore.collection('categories').orderBy('name').get();
    return querySnapshot.docs
        .map((doc) => Category.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Mendapatkan semua Kategori dari SQLite
  Future<List<Category>> getCategoriesFromLocal() async {
    return await _databaseHelper.getCategories(
        orderBy: 'name'); // Perlu tambahkan orderBy di DatabaseHelper
  }

  // Menghapus Kategori (dan semua item menu terkait)
  Future<void> deleteCategory(String categoryId) async {
    // Hapus dari Firestore (opsional: tambahkan batch delete untuk sub-koleksi jika ada)
    await _firestore.collection('categories').doc(categoryId).delete();
    // Hapus dari SQLite
    await _databaseHelper.deleteCategory(categoryId);
    // Mungkin juga perlu menghapus menu_items yang terkait di Firestore jika tidak menggunakan rule cascade delete
    // Untuk saat ini, asumsikan FOREIGN KEY ON DELETE CASCADE di SQLite sudah cukup.
  }

  Future<MenuItem?> getMenuItemById(String id) async {
    final dbHelper = DatabaseHelper();
    final items = await dbHelper.getMenuItems(
      where: 'id = ?',
      whereArgs: [id],
    );

    if (items.isNotEmpty) {
      // Also load the options for this menu item
      final options = await dbHelper.getMenuOptions(
        where: 'menu_item_id = ?',
        whereArgs: [id],
      );

      return items.first.copyWith(options: options);
    }

    return null;
  }

  Future<Category?> getCategoryById(String id) async {
    final dbHelper = DatabaseHelper();
    final categories = await dbHelper.getCategories(
      where: 'id = ?',
      whereArgs: [id],
    );

    return categories.isNotEmpty ? categories.first : null;
  }

  // --- ITEM MENU ---

  // Menambahkan/Memperbarui Item Menu di Firestore
  Future<void> saveMenuItem(MenuItem item) async {
    await _firestore.collection('menu_items').doc(item.id).set(item.toMap());
    await _databaseHelper.insertMenuItem(item); // Sync to local
  }

  // Mendapatkan semua Item Menu dari Firestore (per kategori)
  Future<List<MenuItem>> getMenuItemsFromFirestore(String categoryId) async {
    QuerySnapshot querySnapshot = await _firestore
        .collection('menu_items')
        .where('category_id', isEqualTo: categoryId)
        .orderBy('name')
        .get();
    return querySnapshot.docs
        .map((doc) => MenuItem.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Mendapatkan semua Item Menu dari SQLite (per kategori)
  Future<List<MenuItem>> getMenuItemsFromLocal(String categoryId) async {
    return await _databaseHelper.getMenuItems(
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name', // Perlu tambahkan orderBy di DatabaseHelper
    );
  }

  // Menghapus Item Menu
  Future<void> deleteMenuItem(String itemId) async {
    await _firestore.collection('menu_items').doc(itemId).delete();
    await _databaseHelper.deleteMenuItem(itemId);
  }

  // --- OPSI MENU (untuk item menu tertentu) ---

  // Menambahkan/Memperbarui Opsi Menu di Firestore
  Future<void> saveMenuOption(MenuOption option) async {
    await _firestore
        .collection('menu_options')
        .doc(option.id)
        .set(option.toMap());
    await _databaseHelper.insertMenuOption(option); // Sync to local
  }

  // Mendapatkan semua Opsi Menu untuk suatu MenuItem dari Firestore
  Future<List<MenuOption>> getMenuOptionsFromFirestore(
      String menuItemId) async {
    QuerySnapshot querySnapshot = await _firestore
        .collection('menu_options')
        .where('menu_item_id', isEqualTo: menuItemId)
        .orderBy('name')
        .get();
    return querySnapshot.docs
        .map((doc) => MenuOption.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Mendapatkan semua Opsi Menu untuk suatu MenuItem dari SQLite
  Future<List<MenuOption>> getMenuOptionsFromLocal(String menuItemId) async {
    return await _databaseHelper.getMenuOptions(
      where: 'menu_item_id = ?',
      whereArgs: [menuItemId],
      orderBy: 'name', // Perlu tambahkan orderBy di DatabaseHelper
    );
  }

  // Menghapus Opsi Menu
  Future<void> deleteMenuOption(String optionId) async {
    await _firestore.collection('menu_options').doc(optionId).delete();
    await _databaseHelper.deleteMenuOption(optionId);
  }

  Future<void> clearCache() async {
    // Clear the in-memory caches
    _cachedAllMenuItems = [];
    _cachedCategories = [];
    _isDataLoaded = false;

    print('Cache menu berhasil dibersihkan.');
  }
}
