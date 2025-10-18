import 'package:pos_demantos/models/category_model.dart'; // Import Category
import 'package:pos_demantos/models/menu_option_model.dart'; // Import MenuOption
import 'dart:convert'; // Untuk JSON encoding/decoding

class MenuItem {
  final String id;
  final String categoryId;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final bool isAvailable;
  final DateTime? lastSyncAt;

  // Properti untuk menyimpan opsi-opsi terkait menu item ini (bukan dari DB langsung, tapi saat di-fetch)
  // Akan diisi terpisah atau lewat join saat mengambil data.
  final List<MenuOption>? options; 


  MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.isAvailable = true,
    this.lastSyncAt,
    this.options, // Inisialisasi properti options
  });

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    // Perhatikan: `options` tidak diambil langsung dari map DB, 
    // karena akan di-fetch dari tabel `menu_options` secara terpisah.
    return MenuItem(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      price: map['price'] as double,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      isAvailable: (map['is_available'] as int) == 1,
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.parse(map['last_sync_at'] as String)
          : null,
      options: null, // Default null, akan diisi terpisah
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'price': price,
      'description': description,
      'image_url': imageUrl,
      'is_available': isAvailable ? 1 : 0,
      'last_sync_at': lastSyncAt?.toIso8601String(),
    };
  }

  MenuItem copyWith({
    String? id,
    String? categoryId,
    String? name,
    double? price,
    String? description,
    String? imageUrl,
    bool? isAvailable,
    DateTime? lastSyncAt,
    List<MenuOption>? options, // Pastikan ini juga nullable di copyWith
  }) {
    return MenuItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      options: options ?? this.options, // Gunakan null-aware operator
    );
  }

  @override
  String toString() {
    return 'MenuItem(id: $id, name: $name, price: $price, categoryId: $categoryId, isAvailable: $isAvailable, options: ${options?.length ?? 0} options)';
  }
}