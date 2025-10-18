import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pos_demantos/utils/password_util.dart';
import 'package:pos_demantos/models/user_model.dart';
import 'package:pos_demantos/models/category_model.dart';
import 'package:pos_demantos/models/menu_item_model.dart';
import 'package:pos_demantos/models/menu_option_model.dart';
import 'package:pos_demantos/models/sale_transaction_model.dart';
import 'package:pos_demantos/models/sale_item_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database; // Nullable Database object

  // Private constructor to enforce Singleton pattern
  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'pos_resto.db'); // Nama file database Anda

    // Buka database. Ini akan membuat database jika belum ada.
    return await openDatabase(
      path,
      version: 2, // Updated version to include expenses table
      onCreate: _onCreate, // Dipanggil saat database pertama kali dibuat
      onUpgrade: _onUpgrade, // Dipanggil saat versi database ditingkatkan
    );
  }

  // Metode ini dipanggil saat database pertama kali dibuat.
  Future<void> _onCreate(Database db, int version) async {
    // Membuat tabel users
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        level TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_sync_at TEXT
      )
    ''');

    // Membuat tabel categories
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        last_sync_at TEXT
      )
    ''');

    // Membuat tabel menu_items
    await db.execute('''
      CREATE TABLE menu_items (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        description TEXT,
        image_url TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        last_sync_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Membuat tabel menu_options
    await db.execute('''
      CREATE TABLE menu_options (
        id TEXT PRIMARY KEY,
        menu_item_id TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        price_adjustment REAL NOT NULL DEFAULT 0.0,
        last_sync_at TEXT,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id) ON DELETE CASCADE
      )
    ''');

    // Membuat tabel sales_transactions
    await db.execute('''
      CREATE TABLE sales_transactions (
        id TEXT PRIMARY KEY,
        transaction_date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        cash_paid REAL,
        change_given REAL,
        table_number TEXT,
        customer_name TEXT,
        user_id TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        last_sync_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Membuat tabel sale_items
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        menu_item_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        item_price_at_sale REAL NOT NULL,
        notes TEXT,
        selected_options_json TEXT,
        last_sync_at TEXT,
        FOREIGN KEY (transaction_id) REFERENCES sales_transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id)
      )
    ''');

    // NEW: Membuat tabel expenses untuk reporting system
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        expense_date INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        notes TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        last_sync_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Contoh: Menambahkan user admin awal (untuk development)
    // Pastikan ini hanya untuk tujuan development dan dihapus/dimodifikasi di production
    await db.insert('users', {
      'id': 'admin_123', // ID unik untuk admin
      'name': 'Super Admin',
      'username': 'admin',
      'password_hash': PasswordUtil.hashPassword('admin123'), // <-- GANTI DENGAN INI
      'level': 'admin',
      'is_active': 1,
      'last_sync_at': DateTime.now().toIso8601String(),
    });
  }

  // Metode ini dipanggil saat versi database ditingkatkan.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Logika migrasi database di sini.
    if (oldVersion < 2) {
      // Add expenses table for existing databases
      await db.execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          expense_date INTEGER NOT NULL,
          user_id TEXT NOT NULL,
          notes TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          last_sync_at INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
    }
  }

  // --- Contoh Metode CRUD Sederhana ---

  // Insert data baru ke tabel
  Future<int> insert(String tableName, Map<String, dynamic> data) async {
    Database db = await database;
    return await db.insert(
      tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace, // Jika ID sudah ada, ganti
    );
  }

  // Mengambil semua data dari tabel
  Future<List<Map<String, dynamic>>> queryAll(String tableName) async {
    Database db = await database;
    return await db.query(tableName);
  }

  // Mengambil data berdasarkan query spesifik
  Future<List<Map<String, dynamic>>> query(String tableName, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    Database db = await database;
    return await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  // Memperbarui data di tabel
  Future<int> update(String tableName, Map<String, dynamic> data, String whereColumn, String whereValue) async {
    Database db = await database;
    return await db.update(
      tableName,
      data,
      where: '$whereColumn = ?',
      whereArgs: [whereValue],
    );
  }

  // Menghapus data dari tabel
  Future<int> delete(String tableName, String whereColumn, String whereValue) async {
    Database db = await database;
    return await db.delete(
      tableName,
      where: '$whereColumn = ?',
      whereArgs: [whereValue],
    );
  }

  // Menutup database (opsional, database akan otomatis ditutup saat aplikasi dihentikan)
  Future<void> close() async {
    Database db = await _database!;
    db.close();
    _database = null; // Reset database instance
  }

  // --- Metode CRUD untuk Model User ---
  Future<int> insertUser(User user) async {
    Database db = await database;
    return await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getUsers({String? where, List<dynamic>? whereArgs, String? orderBy}) async { // <-- Tambahkan String? orderBy
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', where: where, whereArgs: whereArgs, orderBy: orderBy); // <-- Teruskan orderBy
    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  Future<int> updateUser(User user) async {
    Database db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(String id) async {
    Database db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Metode CRUD untuk Model Category ---
  Future<int> insertCategory(Category category) async {
    Database db = await database;
    return await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Category>> getCategories({String? where, List<dynamic>? whereArgs, String? orderBy}) async { // <-- Tambahkan String? orderBy
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories', where: where, whereArgs: whereArgs, orderBy: orderBy); // <-- Teruskan orderBy
    return List.generate(maps.length, (i) {
      return Category.fromMap(maps[i]);
    });
  }

  Future<int> updateCategory(Category category) async {
    Database db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    Database db = await database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Metode CRUD untuk Model MenuItem ---
  Future<int> insertMenuItem(MenuItem menuItem) async {
    Database db = await database;
    return await db.insert('menu_items', menuItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MenuItem>> getMenuItems({String? where, List<dynamic>? whereArgs, String? orderBy}) async { // <-- Tambahkan String? orderBy
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('menu_items', where: where, whereArgs: whereArgs, orderBy: orderBy); // <-- Teruskan orderBy
    // TODO: Untuk MenuItem, Anda mungkin perlu mengambil juga MenuOption terkait
    return List.generate(maps.length, (i) {
      return MenuItem.fromMap(maps[i]);
    });
  }

  Future<int> updateMenuItem(MenuItem menuItem) async {
    Database db = await database;
    return await db.update(
      'menu_items',
      menuItem.toMap(),
      where: 'id = ?',
      whereArgs: [menuItem.id],
    );
  }

  Future<int> deleteMenuItem(String id) async {
    Database db = await database;
    return await db.delete(
      'menu_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Metode CRUD untuk Model MenuOption ---
  Future<int> insertMenuOption(MenuOption menuOption) async {
    Database db = await database;
    return await db.insert('menu_options', menuOption.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MenuOption>> getMenuOptions({String? where, List<dynamic>? whereArgs, String? orderBy}) async { // <-- Tambahkan String? orderBy
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('menu_options', where: where, whereArgs: whereArgs, orderBy: orderBy); // <-- Teruskan orderBy
    return List.generate(maps.length, (i) {
      return MenuOption.fromMap(maps[i]);
    });
  }

  Future<int> updateMenuOption(MenuOption menuOption) async {
    Database db = await database;
    return await db.update(
      'menu_options',
      menuOption.toMap(),
      where: 'id = ?',
      whereArgs: [menuOption.id],
    );
  }

  Future<int> deleteMenuOption(String id) async {
    Database db = await database;
    return await db.delete(
      'menu_options',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// --- Akhir dari Metode CRUD Spesifik ---
}