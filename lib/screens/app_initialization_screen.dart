import 'package:flutter/material.dart';
import 'dart:io';
import '../services/printer_manager_service.dart';
import 'auth/login_screen.dart'; // Ganti dengan path yang benar

class AppInitializationScreen extends StatefulWidget {
  const AppInitializationScreen({Key? key}) : super(key: key);

  @override
  State<AppInitializationScreen> createState() => _AppInitializationScreenState();
}

class _AppInitializationScreenState extends State<AppInitializationScreen> {
  final PrinterManagerService _printerService = PrinterManagerService();
  String _statusMessage = "Initializing application...";
  bool _canProceed = false; // True jika bisa Lanjut ke App (Ready, atau Skip Printer)
  bool _hasError = false; // True jika ada Error Fatal (BT Off/Unavailable)
  PrinterStatus _currentPrinterStatus = PrinterStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    // Pastikan listener dibatalkan jika diperlukan di sini,
    // atau biarkan service yang menangani di dispose miliknya
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      print('🚀 Starting app initialization...');
      
      setState(() {
        _statusMessage = "Checking device compatibility...";
        _hasError = false;
        _canProceed = false;
        _currentPrinterStatus = PrinterStatus.searching; // Status awal untuk UI
      });

      // Check if we're on Android
      if (!Platform.isAndroid) {
        setState(() {
          _statusMessage = "Bluetooth printing is only available on Android devices.\nYou can continue without printer functionality.";
          _canProceed = true; // Langsung bisa lanjut
        });
        return;
      }

      // Initialize printer service (memulai scan)
      bool success = await _printerService.initialize();
      
