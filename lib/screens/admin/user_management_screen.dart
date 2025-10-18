import 'package:flutter/material.dart';
import 'package:pos_demantos/models/user_model.dart' as model; // Alias model User
import 'package:pos_demantos/services/user_service.dart'; // Import UserService

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();
  List<model.User> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Ambil semua user dari Firestore
      final users = await _userService.getAllUsersFromFirestore();
      setState(() {
        _users = users;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat pengguna: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Metode untuk menampilkan dialog tambah/edit user
  Future<void> _showUserFormDialog({model.User? userToEdit}) async {
    final TextEditingController nameController = TextEditingController(text: userToEdit?.name);
    final TextEditingController usernameController = TextEditingController(text: userToEdit?.username);
    // Untuk email, kita tidak bisa langsung mengisi dari userToEdit karena email login Firebase Auth tidak disimpan di model User kita.
    // Email hanya digunakan saat membuat user baru.
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    
    // Pastikan level sudah dipilih jika edit, atau default ke 'karyawan' jika user baru
    String? selectedLevel = userToEdit?.level ?? 'karyawan'; 
    bool isActive = userToEdit?.isActive ?? true;

    final isNewUser = userToEdit == null;

    // Untuk memastikan perubahan di DropdownButton dan CheckboxListTile tercermin di dialog
    // kita gunakan StatefullBuilder di dalam showDialog.
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Gunakan BuildContext yang berbeda
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: Text(isNewUser ? 'Tambah Pengguna Baru' : 'Edit Pengguna'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    if (isNewUser) // Email hanya untuk user baru (login Firebase Auth)
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email (Login Auth)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    if (isNewUser) // Password hanya untuk user baru (login Firebase Auth)
                      const SizedBox(height: 10),
                    if (isNewUser)
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedLevel,
                      hint: const Text('Pilih Level'),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'karyawan', child: Text('Karyawan')),
                      ],
                      onChanged: (value) {
                        setStateDialog(() { // Gunakan setStateDialog untuk update UI di dialog
                          selectedLevel = value;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Aktif'),
                      value: isActive,
                      onChanged: (value) {
                        setStateDialog(() { // Gunakan setStateDialog untuk update UI di dialog
                          isActive = value ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () async { // Disable button when loading
                    setStateDialog(() { _isLoading = true; }); // Start loading for save operation
                    try {
                      if (isNewUser) {
                        if (emailController.text.isEmpty || passwordController.text.isEmpty || nameController.text.isEmpty || usernameController.text.isEmpty || selectedLevel == null) {
                          throw Exception('Semua field wajib diisi untuk pengguna baru.');
                        }
                        await _userService.createUserWithRole(
                          emailController.text, // Email untuk Firebase Auth
                          passwordController.text,
                          nameController.text,
                          usernameController.text,
                          selectedLevel!,
                        );
                      } else {
                        if (nameController.text.isEmpty || usernameController.text.isEmpty || selectedLevel == null) {
                          throw Exception('Nama, Username, dan Level wajib diisi.');
                        }
                        // Update user di Firestore dan lokal
                        final updatedUser = userToEdit!.copyWith(
                          name: nameController.text,
                          username: usernameController.text,
                          level: selectedLevel!,
                          isActive: isActive,
                          lastSyncAt: DateTime.now(),
                        );
                        await _userService.updateUserData(updatedUser);
                      }
                      if (dialogContext.mounted) Navigator.pop(dialogContext); // Tutup dialog
                      _loadUsers(); // Muat ulang daftar user
                    } catch (e) {
                      setStateDialog(() { // Update UI di dialog untuk error
                        _errorMessage = 'Gagal menyimpan user: ${e.toString().replaceFirst('Exception: ', '')}';
                      });
                    } finally {
                      setStateDialog(() { _isLoading = false; });
                    }
                  },
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Metode untuk menghapus user
  Future<void> _deleteUser(model.User user) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Apakah Anda yakin ingin menghapus pengguna "${user.name}"? Proses ini tidak akan menghapus akun login Firebase Auth-nya.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() { _isLoading = true; });
      try {
        // Hanya menghapus data profil dari Firestore dan lokal.
        // Penghapusan akun Firebase Auth user harus dilakukan dari sisi server (Cloud Functions)
        // untuk alasan keamanan.
        await _userService.deleteUserFromFirestore(user.id);
        await _userService.deleteUserFromLocal(user.id);
        _loadUsers();
      } catch (e) {
        setState(() {
          _errorMessage = 'Gagal menghapus user: ${e.toString()}';
        });
      } finally {
        setState(() { _isLoading = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showUserFormDialog(), // Panggil tanpa argumen untuk tambah baru
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _users.isEmpty
                  ? const Center(child: Text('Belum ada pengguna.'))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(user.name),
                            subtitle: Text('Username: ${user.username}\nLevel: ${user.level} ${user.isActive ? "" : "(Non-Aktif)"}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showUserFormDialog(userToEdit: user),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteUser(user),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}