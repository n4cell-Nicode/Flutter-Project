import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ReceiptDetailPage.dart';

class DailyTransactionsPage extends StatelessWidget {
  final String date;
  final String dayName;
  final List<Map> transactions;

  const DailyTransactionsPage({
    super.key,
    required this.date,
    required this.dayName,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$dayName, $date'), centerTitle: true),
      body: ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final txn = transactions[index];

          // Assuming time is stored like "HH:mm" (e.g., 17:15)
          final time = txn['time'] ?? 'N/A';
          final total = txn['total'] as int;
          final payment = txn['paymentMethod'] ?? 'N/A';

          return InkWell(
            onTap: () {
              // Navigate to Level 3: ReceiptDetailPage
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptDetailPage(transaction: txn),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.only(bottom: 1.0),
              color:
                  index.isOdd
                      ? Colors.white
                      : Colors.grey.shade100, // alternating colors
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTxnRow('Transaction ID', txn['transactionId']),
                        _buildTxnRow(
                          'Total',
                          'Rp ${NumberFormat('#,##0').format(total)}',
                        ),
                        _buildTxnRow('Date', '$date - $time'),
                        _buildTxnRow('Payment', payment),
                        _buildTxnRow(
                          'Status',
                          txn['status'],
                          color: Colors.green.shade700,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.receipt,
                    color: Colors.blue,
                  ), // Icon to signify receipt view
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper widget to build the detail rows
  Widget _buildTxnRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
