import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for TextInputFormatter
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'product_model.dart';
import 'api_service.dart';
import 'api_config.dart';
import 'dart:io';

import 'LoginPage.dart';

class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  _CashierPageState createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  // ALL METHODS AND WIDGETS GO INSIDE HERE
  final inv = Hive.box('inventory');
  // Use a List of Maps for cart items, ensuring each map represents a unique product.
  final cart = <Map>[];

  // List of available categories based on your design
  final List<String> categories = ['ALL', 'FOOD', 'DRINKS', 'THINGS'];
  String _selectedCategory = 'ALL';

  Future<String>? _documentsPathFuture;
  Future<String> get _documentsPath => _documentsPathFuture ??= getApplicationDocumentsDirectory().then((d) => d.path);

  // Calculate total: sum of (price * qty) for all items in cart
  int get total =>
      cart.fold<int>(0, (s, e) => s + (e['price'] as int) * (e['qty'] as int));

  void _logOut() {
    Navigator.pushAndRemoveUntil(
      context,
      // Changed target to LoginPage without passing a role.
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  // --- CART MANAGEMENT LOGIC ---
  Widget _buildProductImage(Map item) {
    final path = (item['imagePath'] ?? item['image_path'])?.toString().trim();
    if (path == null || path.isEmpty) {
      return const Icon(Icons.image_not_supported, size: 40);
    }
    // Server-uploaded image (from upload API)
    if (path.startsWith('uploads/') || path.startsWith('http')) {
      final url = path.startsWith('http') ? path : '${ApiConfig.uploadsBaseUrl}/$path';
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 40),
      );
    }
    // Full path on device
    if (path.startsWith('/data/') || path.startsWith('/var/mobile')) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 40),
      );
    }
    // Filename: try bundled asset first, then app documents (user-added images)
    return Image.asset(
      'assets/images/$path',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return FutureBuilder<String>(
          future: _documentsPath,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Icon(Icons.image_not_supported, size: 40);
            }
            final filePath = p.join(snap.data!, path);
            return Image.file(
              File(filePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 40),
            );
          },
        );
      },
    );
  }

  /// Extracts yyyy-MM-dd from date string (handles "2026-01-31 17:36:57", ISO, etc.)
  String _extractDateKey(dynamic d) {
    final s = d?.toString() ?? '';
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }

  /// Merges local Hive transactions with server (API) so receipt history persists after restart.
  Future<List<Map>> _getMergedTransactions() async {
    final txBox = Hive.box('transactions');
    final local = txBox.values.cast<Map>().toList();
    List<Map<String, dynamic>> api = [];
    try {
      api = await ApiService.getTransactions();
    } catch (_) {}
    final ids = local.map((e) => e['id'].toString()).toSet();
    for (final tx in api) {
      if (!ids.contains(tx['id'].toString())) local.add(Map<String, dynamic>.from(tx));
    }
    local.sort((a, b) => _extractDateKey(b['date']).compareTo(_extractDateKey(a['date'])));
    return local;
  }

  void _showTransactionHistory() {
    final txBox = Hive.box('transactions');

    showDialog(
      context: context,
      builder: (context) {
        DateTime selectedDate = DateTime.now();

        return FutureBuilder<List<Map>>(
          future: _getMergedTransactions(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const AlertDialog(
                content: SizedBox(width: 200, height: 80, child: Center(child: CircularProgressIndicator())),
              );
            }
            final allTransactions = snap.data!;

            return StatefulBuilder(
              builder: (context, setDialogState) {
                final selectedKey = _extractDateKey(selectedDate);
                final filteredTransactions = allTransactions
                    .where((tx) => _extractDateKey(tx['date']) == selectedKey)
                    .toList()
                    .reversed
                    .toList();

            // --- Date Picker Helper Function ---
            Future<void> _selectDate() async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2023), // Define your start year
                lastDate: DateTime.now(),
              );
              if (picked != null && picked != selectedDate) {
                setDialogState(() {
                  selectedDate = picked;
                });
              }
            }
            // ------------------------------------
            
            return AlertDialog(
              // 2. Add the Date Picker to the title area (using Row for left/right alignment)
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Receipt History'),
                  // Date Picker Button
                  TextButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      // Display the selected date clearly (e.g., YYYY-MM-DD)
                      selectedDate.toString().substring(0, 10),
                    ),
                  ),
                ],
              ),
              
              content: SizedBox(
                width: 400,
                height: 600,
                child: filteredTransactions.isEmpty
                    ? Center(
                        child: Text('No transactions recorded on ${selectedDate.toString().substring(0, 10)}.'),
                      )
                    : ListView.separated(
                        itemCount: filteredTransactions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, thickness: 1),
                        itemBuilder: (context, index) {
                          final tx = filteredTransactions[index]; // Use filtered list
                          
                          // 3. Your simplified ListTile logic (from the last step)
                          final String rawId = tx['id'].toString();
                          final String displayId = rawId.length > 8
                              ? 'TXR-${rawId.substring(0, 8).toUpperCase()}'
                              : 'TXR-$rawId'; 
                          final String displayDate = tx['date'].toString().substring(0, 10);
                          
                          return ListTile(
                            onTap: () => _showReceipt(tx),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              'Transaction ID: $displayId', 
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              'Date: $displayDate',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
              },
            );
          },
        );
      },
    );
  }

  // Helper function to build the rows within the history list tile
  Widget _buildHistoryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _addToCart(Map item) {
    final String itemId = item['id'] as String; // Ensure ID is used

    // 1. Get the current inventory item from the main box.
    //    This always gives the most up-to-date stock.
    final Map? currentInventoryItem = inv.get(itemId);

    if (currentInventoryItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Product "${item['name']}" not found in inventory.')),
      );
      return;
    }

    final int availableStock = currentInventoryItem['stock'] as int;

    // Find if the item is already in the cart
    final int cartIndex = cart.indexWhere((c) => c['id'] == itemId);

    if (cartIndex != -1) {
      // Item already in cart: Check if we can increment quantity
      final int currentCartQty = cart[cartIndex]['qty'] as int;

      if (currentCartQty < availableStock) {
        // If there's available stock for one more item
        setState(() {
          cart[cartIndex]['qty'] += 1;
        });
        print('Incremented ${item['name']}. New cart qty: ${cart[cartIndex]['qty']}');
      } else {
        // Stock limit reached for this item
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough stock for ${item['name']}. Available: $availableStock')),
        );
        print('Stock limit reached for ${item['name']}. Available: $availableStock, In cart: $currentCartQty');
      }
    } else {
      // Item is new to cart: Check if there's any stock to add it for the first time
      if (availableStock > 0) {
        setState(() {
          cart.add({
            'id': item['id'],
            'name': item['name'],
            'price': item['price'],
            'qty': 1,
          });
        });
        print('Added new item ${item['name']} with qty: 1');
      } else {
        // Item is completely out of stock
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item['name']} is out of stock.')),
        );
        print('${item['name']} is out of stock. Cannot add.');
      }
    }
  }

  void _updateCartQuantity(int index, int change) {
    // 1. Get item details from the cart
    final cartItem = cart[index];
    final String itemId = cartItem['id'] as String;
    final String itemName = cartItem['name'] as String;
    
    // 2. Get the current inventory item from the main box.
    final Map? currentInventoryItem = inv.get(itemId);

    if (currentInventoryItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Product "$itemName" not found in inventory.')),
      );
      return;
    }
    
    final int availableStock = currentInventoryItem['stock'] as int;

    setState(() {
      final int currentQty = cartItem['qty'] as int;
      final int newQty = currentQty + change;

      // --- CHECK STOCK LIMITS ---
      if (change > 0) {
        // If incrementing (+)
        if (newQty <= availableStock) {
          // Allow increment if new quantity is within stock limit
          cart[index]['qty'] = newQty;
          print('Updated ${itemName}: new qty $newQty');
        } else {
          // Block if stock limit reached
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot add more ${itemName}. Stock limit reached ($availableStock)')),
          );
          print('Stock limit reached for ${itemName}. Cannot update to $newQty');
        }
      } else if (change < 0) {
        // If decrementing (-)
        if (newQty > 0) {
          // Allow decrement if new quantity is still above zero
          cart[index]['qty'] = newQty;
          print('Updated ${itemName}: new qty $newQty');
        } else {
          // Remove item if quantity drops to 0 or below
          cart.removeAt(index);
          print('Removed ${itemName} from cart.');
        }
      }
      // If change is 0, nothing happens
    });
  }

  void _removeItemFromCart(int index) {
    setState(() => cart.removeAt(index));
  }

  // --- TRANSACTION CONFIRMATION & SAVING LOGIC ---

  Future<void> _confirmPayment(String paymentMethod) async {
    if (cart.isEmpty) return;

    final txBox = Hive.box('transactions');
    final now = DateTime.now();
    final txId = const Uuid().v4();

    final tx = {
      'id': txId,
      'date': now.toIso8601String(),
      'total': total,
      'paymentMethod': paymentMethod,
      'synced': false,
      'items': cart
          .map(
            (e) => {
              'id': e['id'],
              'name': e['name'],
              'qty': e['qty'],
              'price': e['price'],
              'subtotal': e['price'] * e['qty'],
            },
          )
          .toList(),
    };
    txBox.put(txId, tx);

    // Update local inventory
    for (var c in cart) {
      final item = inv.get(c['id']);
      if (item != null) {
        inv.put(c['id'], {
          ...item,
          'stock': (item['stock'] as int) - (c['qty'] as int),
        });
      }
    }

    // Auto-push to API immediately so we never lose transactions
    final ok = await ApiService.saveTransaction(Map<String, dynamic>.from(tx));
    if (ok) {
      tx['synced'] = true;
      txBox.put(txId, tx);
    }

    _showReceipt(tx);
    setState(() => cart.clear());
  }

  // --- PAYMENT MODALS / DIALOGS ---

  // NOTE: You are missing a way to pass the 'change' variable from _checkoutCash
  // to _confirmPayment and then to _showReceipt. We'll fix that.

 void _showReceipt(Map tx) {
  final List items = (tx['items'] as List?) ?? [];

  showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          title: const Text('Struk Pembayaran (Receipt)'),
          content: SizedBox(
            width: 300,
            // The Column itself must now be scrollable to contain all content,
            // but we need to ensure the AlertDialog doesn't try to take infinite height.
            // Since the entire content is wrapped in a Column, we'll wrap the 
            // inner list of items to limit its size.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanggal: ${tx['date'].toString().substring(0, 10)}'),
                Text('Metode Pembayaran: ${tx['paymentMethod']}'),
                const Divider(),
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                // 🎯 FIX: START OF SCROLLABLE ITEMS 🎯
                SizedBox(
                  // Use a fixed max height for the list of items
                  // Adjust this value (e.g., 250) based on your desired look
                  height: 250, 
                  child: ListView.builder(
                    // Important for ListView inside a constrained Column
                    shrinkWrap: true, 
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Use Expanded to prevent horizontal overflow for long names
                            Expanded(child: Text('${item['name']} x ${item['qty']}')), 
                            Text('Rp ${item['subtotal']}'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // 🎯 FIX: END OF SCROLLABLE ITEMS 🎯

                const Divider(),
                Text(
                  'Total: Rp ${tx['total']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                // The receipt now correctly checks for 'change' in the transaction map
                if (tx['paymentMethod'] == 'Cash' && tx.containsKey('change'))
                  Text(
                    'Kembali: Rp ${tx['change']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup (Selesai)'),
            ),
          ],
        ),
  );
}

  // void _checkoutQRIS() {
  //   final payload = const Uuid().v4();
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder:
  //         (context) => AlertDialog(
  //           title: const Text('QRIS Pembayaran'),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               // FIX: Wrap QrImageView in a SizedBox to explicitly enforce constraints
  //               SizedBox(
  //                 width: 250, // Giving the QR code a definite container size
  //                 height: 250,
  //                 child: QrImageView(data: payload, size: 200),
  //               ),
  //               const SizedBox(height: 12),
  //               Text(
  //                 'Total: Rp $total',
  //                 style: const TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text('Batal'),
  //             ),
  //             ElevatedButton(
  //               onPressed: () {
  //                 Navigator.pop(context);
  //                 // Pass a change of 0 for non-cash transactions
  //                 Future.delayed(
  //                   const Duration(milliseconds: 100),
  //                   () => _confirmPayment('QRIS'),
  //                 );
  //               },
  //               child: const Text('Print Receipt (Simulate Payment)'),
  //             ),
  //           ],
  //         ),
  //   );
  // }

  // void _checkoutCard() {
  //   final cardNumberC = TextEditingController();
  //   final cardHolderC = TextEditingController();
  //   String detectedCardType = '';

  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (context, setState) {
  //           final canPrint = cardNumberC.text.length >= 13;

  //           return AlertDialog(
  //             title: const Text('Pembayaran Kartu (Card)'),
  //             content: SingleChildScrollView(
  //               child: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Align(
  //                     alignment: Alignment.centerRight,
  //                     child: Text(
  //                       'Rp ${total}',
  //                       style: const TextStyle(
  //                         fontSize: 18,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                   ),
  //                   const Divider(),

  //                   // Card Type Field (DISABLED, but text is forced to be black/dark)
  //                   // NOTE: Removed the `counterText` hack and fixed the controller setting
  //                   TextField(
  //                     decoration: InputDecoration(
  //                       labelText: 'Card Type',
  //                       hintText: 'Detected Card Type',
  //                       // Use a key to force the TextField to rebuild when detectedCardType changes
  //                       suffixText:
  //                           detectedCardType.isEmpty
  //                               ? 'Unknown'
  //                               : detectedCardType,
  //                       suffixStyle: const TextStyle(
  //                         color: Colors.black,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                     enabled: false,
  //                   ),
  //                   const SizedBox(height: 12),

  //                   // Card Number Field
  //                   TextField(
  //                     controller: cardNumberC,
  //                     keyboardType: TextInputType.number,
  //                     decoration: const InputDecoration(
  //                       labelText: 'Card Number',
  //                       hintText: 'Insert card number.',
  //                     ),
  //                     onChanged: (value) {
  //                       setState(() {
  //                         // Use the dialog's local setState
  //                         detectedCardType = detectCardType(value);
  //                       });
  //                     },
  //                   ),
  //                   const SizedBox(height: 12),

  //                   // Card Holder Name (NOW ENABLED / FUNCTIONING)
  //                   TextField(
  //                     controller: cardHolderC,
  //                     decoration: const InputDecoration(
  //                       labelText: 'Card Holder Name',
  //                       hintText: 'Enter card holder name.',
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context),
  //                 child: const Text('Batal'),
  //               ),
  //               ElevatedButton(
  //                 onPressed:
  //                     canPrint
  //                         ? () {
  //                           Navigator.pop(context);
  //                           // Pass a change of 0 for non-cash transactions
  //                           Future.delayed(
  //                             const Duration(milliseconds: 100),
  //                             () => _confirmPayment('Card'),
  //                           );
  //                         }
  //                         : null,
  //                 child: const Text('Print Receipt'),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  Future<void> _confirmPaymentWithChange(String paymentMethod, {int change = 0}) async {
    if (cart.isEmpty) return;

    final txBox = Hive.box('transactions');
    final now = DateTime.now();
    final txId = const Uuid().v4();
    final tx = {
      'id': txId,
      'date': now.toIso8601String(),
      'total': total,
      'paymentMethod': paymentMethod,
      'change': change,
      'synced': false,
      'items': cart
          .map(
            (e) => {
              'id': e['id'],
              'name': e['name'],
              'qty': e['qty'],
              'price': e['price'],
              'subtotal': e['price'] * e['qty'],
            },
          )
          .toList(),
    };
    txBox.put(txId, tx);

    for (var c in cart) {
      final item = inv.get(c['id']);
      if (item != null) {
        inv.put(c['id'], {
          ...item,
          'stock': (item['stock'] as int) - (c['qty'] as int),
        });
      }
    }

    final ok = await ApiService.saveTransaction(Map<String, dynamic>.from(tx));
    if (ok) {
      tx['synced'] = true;
      txBox.put(txId, tx);
    }

    _showReceipt(tx);
    setState(() => cart.clear());
  }

  void _checkoutCash() {
    final receivedC = TextEditingController();

    // Show the cash payment dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          // Use StatefulBuilder to update the dialog's state
          builder: (context, setState) {
            final receivedAmount = int.tryParse(receivedC.text) ?? 0;
            final change = receivedAmount - total; // Calculate change directly
            final canPrint = receivedAmount >= total;

            return AlertDialog(
              title: const Text('Pembayaran Tunai (Cash)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Belanja: Rp $total',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  TextField(
                    controller: receivedC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Uang Diterima (Received)',
                      prefixText: 'Rp ',
                    ),
                    onChanged:
                        (value) => setState(
                          () {},
                        ), // Call setState to trigger recalculation
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kembali (Change): Rp ${change.toString()}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed:
                      canPrint
                          ? () {
                            Navigator.pop(context);
                            // CALL THE NEW METHOD and pass the calculated change
                            _confirmPaymentWithChange('Cash', change: change);
                          }
                          : null,
                  child: const Text('Print Receipt'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // The initial checkout button that shows the payment selection modal
  void _showPaymentSelection() {
    if (cart.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            title: Center(
              child: Column(
                children: const [
                  Text(
                    "Receipt",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "POS 🛒",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ========= TOTAL =============
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Rp $total",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(thickness: 1),

                const SizedBox(height: 10),
                const Text(
                  "Payment Method",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),

                // ================= Payment Buttons =================
                Row(
                  children: [
                    _paymentSquareButton(
                      label: "QRIS",
                      icon: Icons.qr_code,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmPayment('QRIS');
                      },
                    ),
                    const SizedBox(width: 8),
                    _paymentSquareButton(
                      label: "Cash",
                      icon: Icons.money,
                      onTap: () {
                        Navigator.pop(context);
                        _checkoutCash();
                      },
                    ),
                    const SizedBox(width: 8),
                    _paymentSquareButton(
                      label: "Card",
                      icon: Icons.credit_card,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmPayment('Card');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _paymentSquareButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier'),
        centerTitle: true, // Center the title for a cleaner look
        actions: [
          // THE HISTORY ICON
          IconButton(
            icon: const Icon(Icons.history), // The clock/history icon
            onPressed: _showTransactionHistory, // Call the history function
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logOut, // Call the log out function
            tooltip: 'Log Out',
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        // The original layout Row with the two Expanded children (Product Grid and Cart)
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: Inventory Grid (Flex 2)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // 1. Category Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 8.0,
                    ),
                    child: SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (_, i) {
                          final category = categories[i];
                          final isSelected = category == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedCategory = category);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 2. Product Grid
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: inv.listenable(),
                      builder: (_, box, __) {
                        final allItems = inv.values.cast<Map>().toList();
                        final filteredItems =
                            _selectedCategory == 'ALL'
                                ? allItems
                                : allItems
                                    .where(
                                      (item) =>
                                          item['category'] == _selectedCategory,
                                    )
                                    .toList();
                                    
                        final currentlyAvailableItems = filteredItems.where((item) => item['stock'] > 0).toList();

                        if (currentlyAvailableItems.isEmpty) {
                          return Center(
                            child: Text(
                              'Tidak ada barang di kategori "$_selectedCategory".',
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8.0,
                                mainAxisSpacing: 8.0,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: currentlyAvailableItems.length,
                          itemBuilder: (_, i) {
                            final item = currentlyAvailableItems[i];
                            final isOutOfStock = item['stock'] <= 0;

                            return Card(
                              key: ValueKey(item['id']),
                              child: InkWell(
                                onTap:
                                    isOutOfStock
                                        ? null
                                        : () => _addToCart(Map.from(item)),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Center(
                                          child: _buildProductImage(item),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Rp ${item['price']}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        'Stok: ${item['stock']}',
                                        style: TextStyle(
                                          color:
                                              isOutOfStock
                                                  ? Colors.red
                                                  : Colors.grey,
                                        ),
                                      ),
                                      if (!isOutOfStock)
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.add_circle,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () => _addToCart(item),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            const VerticalDivider(width: 1),

            // RIGHT: Cart (Flex 1)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Cart List
                    Expanded(
                      child:
                          cart.isEmpty
                              ? const Center(child: Text('Keranjang kosong.'))
                              : ListView.builder(
                                itemCount: cart.length,
                                itemBuilder: (_, i) {
                                  final c = cart[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text('Rp ${c['price']}'),
                                            ],
                                          ),
                                        ),

                                        // Quantity Controls
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove,
                                                size: 18,
                                              ),
                                              onPressed:
                                                  () => _updateCartQuantity(
                                                    i,
                                                    -1,
                                                  ),
                                            ),
                                            Text(
                                              '${c['qty']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add,
                                                size: 18,
                                              ),
                                              onPressed:
                                                  () =>
                                                      _updateCartQuantity(i, 1),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                              onPressed:
                                                  () => _removeItemFromCart(i),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                    const Divider(),
                    // Total and Checkout Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rp $total',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white, // <=== tambahkan ini
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: cart.isEmpty ? null : _showPaymentSelection,
                        child: const Text('Check Out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
