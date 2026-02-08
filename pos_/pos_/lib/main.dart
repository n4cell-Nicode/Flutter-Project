import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'pages/LoginPage.dart';
import 'pages/CashierPage.dart';
import 'pages/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('users');
  await Hive.openBox('inventory');
  await Hive.openBox('transactions');
  await Hive.openBox('inventory_changes');

  // Load inventory from API on startup so Cashier sees latest MySQL data after restart
  var inv = Hive.box('inventory');
  try {
    final products = await ApiService.getInventory();
    if (products.isNotEmpty) {
      final savedPaths = <String, String?>{};
      for (final key in inv.keys) {
        final m = inv.get(key) as Map?;
        if (m != null) {
          final path = m['imagePath'] ?? m['image_path'];
          if (path != null && path.toString().isNotEmpty) {
            savedPaths[m['id']?.toString() ?? key.toString()] = path.toString();
          }
        }
      }
      await inv.clear();
      for (final p in products) {
        final imgPath = p.imagePath ?? savedPaths[p.id];
        inv.put(p.id, {
          'id': p.id, 'name': p.name, 'price': p.price, 'stock': p.stock,
          'category': p.category, 'imagePath': imgPath,
        });
      }
    }
  } catch (_) {}

  // Seed example data if empty
  var users = Hive.box('users');
  if (users.isEmpty) {
    users.put('admin', {
      'username': 'admin',
      'password': 'admin',
      'role': 'admin',
    });
    users.put('cashier', {
      'username': 'cashier',
      'password': 'cashier',
      'role': 'cashier',
    });
  }

  if (inv.isEmpty) {
    // UPDATED: Seed data with 'category' and 'imagePath' fields
    inv.put('1000000', {
      'id': '1000000',
      'name': 'Aice Mochi',
      'price': 5000,
      'stock': 20,
      'category': 'FOOD',
      'imagePath': 'mochi.png',
    });
    inv.put('1000001', {
      'id': '1000001',
      'name': 'FT Blackcurrrant',
      'price': 3000,
      'stock': 30,
      'category': 'DRINKS',
      'imagePath': 'tea.png',
    });
    inv.put('1000002', {
      'id': '1000002',
      'name': 'Kanzleer Original',
      'price': 7000,
      'stock': 15,
      'category': 'FOOD',
      'imagePath': 'soscis.png',
    });
    inv.put('1000003', {
      'id': '1000003',
      'name': 'Teh Botol',
      'price': 4500,
      'stock': 40,
      'category': 'DRINKS',
      'imagePath': 'teasoro.png',
    });
    inv.put('1000004', {
      'id': '1000004',
      'name': 'Minyak telon MB',
      'price': 15000,
      'stock': 10,
      'category': 'THINGS',
      'imagePath': 'babyoil.png',
    });
    inv.put('1000005', {
      'id': '1000005',
      'name': 'Cussons baby powder',
      'price': 15000,
      'stock': 10,
      'category': 'THINGS',
      'imagePath': 'baby.png',
    });
    inv.put('1000006', {
      'id': '1000006',
      'name': 'Maerina Body Lotion',
      'price': 15000,
      'stock': 10,
      'category': 'THINGS',
      'imagePath': 'bodyl.png',
    });
    inv.put('1000007', {
      'id': '1000007',
      'name': 'Cimory Cashew',
      'price': 15000,
      'stock': 10,
      'category': 'DRINKS',
      'imagePath': 'cimory.png',
    });
    inv.put('1000008', {
      'id': '1000008',
      'name': 'Cadbury Chocholate',
      'price': 15000,
      'stock': 10,
      'category': 'FOOD',
      'imagePath': 'dairymilk.png',
    });
    inv.put('1000009', {
      'id': '1000009',
      'name': 'Cornetto Ice Cream',
      'price': 15000,
      'stock': 10,
      'category': 'DRINKS',
      'imagePath': 'ice.png',
    });
    inv.put('1000010', {
      'id': '1000010',
      'name': 'Kinderjoy ',
      'price': 15000,
      'stock': 10,
      'category': 'FOOD',
      'imagePath': 'kinderjoy.png',
    });
    inv.put('1000011', {
      'id': '1000011',
      'name': 'Pucuk harum',
      'price': 15000,
      'stock': 10,
      'category': 'DRINKS',
      'imagePath': 'pucuk.png',
    });
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        dialogBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        dividerTheme: const DividerThemeData(color: Colors.black, thickness: 1),

        cardTheme: const CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.black, width: 1),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.white),
            foregroundColor: MaterialStatePropertyAll(Colors.black),
            side: MaterialStatePropertyAll(BorderSide(color: Colors.black)),
            shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
