import 'package:flutter/material.dart';
import 'package:pos_demantos/services/database_helper.dart'; // Import DatabaseHelper
import 'package:pos_demantos/models/user_model.dart';
import 'package:pos_demantos/utils/password_util.dart'; // Import UserModel

class TestDbScreen extends StatefulWidget {
  const TestDbScreen({super.key});

  @override
  _TestDbScreenState createState() => _TestDbScreenState();
}

class _TestDbScreenState extends State<TestDbScreen> {
  List<User> _users = []; // Pastikan ini List<User>

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await DatabaseHelper().getUsers();
    setState(() {
      _users = users;
    });
    print('Users loaded: $_users');
  }

  Future<void> _addUser() async {
    final newUser = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Karyawan Test ${DateTime.now().millisecondsSinceEpoch}',
      username: 'karyawan_test_${DateTime.now().millisecondsSinceEpoch}',
      passwordHash: PasswordUtil.hashPassword('karyawan123'), // <-- GANTI DENGAN INI
      level: 'karyawan',
      isActive: true,
      lastSyncAt: DateTime.now(),
    );
    await DatabaseHelper().insertUser(newUser);
    await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Local DB')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _addUser,
            child: const Text('Add Test Karyawan'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final User user = _users[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text('Username: ${user.username}, Level: ${user.level}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}