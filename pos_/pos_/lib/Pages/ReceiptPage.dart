import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ReceiptPage extends StatelessWidget {
  final Map tx;
  const ReceiptPage({super.key, required this.tx});
  @override
  Widget build(BuildContext context) {
    final items = (tx['items'] as List).cast<Map>();
    return Scaffold(
      appBar: AppBar(title: Text('Struk')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tanggal: ${tx['date']}'),
            SizedBox(height: 8),
            ...items.map(
              (it) =>
                  Text('${it['name']} x ${it['qty']} • Rp ${it['subtotal']}'),
            ),
            Divider(),
            Text(
              'Total: Rp ${tx['total']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
