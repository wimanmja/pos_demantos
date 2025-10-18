import 'package:flutter/material.dart';
import 'package:pos_demantos/screens/auth/login_screen.dart';
import 'package:pos_demantos/services/auth_service.dart';
import 'package:pos_demantos/screens/pos_screen.dart'; // Import POSScreen

class CashierDashboardScreen extends StatelessWidget {
  const CashierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Selamat datang Kasir!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const POSScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Mulai Transaksi (POS)'),
            ),
            // Tambahkan tombol lain jika ada fitur untuk Kasir di sini
          ],
        ),
      ),
    );
  }
}