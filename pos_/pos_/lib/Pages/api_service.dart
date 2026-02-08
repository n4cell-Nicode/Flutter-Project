import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'user_model.dart';
import 'product_model.dart';

class ApiService {
  // This function sends the username and password to your server
  static Future<User?> login(String username, String password) async {
    try {
      final response = await http.post(
        // PHP backend: explicit .php path
        Uri.parse('${ApiConfig.baseUrl}/auth/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        // If the server says OK, turn the response into our User model
        return User.fromJson(jsonDecode(response.body));
      } else {
        // If the server says "Unauthorized" or "Error"
        return null;
      }
    } catch (e) {
      // If the internet is down or server is off
      print("Login Error: $e");
      return null;
    }
  }

  static Future<List<Product>> getInventory() async {
    try {
      final response = await http.get(
        // PHP backend: inventory.php endpoint
        Uri.parse('${ApiConfig.baseUrl}/inventory.php'),
      );

      if (response.statusCode == 200) {
        List jsonResponse = jsonDecode(response.body);
        return jsonResponse.map((item) => Product.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load inventory');
      }
    } catch (e) {
      print("Inventory Error: $e");
      return []; // Return empty list if something goes wrong
    }
  }

  static Future<bool> saveTransaction(Map<String, dynamic> transactionData) async {
    try {
      final response = await http.post(
        // PHP backend: transactions.php endpoint
        Uri.parse('${ApiConfig.baseUrl}/transactions.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(transactionData),
      );

      // If the server returns 201 (Created) or 200 (OK)
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Transaction Error: $e");
      return false;
    }
  }

  /// Returns all transactions from server (for receipt history after restart).
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/transactions.php'),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      print("Get Transactions Error: $e");
      return [];
    }
  }

  /// Save an inventory change log entry (Admin Change History).
  static Future<bool> saveInventoryChange(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/inventory_changes.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Save Inventory Change Error: $e");
      return false;
    }
  }

  /// Load all inventory change logs (Admin Change History).
  static Future<List<Map<String, dynamic>>> getInventoryChanges() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/inventory_changes.php'),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      print("Get Inventory Changes Error: $e");
      return [];
    }
  }

  static Future<bool> updateStock(String id, int newStock) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/inventory/stock.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'stock': newStock}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Update Error: $e");
      return false;
    }
  }

  /// Full product update (name, price, stock, category, image).
  static Future<bool> updateProduct(String id, String name, int price, int stock, String category, [String? imagePath]) async {
    try {
      final body = {
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
        'category': category,
        if (imagePath != null && imagePath.isNotEmpty) 'imagePath': imagePath,
      };
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/inventory/update.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Update Product Error: $e");
      return false;
    }
  }

  /// Upload product image to server. Returns path (e.g. "uploads/products/xxx.jpg") on success, null on failure.
  static Future<String?> uploadProductImage(String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/upload.php'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', filePath));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['path']?.toString();
      }
      return null;
    } catch (e) {
      print("Upload Image Error: $e");
      return null;
    }
  }

  /// Add new product to server.
  static Future<bool> addProduct(Map<String, dynamic> product) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/inventory.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(product),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Add Product Error: $e");
      return false;
    }
  }

  /// Delete product from server (inventory table). Uses same endpoint as add (inventory.php).
  /// Returns null on success, or an error message string on failure.
  static Future<String?> deleteProduct(String id) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/inventory.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'delete', 'id': id}),
      );
      if (response.statusCode == 200) return null;
      try {
        final decoded = jsonDecode(response.body);
        return decoded['error']?.toString() ?? 'Server returned ${response.statusCode}';
      } catch (_) {
        return response.body.isNotEmpty ? response.body : 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      print("Delete Product Error: $e");
      return e.toString();
    }
  }
}