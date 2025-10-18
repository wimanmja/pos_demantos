import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos_demantos/models/user_model.dart' as model; // Alias untuk model kita
import 'package:pos_demantos/services/database_helper.dart'; // Untuk sync ke SQLite

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Mendapatkan stream user dari Firestore berdasarkan ID (UID Firebase)
  Stream<model.User?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return model.User.fromMap(snapshot.data()!);
      }
      return null;
    });
  }

  // Mendapatkan user dari Firestore (sekali ambil)
  Future<model.User?> getUser(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return model.User.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Menambahkan atau memperbarui data user di Firestore
  Future<void> saveUser(model.User user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  // Mengelola user di database lokal (SQLite)
  Future<void> syncUserToLocal(model.User user) async {
    await _databaseHelper.insertUser(user);
    print('User ${user.username} synced to local SQLite.');
  }

  // Mendapatkan user dari SQLite
  Future<model.User?> getLocalUser(String uid) async {
    List<model.User> users = await _databaseHelper.getUsers(where: 'id = ?', whereArgs: [uid]);
    return users.isNotEmpty ? users.first : null;
  }

  // Metode untuk membuat user baru (hanya untuk Admin)
  Future<void> createUserWithRole(String email, String password, String name, String username, String level) async {
    // 1. Buat user di Firebase Authentication
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    String uid = userCredential.user!.uid;

    // 2. Simpan detail user di Firestore
    model.User newUser = model.User(
      id: uid, // UID dari Firebase Auth
      name: name,
      username: username,
      // Penting: passwordHash ini tidak akan digunakan untuk login Firebase Auth,
      // tapi mungkin berguna untuk skenario offline atau audit lokal.
      // Firebase Auth menangani hashing password sendiri.
      // Kita bisa menyimpan hash kosong atau hash dari password awal jika ingin.
      passwordHash: '', // Password hash tidak relevan untuk Firebase Auth, tapi kita simpan untuk konsistensi model
      level: level,
      isActive: true,
      lastSyncAt: DateTime.now(),
    );
    await saveUser(newUser);
    await syncUserToLocal(newUser); // Sinkronkan langsung ke lokal
  }

  // Metode untuk memperbarui user (hanya untuk Admin)
  Future<void> updateUserData(model.User user) async {
    await saveUser(user); // Update di Firestore
    await syncUserToLocal(user); // Update di lokal
  }

  // Mendapatkan semua user dari Firestore
  Future<List<model.User>> getAllUsersFromFirestore() async {
    QuerySnapshot querySnapshot = await _firestore.collection('users').get();
    return querySnapshot.docs
        .map((doc) => model.User.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Mendapatkan semua user dari SQLite
  Future<List<model.User>> getAllUsersFromLocal() async {
    return await _databaseHelper.getUsers();
  }

  // Menghapus user dari Firestore
  Future<void> deleteUserFromFirestore(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
    // Penting: Menghapus user di Firebase Auth juga perlu dilakukan jika itu yang diinginkan
    // Ini agak rumit karena membutuhkan Cloud Function atau backend sendiri untuk keamanan.
    // Untuk saat ini, kita hanya menghapus data profilnya.
    // Jika user dihapus dari Authentication, dokumen di Firestore ini tidak akan bisa diakses lagi.
  }

  // Menghapus user dari SQLite
  Future<void> deleteUserFromLocal(String uid) async {
    await _databaseHelper.deleteUser(uid);
    print('User $uid deleted from local SQLite.');
  }
}