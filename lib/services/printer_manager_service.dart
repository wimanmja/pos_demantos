import 'dart:async';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:intl/intl.dart';

enum PrinterStatus {
  disconnected,
  searching,
  connecting,
  ready,
  printing,
  notFound,
  connectionFailed,
  bluetoothOff,
  bluetoothUnavailable,
  error,
}

extension PrinterStatusExtension on PrinterStatus {
  String get displayName {
    switch (this) {
      case PrinterStatus.disconnected: return 'Disconnected';
      case PrinterStatus.searching: return 'Searching';
      case PrinterStatus.connecting: return 'Connecting';
      case PrinterStatus.ready: return 'Ready';
      case PrinterStatus.printing: return 'Printing';
      case PrinterStatus.notFound: return 'Not Found';
      case PrinterStatus.connectionFailed: return 'Connection Failed';
      case PrinterStatus.bluetoothOff: return 'Bluetooth Off';
      case PrinterStatus.bluetoothUnavailable: return 'Bluetooth Unavailable';
      case PrinterStatus.error: return 'Error';
    }
  }
}

class PrinterManagerService {
  static final PrinterManagerService _instance = PrinterManagerService._internal();
  factory PrinterManagerService() => _instance;
  PrinterManagerService._internal();

  static PrinterManagerService get instance => _instance;

  final BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;
  final StreamController<PrinterStatus> _statusController = StreamController<PrinterStatus>.broadcast();
  
  // Mengganti NumberFormat dengan utilitas sederhana
  // final NumberFormat _currencyFormat = NumberFormat("#,##0", "en_US"); 

  PrinterStatus _currentStatus = PrinterStatus.disconnected;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  Timer? _connectionTimer;

  // Getters
  Stream<PrinterStatus> get statusStream => _statusController.stream;
  PrinterStatus get currentStatus => _currentStatus;

  Future<bool> initialize() async {
    try {
      print('🖨️ Initializing PrinterManagerService...');
      
      _updateStatus(PrinterStatus.searching);
      
      bool isAvailable = await _bluetoothPrint.isAvailable ?? false;
      if (!isAvailable) {
        _updateStatus(PrinterStatus.bluetoothUnavailable);
        return false;
      }

      bool isOn = await _bluetoothPrint.isOn ?? false;
      if (!isOn) {
        _updateStatus(PrinterStatus.bluetoothOff);
        return false;
      }

      print('✅ Bluetooth is available and on');
      
      await _searchForPrinter();
      
      return true; 
    } catch (e) {
      print('❌ PrinterManagerService initialization error: $e');
      _updateStatus(PrinterStatus.error);
      return false;
    }
  }

  Future<void> _searchForPrinter() async {
    try {
      _updateStatus(PrinterStatus.searching);
      
      await _scanSubscription?.cancel();
      _connectionTimer?.cancel();
      
      await _bluetoothPrint.startScan(timeout: const Duration(seconds: 10));
      
      bool deviceFound = false;

      _scanSubscription = _bluetoothPrint.scanResults.listen((devices) async {
        if (deviceFound) return;
        
        for (var device in devices) {
          if (device.name != null && device.name!.contains('RPP02N')) {
            deviceFound = true;
            print('🎯 Target printer found: ${device.name}');
            
            // HENTIKAN PEMINDAIAN & TIMER SEGERA
            _bluetoothPrint.stopScan();
            await _scanSubscription?.cancel();
            _connectionTimer?.cancel(); 
            
            // MULAI KONEKSI
            await _connectToPrinter(device);
            return;
          }
        }
      });

      // Set timeout for search
      _connectionTimer = Timer(const Duration(seconds: 12), () async {
        if (!deviceFound && _currentStatus == PrinterStatus.searching) {
          await _scanSubscription?.cancel();
          _bluetoothPrint.stopScan();
          print('⏰ Printer search timeout');
          _updateStatus(PrinterStatus.notFound);
        }
      });
      
    } catch (e) {
      print('❌ Search error: $e');
      _updateStatus(PrinterStatus.error);
    }
  }

  Future<void> _connectToPrinter(BluetoothDevice device) async {
    try {
      _updateStatus(PrinterStatus.connecting);
      print('🔗 Connecting to ${device.name}...');
      
      bool success = await _bluetoothPrint.connect(device) ?? false;
      
      if (success) {
        await Future.delayed(const Duration(seconds: 2));
        _connectedDevice = device;
        _updateStatus(PrinterStatus.ready);
        print('✅ Successfully connected to ${device.name}');
      } else {
         throw Exception('Connection failed immediately after connect call.');
      }
      
    } catch (e) {
      print('❌ Connection error: $e');
      _connectedDevice = null;
      _updateStatus(PrinterStatus.connectionFailed);
    }
  }

