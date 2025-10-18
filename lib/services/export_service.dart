import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_demantos/models/report_models.dart';
import 'package:intl/intl.dart';

class ExportService {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  // Export Sales Report to PDF
  Future<File> exportSalesReportToPDF(List<SalesReportData> data, String title) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Tanggal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total Penjualan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Transaksi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Rata-rata', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...data.map((item) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_dateFormat.format(item.date)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_currencyFormat.format(item.totalSales)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(item.totalTransactions.toString()),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_currencyFormat.format(item.averageTransaction)),
                    ),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Total Keseluruhan:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Penjualan: ${_currencyFormat.format(data.fold(0.0, (sum, item) => sum + item.totalSales))}'),
            pw.Text('Transaksi: ${data.fold(0, (sum, item) => sum + item.totalTransactions)}'),
          ];
        },
      ),
    );

    return _savePDF(pdf, 'sales_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  // Export Sales Report (simple method for compatibility)
  Future<File> exportSalesReport(List<SalesReportData> data) async {
    return exportSalesReportToPDF(data, 'Laporan Penjualan');
  }

  // Export Expense Report to PDF
  Future<File> exportExpenseReportToPDF(List<ExpenseReportData> data, String title) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Tanggal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total Pengeluaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Jumlah Entry', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...data.map((item) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_dateFormat.format(item.date)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_currencyFormat.format(item.totalExpenses)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(item.totalExpenseEntries.toString()),
                    ),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Total Pengeluaran: ${_currencyFormat.format(data.fold(0.0, (sum, item) => sum + item.totalExpenses))}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ];
        },
      ),
    );

    return _savePDF(pdf, 'expense_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  // Export Profit/Loss Report to PDF
  Future<File> exportProfitLossReportToPDF(List<ProfitLossReportData> data, String title) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Tanggal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Pendapatan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Pengeluaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Laba Bersih', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Margin (%)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...data.map((item) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_dateFormat.format(item.date)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_currencyFormat.format(item.totalRevenue)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(_currencyFormat.format(item.totalExpenses)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        _currencyFormat.format(item.netProfit),
                        style: pw.TextStyle(
                          color: item.netProfit >= 0 ? PdfColors.green : PdfColors.red,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('${item.profitMargin.toStringAsFixed(1)}%'),
                    ),
                  ],
                )),
              ],
            ),
          ];
        },
      ),
    );

    return _savePDF(pdf, 'profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  // Export to CSV
  Future<File> exportToCSV(List<Map<String, dynamic>> data, String filename) async {
    if (data.isEmpty) {
      throw Exception('No data to export');
    }

    final headers = data.first.keys.toList();
    final csvContent = StringBuffer();

    // Add headers
    csvContent.writeln(headers.join(','));

    // Add data rows
    for (var row in data) {
      final values = headers.map((header) => '"${row[header] ?? ''}"').toList();
      csvContent.writeln(values.join(','));
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(csvContent.toString());

    return file;
  }

  Future<File> _savePDF(pw.Document pdf, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
