class User {
  final String id;
  final String name;
  final String username;
  final String passwordHash; // Disimpan sebagai hash
  final String level; // 'admin' atau 'karyawan'
  final bool isActive;
  final DateTime? lastSyncAt; // Nullable, untuk sinkronisasi

  User({
    required this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.level,
    this.isActive = true, // Default true
    this.lastSyncAt,
  });

  // Factory constructor untuk membuat objek User dari Map (dari SQLite/Firebase)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      name: map['name'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      level: map['level'] as String,
      isActive: map['is_active'] != null
          ? (map['is_active'] is bool // Cek apakah aslinya boolean (dari Firestore)
              ? map['is_active'] as bool
              : (map['is_active'] as int) == 1) // Jika bukan boolean, asumsikan int (dari SQLite)
          : true, // Beri nilai default `true` jika field tidak ada atau null
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.parse(map['last_sync_at'] as String)
          : null,
    );
  }

  // Metode untuk mengonversi objek User menjadi Map (untuk disimpan ke SQLite/Firebase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'password_hash': passwordHash,
      'level': level,
      'is_active': isActive ? 1 : 0, // Konversi bool ke int
      'last_sync_at': lastSyncAt?.toIso8601String(), // Konversi DateTime ke String
    };
  }

  // Untuk debug, bisa ditambahkan toString
  @override
  String toString() {
    return 'User(id: $id, name: $name, username: $username, level: $level, isActive: $isActive)';
  }
  
  User copyWith({
    String? id,
    String? name,
    String? username,
    String? passwordHash,
    String? level,
    bool? isActive,
    DateTime? lastSyncAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      level: level ?? this.level,
      isActive: isActive ?? this.isActive,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}