  // --- PERUBAHAN KRITIS DI SINI ---
  Future<bool> printReceipt(Map<String, dynamic> receiptData) async {
    // 1. Pengecekan Status dan Quick Reconnect
    if (_currentStatus != PrinterStatus.ready) {
      print('❌ Printer not ready. Attempting quick reconnect.');
      if (_connectedDevice != null) {
          await _connectToPrinter(_connectedDevice!); // Coba sambung ulang cepat
      }
      if (_currentStatus != PrinterStatus.ready) {
          return false;
      }
    }

    try {
      _updateStatus(PrinterStatus.printing);
      print('🖨️ Starting print process...');

      Map<String, dynamic> config = {}; // Ganti Map() dengan {}
      List<LineText> list = [];
      List<dynamic> rawItems = receiptData['items'] ?? [];

      // Extract data
      List<Map<String, dynamic>> items = rawItems.cast<Map<String, dynamic>>();
      double total = receiptData['total'] ?? 0.0;
      double cashPaid = receiptData['cashPaid'] ?? 0.0;
      double changeGiven = receiptData['changeGiven'] ?? 0.0;
      String paymentMethod = receiptData['paymentMethod'] ?? '';
      String? tableNumber = receiptData['tableNumber'];
      String? customerName = receiptData['customerName'];
      
      // Helper untuk format Rupiah tanpa desimal
      String formatPrice(double price) => price.toStringAsFixed(0);

      // Header
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: "DEMANTOS",
        weight: 2,
        width: 2,
        height: 2,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));

      list.add(LineText(type: LineText.TYPE_TEXT, content: "JL. PANJAITAN NO. 72 KEL KRAJAN", align: LineText.ALIGN_CENTER, linefeed: 1));
      list.add(LineText(type: LineText.TYPE_TEXT, content: "KEC MEJAYAN, KAB MADIUN, 63153", align: LineText.ALIGN_CENTER, linefeed: 1));
      list.add(LineText(type: LineText.TYPE_TEXT, content: "================================", align: LineText.ALIGN_CENTER, linefeed: 1));

      // Date and time
      String currentDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      list.add(LineText(type: LineText.TYPE_TEXT, content: "Date: $currentDate", align: LineText.ALIGN_LEFT, linefeed: 1));

      // Table and customer info
      if (tableNumber != null) {
        list.add(LineText(type: LineText.TYPE_TEXT, content: "Table: $tableNumber", align: LineText.ALIGN_LEFT, linefeed: 1));
      }
      if (customerName != null) {
        list.add(LineText(type: LineText.TYPE_TEXT, content: "Customer: $customerName", align: LineText.ALIGN_LEFT, linefeed: 1));
      }

      list.add(LineText(type: LineText.TYPE_TEXT, content: "--------------------------------", align: LineText.ALIGN_CENTER, linefeed: 1));

      // Items
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final price = item['price'] ?? 0.0;
        final qty = item['qty'] ?? 1;
        final itemTotal = price * qty;

        list.add(LineText(type: LineText.TYPE_TEXT, content: item['title'] ?? 'Unknown Item', weight: 1, align: LineText.ALIGN_LEFT, linefeed: 1));
        
        // PERBAIKAN FORMAT MATA UANG
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: "Rp ${formatPrice(price)} x $qty = Rp ${formatPrice(itemTotal)}",
          align: LineText.ALIGN_LEFT,
          linefeed: 1,
        ));
      }

      // Total
      list.add(LineText(type: LineText.TYPE_TEXT, content: "--------------------------------", align: LineText.ALIGN_CENTER, linefeed: 1));

      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: "TOTAL: Rp ${formatPrice(total)}", // PERBAIKAN FORMAT MATA UANG
        weight: 2,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));

      // Payment information
      if (paymentMethod == 'tunai') {
        list.add(LineText(type: LineText.TYPE_TEXT, content: "Cash: Rp ${formatPrice(cashPaid)}", weight: 1, align: LineText.ALIGN_LEFT, linefeed: 1));
        list.add(LineText(type: LineText.TYPE_TEXT, content: "Change: Rp ${formatPrice(changeGiven)}", weight: 1, align: LineText.ALIGN_LEFT, linefeed: 1));
      } else {
        list.add(LineText(type: LineText.TYPE_TEXT, content: "Payment: ${paymentMethod.toUpperCase()}", weight: 1, align: LineText.ALIGN_LEFT, linefeed: 1));
      }

      list.add(LineText(type: LineText.TYPE_TEXT, content: "================================", align: LineText.ALIGN_CENTER, linefeed: 1));
      list.add(LineText(type: LineText.TYPE_TEXT, content: "Thank you for shopping!", align: LineText.ALIGN_CENTER, linefeed: 2));

      // Cut paper command
      list.add(LineText(type: LineText.TYPE_TEXT, content: "", linefeed: 1));
      list.add(LineText(type: LineText.TYPE_TEXT, content: "", linefeed: 1));

      // Send to printer
      print("📄 Sending print data to printer...");
      bool printSuccess = await _bluetoothPrint.printReceipt(config, list) ?? false;
      
      // Wait for print to complete
      await Future.delayed(const Duration(seconds: 3));
      
      _updateStatus(PrinterStatus.ready);
      if (printSuccess) {
          print('✅ Receipt printed successfully');
      } else {
          print('❌ Print command failed (bluetooth_print returned false)');
      }
      
      return printSuccess;
      
    } catch (e) {
      print('❌ Print error: $e');
      _updateStatus(PrinterStatus.ready); 
      return false;
    }
  }

  Future<void> retryConnection() async {
    print('🔄 Retrying printer connection...');
    await _searchForPrinter();
  }

  void _updateStatus(PrinterStatus status) {
    _currentStatus = status;
    _statusController.add(status);
    print('📊 Printer status updated: ${status.displayName}');
  }

  void dispose() {
    _scanSubscription?.cancel();
    _connectionTimer?.cancel();
    _statusController.close();
    _bluetoothPrint.stopScan();
  }
}