import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const AwamiInstallmentApp());
}

class AwamiInstallmentApp extends StatelessWidget {
  const AwamiInstallmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Awami Installment',
      theme: ThemeData(primarySwatch: Colors.deepOrange, useMaterial3: true),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Database _db;
  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'installment_db.sqlite');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS Customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            cnic TEXT,
            phone TEXT,
            item TEXT,
            total_amount REAL,
            paid_amount REAL,
            monthly_installment REAL
          )
        ''');
      },
    );
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final data = await _db.query('Customers');
    setState(() {
      _customers = data;
    });
  }

  Future<void> _generatePdfAndShare(Map<String, dynamic> customer, double installmentPaid) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          double remaining = customer['total_amount'] - (customer['paid_amount'] + installmentPaid);
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("AWAMI INSTALLMENT - RECEIPT", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text("Customer Name: ${customer['name']}"),
                pw.Text("Phone: ${customer['phone']}"),
                pw.Text("Item: ${customer['item']}"),
                pw.SizedBox(height: 10),
                pw.Text("Installment Paid: Rs. $installmentPaid", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Remaining Balance: Rs. $remaining"),
                pw.SizedBox(height: 20),
                pw.Text("Thank you for your payment!"),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Receipt_${customer['name']}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Awami Installment Mobile')),
      body: ListView.builder(
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          final c = _customers[index];
          double remaining = c['total_amount'] - c['paid_amount'];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Item: ${c['item']} | Remaining: Rs. $remaining"),
              trailing: IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
                onPressed: () => _showPaymentDialog(c),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showPaymentDialog(Map<String, dynamic> customer) {
    final amountController = TextEditingController(text: customer['monthly_installment'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Receive Payment - ${customer['name']}"),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Amount Received (Rs)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              double paid = double.tryParse(amountController.text) ?? 0.0;
              if (paid > 0) {
                double newTotalPaid = customer['paid_amount'] + paid;
                await _db.update(
                  'Customers',
                  {'paid_amount': newTotalPaid},
                  where: 'id = ?',
                  whereArgs: [customer['id']],
                );
                Navigator.pop(ctx);
                _loadCustomers();
                _generatePdfAndShare(customer, paid);
              }
            },
            child: const Text("Save & Share Receipt"),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final monthlyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Customer"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Customer Name")),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Phone Number")),
              TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: "Item Name")),
              TextField(controller: totalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Total Amount")),
              TextField(controller: monthlyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Monthly Installment")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _db.insert('Customers', {
                'name': nameCtrl.text,
                'phone': phoneCtrl.text,
                'item': itemCtrl.text,
                'total_amount': double.tryParse(totalCtrl.text) ?? 0.0,
                'paid_amount': 0.0,
                'monthly_installment': double.tryParse(monthlyCtrl.text) ?? 0.0,
              });
              Navigator.pop(ctx);
              _loadCustomers();
            },
            child: const Text("Save Customer"),
          ),
        ],
      ),
    );
  }
}
