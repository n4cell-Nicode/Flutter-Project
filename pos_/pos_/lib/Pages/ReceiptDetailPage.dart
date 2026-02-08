import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceiptDetailPage extends StatelessWidget {
  final Map transaction;

  const ReceiptDetailPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final total = transaction['total'] as int;
    final date = transaction['date'] ?? 'N/A';
    final time = transaction['time'] ?? 'N/A';
    final items = transaction['items'] as List<Map>? ?? [];
    final transactionId = transaction['transactionId'] ?? 'N/A';

    // Placeholder Receipt Number (since it wasn't in the transaction data)
    final receiptNo = '#A${transactionId.substring(transactionId.length - 4)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Detail'), centerTitle: true),
      body: Center(
        child: Container(
          width: 400, // Fixed width for a receipt
          padding: const EdgeInsets.all(20.0),
          margin: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'POS🛒',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const Text('Jl. POS, Medan', textAlign: TextAlign.center),
              const Text('NPWP: 0017110628092000', textAlign: TextAlign.center),
              Text('Receipt No: $receiptNo', textAlign: TextAlign.center),
              const Divider(),

              // Items List
              ...items.map((item) {
                final itemName = item['name'] as String;
                final quantity = item['quantity'] as int;
                final price = item['price'] as int;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$quantity x $itemName'),
                      Text(
                        'Rp ${NumberFormat('#,##0').format(price * quantity)}',
                      ),
                    ],
                  ),
                );
              }),

              // Summary
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rp ${NumberFormat('#,##0').format(total)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // Quantity Purchased - Sum up all item quantities
              Text(
                'Quantity Purchased: ${items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int))}',
                textAlign: TextAlign.right,
              ),
              const Divider(),

              // Footer Message
              const Text(
                'Thank you for shopping at POS\nPrices include VAT/Tax\nKeep your receipt for reward points collection!',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const Divider(),

              // Transaction Info
              Text(
                'Transaction ID : $transactionId',
                textAlign: TextAlign.center,
              ),
              Text('Time: $time, Date: $date', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
