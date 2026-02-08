import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'product_model.dart';
import 'api_service.dart';
import 'api_config.dart';
import 'LoginPage.dart';
import 'dart:io';

class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  final logBox = Hive.box('inventory_changes');
  List<Product> products = []; 
  bool _isLoading = true;
  bool _isSyncing = false; // indicates when manual sync with server is running

  final inv = Hive.box('inventory');
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  List<String> _categories = ['ALL', 'FOOD', 'DRINKS', 'THINGS'];
  Product? _itemToEdit;
  String _formImagePath = '';
  Future<String>? _documentsPathFuture;
  Future<String> get _documentsPath => _documentsPathFuture ??= getApplicationDocumentsDirectory().then((d) => d.path);

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    // Auto-sync when Admin loads so cashier transactions appear without manual sync
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWithServer());
  }

  void _fetchInventory() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getInventory();
    setState(() {
      products = data;
      _isLoading = false;
    });
  }

  Future<void> _logchange(String action, String itemId, String itemName, String details) async {
    final now = DateTime.now();
    final timeString = DateFormat('HH:mm:ss').format(now);
    final dateString = DateFormat('dd MMM yyyy').format(now);

    final entry = {
      'id': const Uuid().v4(),
      'action': action,
      'itemId': itemId,
      'itemName': itemName,
      'details': details,
      'time': timeString,
      'date': dateString,
      'synced': false,
    };
    final key = await logBox.add(entry);
    final ok = await ApiService.saveInventoryChange(entry);
    if (ok) { entry['synced'] = true; await logBox.put(key, entry); }
    if (mounted) setState(() {});
  }

  /// Manually synchronizes local data with the backend:
  /// - Pushes any unsynced transactions from Hive to the API.
  /// - Refreshes the local `inventory` Hive box from the server inventory.
  Future<void> _syncWithServer() async {
    setState(() {
      _isSyncing = true;
    });

    final txBox = Hive.box('transactions');
    final invBox = Hive.box('inventory');

    int pushed = 0;
    int failed = 0;

    // 1. Push unsynced transactions to backend
    for (final key in txBox.keys) {
      final raw = txBox.get(key);
      if (raw is! Map) continue;

      // Only consider transactions explicitly marked as not yet synced
      if (raw['synced'] == true) continue;

      // Convert to Map<String, dynamic> for the API
      final tx = Map<String, dynamic>.from(raw);

      final ok = await ApiService.saveTransaction(tx);
      if (ok) {
        // Mark as synced locally
        tx['synced'] = true;
        await txBox.put(key, tx);
        pushed++;
      } else {
        failed++;
      }
    }

    // 2. Push unsynced inventory changes to backend
    final logBox = Hive.box('inventory_changes');
    for (final key in logBox.keys) {
      final raw = logBox.get(key);
      if (raw is Map && raw['synced'] != true) {
        final entry = Map<String, dynamic>.from(raw);
        final ok = await ApiService.saveInventoryChange(entry);
        if (ok && mounted) {
          entry['synced'] = true;
          await logBox.put(key, entry);
        }
      }
    }

    // 3. Refresh local inventory from server
    List<Product> remoteProducts = [];
    try {
      remoteProducts = await ApiService.getInventory();
    } catch (_) {
      // If this fails we still want to show the transaction sync result
    }

    if (remoteProducts.isNotEmpty) {
      // Preserve local image paths before clear (API may not return them all)
      final Map<String, String?> savedImagePaths = {};
      for (final key in invBox.keys) {
        final m = invBox.get(key) as Map?;
        if (m != null) {
          final path = m['imagePath'] ?? m['image_path'];
          if (path != null && path.toString().isNotEmpty) {
            savedImagePaths[m['id']?.toString() ?? key.toString()] = path.toString();
          }
        }
      }
      await invBox.clear();

      for (final product in remoteProducts) {
        invBox.put(product.id, {
          'id': product.id,
          'name': product.name,
          'price': product.price,
          'stock': product.stock,
          'category': product.category,
          'imagePath': product.imagePath ?? savedImagePaths[product.id],
        });
      }
    }

    setState(() {
      _isSyncing = false;
    });

    if (!mounted) return;

    // 3. Show a short summary of the sync result
    final msg = remoteProducts.isEmpty
        ? 'Sync complete. Transactions: $pushed synced, $failed failed. (Inventory refresh skipped)'
        : 'Sync complete. Transactions: $pushed synced, $failed failed. Inventory refreshed.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _extractDateKey(dynamic d) {
    final s = d?.toString() ?? '';
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }

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

  // --- Utility Methods ---

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _showReceipt(Map tx) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Struk Pembayaran (Receipt)'),
            content: SizedBox(
              width: 300,
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
                  ...(tx['items'] as List<dynamic>).map<Widget>(
                    (it) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${it['name']} x ${it['qty']}'),
                          Text('Rp ${it['subtotal']}'),
                        ],
                      ),
                    ),
                  ),
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

  void _logOut() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false, 
    );
  }

  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery,
      imageQuality: 50, // Reduce quality to 50% (Recommended)
      maxWidth: 600,
    );

    if (image != null) {
      setState(() {
        _formImagePath = image.path; // Store the full temporary file path
      });
    }
  }

  // Method to add or update an item
  void _saveItem() async {
    final name = _nameController.text;
    final price = int.tryParse(_priceController.text) ?? 0;
    final stock = int.tryParse(_stockController.text) ?? 0;

    if (name.isEmpty || price <= 0 || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly.')),
      );
      return;
    }

    String imageToSave = '';
    final newId = _itemToEdit?.id ?? const Uuid().v4();

    // --- IMAGE LOGIC: Upload to server API when local file; otherwise keep existing path ---
    if (!kIsWeb && _formImagePath.isNotEmpty && !_formImagePath.startsWith('blob:')) {
      // Any absolute path: Unix (/ or \), Android (/data, /storage), Windows (C:\...)
      final isAbsolutePath = _formImagePath.startsWith('/') ||
          _formImagePath.startsWith(r'\') ||
          (_formImagePath.length > 2 && _formImagePath[1] == ':');
      final pathToCopy = _formImagePath;
      if (isAbsolutePath) {
        // Upload image to server API; fall back to local copy if upload fails
        final uploadedPath = await ApiService.uploadProductImage(pathToCopy);
        if (uploadedPath != null && uploadedPath.isNotEmpty) {
          imageToSave = uploadedPath;
        } else {
          try {
            final Directory appStorage = await getApplicationDocumentsDirectory();
            final String ext = p.extension(pathToCopy).isEmpty ? '.jpg' : p.extension(pathToCopy);
            final String fileName = 'img_$newId$ext';
            final String destPath = p.join(appStorage.path, fileName);
            await File(pathToCopy).copy(destPath);
            imageToSave = fileName;
          } catch (e) {
            print("Error copying image file: $e");
            if (_itemToEdit != null) imageToSave = _itemToEdit!.imagePath ?? '';
          }
        }
      } else {
        // Already a relative filename or server path (e.g. from edit form)
        imageToSave = _formImagePath;
      }
    } else if (!kIsWeb && _formImagePath.startsWith('blob:')) {
      imageToSave = _itemToEdit?.imagePath ?? '';
    }
    // On web with blob: we leave imageToSave empty (Add Product with image not fully supported on web)

    if (_itemToEdit == null) {
      // --- ADD NEW ITEM ---
      final productData = {
        'id': newId,
        'name': name,
        'price': price,
        'stock': stock,
        'category': _selectedCategory,
        if (imageToSave.isNotEmpty) 'imagePath': imageToSave,
      };

      bool success = await ApiService.addProduct(productData);
      if (success) {
        inv.put(newId, {
          'id': newId,
          'name': name,
          'price': price,
          'stock': stock,
          'category': _selectedCategory,
          'imagePath': imageToSave,
        });
        _logChange('ADD', newId, name, 'Price: Rp $price, Stock: $stock, Category: $_selectedCategory');
        _fetchInventory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add product on server.')),
        );
      }
    } else {
      // --- EDIT EXISTING ITEM ---
      final oldItem = _itemToEdit!;
      // When user didn't change image, send existing so backend doesn't overwrite with null
      final effectiveImagePath = imageToSave.isNotEmpty ? imageToSave : (oldItem.imagePath ?? '');

      String details = '';
      if (oldItem.name != name) details += 'Name: ${oldItem.name} -> $name; ';
      if (oldItem.price != price) details += 'Price: ${oldItem.price} -> $price; ';
      if (oldItem.stock != stock) details += 'Stock: ${oldItem.stock} -> $stock; ';
      if (oldItem.category != _selectedCategory) details += 'Category: ${oldItem.category} -> $_selectedCategory; ';

      bool success = await ApiService.updateProduct(
        oldItem.id, name, price, stock, _selectedCategory,
        effectiveImagePath.isNotEmpty ? effectiveImagePath : null,
      );

      if (success) {
        final existing = inv.get(oldItem.id) as Map? ?? {};
        inv.put(oldItem.id, {
          ...existing,
          'id': oldItem.id,
          'name': name,
          'price': price,
          'stock': stock,
          'category': _selectedCategory,
          'imagePath': effectiveImagePath.isNotEmpty ? effectiveImagePath : (existing['imagePath'] ?? oldItem.imagePath),
        });
        // 3. Log change only if actual changes were made
        if (details.isNotEmpty) {
          _logChange('EDIT', oldItem.id, name, details.trim());
        }
        // 4. Refresh the list from the server to show the update
        _fetchInventory(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update product on server.')),
        );
      }
    }

    _clearForm();
  }

  // Method to delete an item
  void _deleteItem(dynamic itemKey) {
    final itemToDelete = products.firstWhere((p) => p.id == itemKey.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${itemToDelete.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // 1. Delete from server first so it's gone from the inventory table
              final error = await ApiService.deleteProduct(itemToDelete.id);
              if (error != null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: ${error.length > 80 ? "${error.substring(0, 80)}..." : error}')),
                  );
                }
                Navigator.pop(context);
                return;
              }
              // 2. Log the change locally + backend (audit trail)
              await _logchange(
                'DELETE',
                itemToDelete.id,
                itemToDelete.name,
                'Item deleted from inventory.',
              );
              // 3. Remove from local Hive
              await inv.delete(itemKey);
              // 4. Refresh the list from server (item will no longer be returned)
              _fetchInventory();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted.')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Method to load item data into the form for editing
  void _editItem(Product product) {
    setState(() {
      _itemToEdit = product;
      _nameController.text = product.name;
      _priceController.text = product.price.toString();
      _stockController.text = product.stock.toString();
      _selectedCategory = product.category;
      _formImagePath = product.imagePath ?? '';
    });
  }

  // Method to clear the form fields and reset state
  void _clearForm() {
    setState(() {
      _itemToEdit = null;
      _nameController.clear();
      _priceController.clear();
      _stockController.clear();
      _selectedCategory = 'ALL'; // Reset category filter
      // FIX: Set to empty string for "Add Product" state
      _formImagePath = ''; 
    });
  }

  Widget _productLeading(Product product) {
    final imagePathVal = product.imagePath;
    if (imagePathVal == null || imagePathVal.isEmpty) {
      return const Icon(Icons.inventory, size: 50, color: Colors.blueGrey);
    }
    // Server-uploaded image (from upload API)
    if (imagePathVal.startsWith('uploads/') || imagePathVal.startsWith('http')) {
      final url = imagePathVal.startsWith('http')
          ? imagePathVal
          : '${ApiConfig.uploadsBaseUrl}/$imagePathVal';
      return SizedBox(
        width: 50,
        height: 50,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 50, color: Colors.blueGrey),
          ),
        ),
      );
    }
    // Full path on device (from local cache or edit form)
    if (imagePathVal.startsWith('/data/') || imagePathVal.startsWith('/var/mobile')) {
      return SizedBox(
        width: 50,
        height: 50,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(imagePathVal),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 50, color: Colors.blueGrey),
          ),
        ),
      );
    }
    // Filename only: try bundled asset first (Aice Mochi, etc.), then app documents (user-added images)
    return SizedBox(
      width: 50,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/images/$imagePathVal',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _ProductImageFromDocuments(documentsPath: _documentsPath, fileName: imagePathVal);
          },
        ),
      ),
    );
  }

  // Helper to record any inventory change (local + backend)
  void _logChange(String action, String itemId, String itemName, String details) {
    final logEntry = {
      'id': const Uuid().v4(),
      'timestamp': DateTime.now().toIso8601String(),
      'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
      'time': DateFormat('HH:mm').format(DateTime.now()),
      'action': action,
      'itemId': itemId,
      'itemName': itemName,
      'details': details,
      'synced': false,
    };
    final key = logBox.add(logEntry);
    ApiService.saveInventoryChange(logEntry).then((ok) async {
      if (ok) {
        logEntry['synced'] = true;
        await logBox.put(key, logEntry);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          // Manual sync button: pushes unsynced transactions to server
          // and refreshes local inventory from backend.
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync with Server',
            onPressed: _isSyncing ? null : _syncWithServer,
          ),
          IconButton(
            icon: const Icon(Icons.history), // The clock/history icon
            onPressed: _showTransactionHistory, // Call the history function
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logOut, 
            tooltip: 'Log Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            // LEFT SIDE: Product List & Search
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: null, // If you want to control this, use a separate TextEditingController
                      decoration: const InputDecoration(
                        labelText: 'Search Product',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  // Category Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 8.0,
                    ),
                    child: SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (_, i) {
                          final category = _categories[i];
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
                  // Product List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (() {
                            // Manually filter our new 'products' list from the API
                            final filteredItems = products.where((product) {
                              final name = product.name.toLowerCase();
                              final query = _searchQuery.toLowerCase();
                              final matchesSearch = name.contains(query);
                              final matchesCategory = _selectedCategory == 'ALL' || product.category == _selectedCategory;
                              return matchesSearch && matchesCategory;
                            }).toList();

                            if (filteredItems.isEmpty) {
                              return Center(
                                child: Text(_searchQuery.isEmpty
                                    ? 'No items in "$_selectedCategory" category.'
                                    : 'No items found for "$_searchQuery".'),
                              );
                            }

                            return ListView.builder(
                              itemCount: filteredItems.length,
                              itemBuilder: (_, i) {
                                final product = filteredItems[i];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    leading: _productLeading(product),
                                    title: Text(product.name),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Harga Rp ${product.price}'),
                                        Text('Stok ${product.stock}'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _editItem(product), // Note: We changed 'item' to 'product'
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteItem(product.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }()),
                  ),
                ],
              ),
            ),
            // Vertical Divider
            const VerticalDivider(width: 1, thickness: 1),

            // RIGHT SIDE: Add/Edit Product Form
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _itemToEdit == null ? 'Add Product' : 'Edit Product',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Image Input
                      GestureDetector(
                        onTap: _selectImage,
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                              style: BorderStyle.solid,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _formImagePath.isNotEmpty
                            ? (() {
                                // Server-uploaded image (from upload API)
                                if (_formImagePath.startsWith('uploads/') || _formImagePath.startsWith('http')) {
                                  final url = _formImagePath.startsWith('http')
                                      ? _formImagePath
                                      : '${ApiConfig.uploadsBaseUrl}/$_formImagePath';
                                  return Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.red)),
                                  );
                                }
                                // Full path on device: try file first, on error try asset/documents by basename
                                if (_formImagePath.startsWith('/data/user') ||
                                    _formImagePath.startsWith('/var/mobile') ||
                                    (_formImagePath.length > 2 && _formImagePath[1] == ':')) {
                                  return Image.file(
                                    File(_formImagePath),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) {
                                      final base = p.basename(_formImagePath);
                                      return Center(
                                        child: Image.asset(
                                          'assets/images/$base',
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: _ProductImageFromDocuments(
                                              documentsPath: _documentsPath,
                                              fileName: base,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }
                                if (kIsWeb || _formImagePath.startsWith('blob:')) {
                                  return Image.network(
                                    _formImagePath,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.red)),
                                  );
                                }
                                // Filename only: try asset first (bundled), then app documents (user-added)
                                return Image.asset(
                                  'assets/images/$_formImagePath',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: _ProductImageFromDocuments(
                                      documentsPath: _documentsPath,
                                      fileName: _formImagePath,
                                    ),
                                  ),
                                );
                              })()
                            : const Center(
                                // Placeholder for when no image is selected
                                child: Icon(
                                  Icons.add_photo_alternate,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Category selection (DropDown or FilterChips)
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _categories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Name Input
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Price Input
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stock Input
                      TextField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Add/Update Button
                      ElevatedButton(
                        onPressed: _saveItem,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _itemToEdit == null
                              ? 'Add Product'
                              : 'Update Product',
                        ),
                      ),
                      if (_itemToEdit != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: TextButton(
                            onPressed: _clearForm,
                            child: const Text('Cancel Edit'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads product image from app documents directory (user-added images).
class _ProductImageFromDocuments extends StatelessWidget {
  final Future<String> documentsPath;
  final String fileName;

  const _ProductImageFromDocuments({required this.documentsPath, required this.fileName});

  @override
  Widget build(BuildContext context) {
    // If API returned an absolute path (legacy or /storage/), use it directly
    if (fileName.startsWith('/') || (fileName.length > 1 && fileName[1] == ':')) {
      return Image.file(
        File(fileName),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 50, color: Colors.blueGrey),
      );
    }
    return FutureBuilder<String>(
      future: documentsPath,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Icon(Icons.inventory, size: 50, color: Colors.blueGrey);
        }
        final filePath = p.join(snap.data!, fileName);
        return Image.file(
          File(filePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.inventory, size: 50, color: Colors.blueGrey),
        );
      },
    );
  }
}