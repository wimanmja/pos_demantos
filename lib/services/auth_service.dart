import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Method untuk login
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Pengguna tidak ditemukan untuk email tersebut.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Password salah untuk email tersebut.');
      } else {
        throw Exception(e.message ?? 'Terjadi kesalahan saat login.');
      }
    } catch (e) {
      throw Exception('Login gagal: $e');
    }
  }

  // Method untuk logout
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Mendapatkan stream perubahan status autentikasi
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Mendapatkan user yang sedang login
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }
}