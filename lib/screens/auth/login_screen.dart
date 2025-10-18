import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos_demantos/services/auth_service.dart'; // Import AuthService
import 'package:pos_demantos/services/user_service.dart'; // Import UserService
import 'package:pos_demantos/services/database_helper.dart'; // Tetap butuh ini untuk get user lokal
import 'package:pos_demantos/models/user_model.dart' as model; // Alias untuk model kita
import 'package:pos_demantos/screens/admin_dashboard_screen.dart';
import 'package:pos_demantos/screens/cashier_dashboard_screen.dart';
// import 'package:pos_demantos/utils/password_util.dart'; // Ini tidak lagi dipakai untuk login Firebase

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final TextEditingController _emailController = TextEditingController(); // Gunakan email untuk Firebase Auth
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Mendengarkan perubahan status autentikasi Firebase
    _authService.authStateChanges.listen((User? firebaseUser) {
      if (firebaseUser != null && !_isLoading) { // Jika sudah login dan bukan karena proses login sedang berjalan
        _navigateToDashboard(firebaseUser.uid);
      }
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Coba login menggunakan Firebase Authentication
      UserCredential userCredential = await _authService.signInWithEmailAndPassword(
        _emailController.text, // Email (bukan username)
        _passwordController.text,
      );

      String uid = userCredential.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        print("Nama kasir: ${userData['name']} - Level: ${userData['level']}");
      } else {
        print("Dokumen user tidak ditemukan di Firestore");
      }

      // 2. Setelah berhasil login Firebase Auth, ambil detail user dari Firestore/lokal
      model.User? loggedInUser = await _userService.getUser(uid); // Coba dari Firestore
      if (loggedInUser == null) {
        // Jika tidak ada di Firestore (mungkin user baru terdaftar tanpa detail),
        // atau jika offline, coba dari SQLite.
        loggedInUser = await _userService.getLocalUser(uid);
      }

      if (loggedInUser == null) {
        // Ini berarti user berhasil login Firebase Auth tapi tidak ada data detail di Firestore/SQLite.
        // Ini bisa terjadi jika user dibuat langsung di Firebase Auth tanpa detail peran.
        // Kita bisa asumsikan default role atau lemparkan error.
        // Untuk saat ini, kita akan lemparkan error untuk mencegah akses yang tidak terkontrol.
        throw Exception('Data pengguna tidak lengkap. Hubungi administrator.');
      }

      // Pastikan data user dari Firestore/lokal sudah sinkron ke lokal (jika belum ada)
      // Ini penting untuk offline mode
      await _userService.syncUserToLocal(loggedInUser);

      // Arahkan ke dashboard yang sesuai
      if (!mounted) return;

      _navigateToDashboard(loggedInUser.id); // Gunakan ID dari model User
      
    } on Exception catch (e) { // Tangkap Exception dari AuthService atau UserService
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('Login error: $_errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToDashboard(String uid) async {
     model.User? user = await _userService.getLocalUser(uid); // Ambil dari lokal (lebih cepat)
     if (user == null) {
       user = await _userService.getUser(uid); // Jika tidak ada di lokal, coba dari Firestore
       if (user != null) {
         await _userService.syncUserToLocal(user); // Sinkronkan jika dari Firestore
       } else {
         // Harusnya tidak terjadi jika sudah berhasil login Firebase Auth
         _errorMessage = 'Gagal mendapatkan data pengguna setelah login.';
         setState(() {}); // Update UI
         return;
       }
     }

     if (!mounted) return;

     if (user!.level == 'admin') {
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
       );
     } else if (user.level == 'karyawan') {
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (context) => const CashierDashboardScreen()),
       );
     } else {
       // Log out user jika level tidak dikenal
       await _authService.signOut();
       setState(() {
         _errorMessage = 'Level pengguna tidak dikenal. Anda akan dilogout.';
       });
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login POS Resto'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Aplikasi (opsional)
              Image.asset(
                'assets/app_logo.png', // Ganti dengan path logo Anda
                height: 100,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController, // Menggunakan email
                decoration: const InputDecoration(
                  labelText: 'Email', // Ubah menjadi Email
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email), // Ubah ikon
                ),
                keyboardType: TextInputType.emailAddress, // Tipe keyboard email
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Login'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}