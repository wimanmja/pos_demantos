import 'package:flutter/material.dart';
import 'package:pos_demantos/screens/auth/login_screen.dart';
import 'package:pos_demantos/screens/start_transaction_dialog.dart';
import 'package:pos_demantos/screens/transaction_history_screen.dart';
import 'package:pos_demantos/services/auth_service.dart';
import 'package:pos_demantos/screens/admin/user_management_screen.dart';
import 'package:pos_demantos/screens/admin/menu_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Add this line to prevent keyboard from moving the page
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
              'Welcome Admin!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            
            // User Management Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserManagementScreen()),
                );
              },
              icon: const Icon(Icons.people),
              label: const Text('User Management'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
                minimumSize: const Size(250, 50),
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Menu Management Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MenuManagementScreen()),
                );
              },
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Menu Management'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
                minimumSize: const Size(250, 50),
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Start Transaction (POS) Button - Updated to show dialog
            ElevatedButton.icon(
              onPressed: () {
                // Show the start transaction dialog instead of directly navigating
                StartTransactionDialog.show(context);
              },
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Start Transaction (POS)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                minimumSize: const Size(250, 50),
              ),
            ),

            const SizedBox(height: 15),

            // Histori Transaksi Button
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('Histori Transaksi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
                minimumSize: const Size(250, 50),
              ),
            ),

          ],
        ),
      ),
    );
  }
}