      if (success) {
        // Blok ini dieksekusi jika Bluetooth berhasil dihidupkan/tersedia
        
        // Listener status
        _printerService.statusStream.listen((status) {
          if (mounted) {
            setState(() {
              _currentPrinterStatus = status;
              _statusMessage = _getStatusMessage(status);
              
              // _canProceed: Hanya true jika READY (untuk auto-proceed)
              _canProceed = (status == PrinterStatus.ready); 
              
              // _hasError: Hanya true untuk error fatal yang perlu tombol 'Retry' Biru
              _hasError = (status == PrinterStatus.bluetoothUnavailable || 
                           status == PrinterStatus.error || 
                           status == PrinterStatus.bluetoothOff);
            });
            
            // LOGIKA AUTO-PROCEED DIJALANKAN HANYA SAAT STATUS = READY
            if (status == PrinterStatus.ready) {
                // Beri jeda visual singkat sebelum transisi
                Future.delayed(const Duration(milliseconds: 500), () { 
                    if (mounted) {
                        _proceedToLogin(); // Lanjutkan ke LoginScreen
                    }
                });
            }
          }
        });
        
      } else {
        // Ini menangani inisialisasi awal yang gagal (misalnya Bluetooth Unavailable saat initialize dipanggil)
        setState(() {
          // Status sudah diperbarui oleh service, kita hanya menyesuaikan hasError/canProceed
          _currentPrinterStatus = _printerService.currentStatus;
          _hasError = true;
          _statusMessage = _getStatusMessage(_currentPrinterStatus);
          _canProceed = (_currentPrinterStatus == PrinterStatus.bluetoothUnavailable); // Allow continuing anyway if BT unavailable
        });
      }
      
    } catch (e) {
      print('❌ App initialization failed: $e');
      setState(() {
        _hasError = true;
        _statusMessage = "Initialization failed: ${e.toString()}";
        _canProceed = true; // Allow continuing anyway
      });
    }
  }

  String _getStatusMessage(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.bluetoothUnavailable:
        return "Bluetooth is not available on this device ❌\nYou can continue without printer.";
      case PrinterStatus.bluetoothOff:
        return "Please turn on Bluetooth to use printer 📱\nOr continue without printer.";
      case PrinterStatus.searching:
        return "Searching for printer RPP02N... 🔍";
      case PrinterStatus.connecting:
        return "Connecting to printer... 🔗";
      case PrinterStatus.ready:
        return "Printer ready! ✅\nProceeding to login...";
      case PrinterStatus.notFound:
        return "Printer RPP02N not found ⚠️\nPlease check if printer is on and nearby";
      case PrinterStatus.connectionFailed:
        return "Failed to connect to printer ❌\nYou can continue without printer";
      case PrinterStatus.error:
        return "Printer error occurred ❌\nYou can continue without printer";
      case PrinterStatus.disconnected:
      default:
        return "Checking printer status... ⏳";
    }
  }

  void _proceedToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _retryInitialization() {
    setState(() {
      _canProceed = false;
      _hasError = false;
      _statusMessage = "Retrying initialization...";
    });
    // Panggil ulang initialize() untuk memulai proses dari awal
    _initializeApp(); 
  }

  void _proceedWithoutPrinter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continue Without Printer?'),
        content: const Text(
          'You can continue using the app, but printing receipts will not be available. '
          'You can try connecting to the printer later from the settings.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToLogin();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Menentukan status visual saat ini
    bool isSearchingOrConnecting = (_currentPrinterStatus == PrinterStatus.searching || _currentPrinterStatus == PrinterStatus.connecting);
    bool isProceedWarning = _canProceed && !_hasError && !isSearchingOrConnecting;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ... (App Logo and Title)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon( Icons.point_of_sale, size: 80, color: Colors.blue[600]),
                    const SizedBox(height: 16),
                    Text('POS DEMANTOS', style: TextStyle( fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                    const SizedBox(height: 8),
                    Text('Point of Sale System', style: TextStyle( fontSize: 16, color: Colors.blue[600])),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Status Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _hasError ? Colors.red[50] : (isProceedWarning ? Colors.green[50] : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasError ? Colors.red[200]! : (isProceedWarning ? Colors.green[200]! : Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  children: [
                    // Loading indicator or status icon
                    if (isSearchingOrConnecting || (_currentPrinterStatus == PrinterStatus.disconnected && !_hasError)) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                    ] else if (_currentPrinterStatus == PrinterStatus.ready || isProceedWarning) ...[
                      Icon( Icons.check_circle, size: 48, color: Colors.green[600]),
                      const SizedBox(height: 16),
                    ] else if (_hasError) ...[
                      Icon( Icons.error_outline, size: 48, color: Colors.red[600]),
                      const SizedBox(height: 16),
                    ] else if (_currentPrinterStatus == PrinterStatus.notFound || 
                               _currentPrinterStatus == PrinterStatus.connectionFailed) ...[
                       Icon( Icons.warning_amber, size: 48, color: Colors.orange[600]),
                       const SizedBox(height: 16),
                    ], 
                    
                    // Status message
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 16,
                        color: _hasError ? Colors.red[700] : (isProceedWarning ? Colors.green[700] : Colors.grey[700]),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Action buttons
              if (_canProceed) ...[ // Hanya tampilkan tombol hijau jika READY
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _proceedToLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward),
                        SizedBox(width: 8),
                        Text('Continue to App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ] else if (_hasError || _currentPrinterStatus == PrinterStatus.bluetoothOff) ...[ 
                // Tombol RETRY/LANJUT untuk error fatal atau BT Off
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _retryInitialization,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 8),
                            Text('Retry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _proceedWithoutPrinter,
                        style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Continue Without Printer', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ] else if (_currentPrinterStatus == PrinterStatus.notFound || 
                         _currentPrinterStatus == PrinterStatus.connectionFailed) ...[
                // Tombol SEARCH AGAIN/LANJUT untuk non-fatal failure
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _printerService.retryConnection(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search),
                            SizedBox(width: 8),
                            Text('Search Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _proceedWithoutPrinter,
                        style: TextButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Continue Without Printer', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Help text
              Text(
                'Make sure your printer RPP02N is turned on and nearby',
                style: TextStyle( fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}