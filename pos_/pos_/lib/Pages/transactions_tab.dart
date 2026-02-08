import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'ReceiptPage.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({Key? key}) : super(key: key);

  @override
  _TransactionsTabState createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  late Box txBox;

  @override
  void initState() {
    super.initState();
    txBox = Hive.box('transactions');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: txBox.listenable(),
      builder: (_, box, __) {
        final keys = txBox.keys.cast<String>().toList();
        return ListView.builder(
          itemCount: keys.length,
          itemBuilder: (_, i) {
            final tx = txBox.get(keys[i]);
            // Ensure all required fields are safely cast/accessed
            final String transactionId = tx['id'].toString();
            final String date = tx['date'] ?? 'N/A';
            
            // The current date in the transaction ID is messy, let's use the first 8 characters of the ID
            final String displayId = transactionId.length > 8 ? transactionId.substring(0, 8) : transactionId;

            return ListTile(
              // Keep the onTap function to retain the flow to ReceiptPage/detail dialog
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReceiptPage(tx: tx)), // Or wherever you navigate for detail
                );
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              
              // Primary display: Transaction ID (simplified)
              title: Text(
                'ID: $displayId',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              
              // Secondary display: Transaction Date
              subtitle: Text(
                'Tanggal: $date',
                style: TextStyle(color: Colors.grey[700]),
              ),
              
              // Optional: Add a subtle icon to indicate it's clickable
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              
              // Simplify the card by removing unnecessary complexity from the original design
            );
          },
        );
      }
    );
  }
}
