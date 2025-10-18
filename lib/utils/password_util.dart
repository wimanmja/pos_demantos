import 'dart:convert';
import 'package:crypto/crypto.dart'; // Import library crypto

class PasswordUtil {
  // Fungsi untuk meng-hash password menggunakan SHA256
  static String hashPassword(String password) {
    // Mengonversi password ke bytes
    final bytes = utf8.encode(password);
    // Menghitung hash SHA256
    final digest = sha256.convert(bytes);
    // Mengembalikan hash dalam bentuk string heksadesimal
    return digest.toString();
  }

  // Fungsi untuk memverifikasi password
  static bool verifyPassword(String plainPassword, String hashedPassword) {
    return hashPassword(plainPassword) == hashedPassword;
  }
}