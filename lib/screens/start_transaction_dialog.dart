import 'package:flutter/material.dart';
import 'package:pos_demantos/screens/pos_screen.dart';

class StartTransactionDialog {
  static Future<void> show(BuildContext context) async {
    final TextEditingController tableController = TextEditingController();
    final TextEditingController customerController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.point_of_sale, color: Colors.blue),
              SizedBox(width: 8),
              Text('Start Transaction (POS)'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tableController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Meja',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.table_restaurant),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: customerController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pelanggan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => POSScreen(
                      tableNumber: tableController.text.isNotEmpty ? tableController.text : null,
                      customerName: customerController.text.isNotEmpty ? customerController.text : null,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}