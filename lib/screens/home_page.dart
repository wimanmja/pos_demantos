import 'package:flutter/material.dart';
import 'package:pos_demantos/services/database_helper.dart'; // Import DatabaseHelper
import 'package:pos_demantos/screens/test_db_screen.dart'; // Import TestDbScreen (jika ingin navigasi)

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Resto App - Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Selamat datang di aplikasi POS Resto!',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final users = await DatabaseHelper().getUsers(); // Gunakan getUsers()
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Users in DB: ${users.length}')),
                );
                print('Users from DB: $users');
              },
              child: const Text('Cek Data User di DB Lokal'),
            ),
             ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TestDbScreen()),
                );
              },
              child: const Text('Go to DB Test Screen'),
            ),
          ],
        ),
      ),
    );
  }
}