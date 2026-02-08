import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'HomePage.dart';
import 'api_service.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userC = TextEditingController();
  final _passC = TextEditingController();
  String _error = '';
  bool _isLoading = false;

  void _login() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final username = _userC.text.trim();
    final password = _passC.text.trim();

    final user = await ApiService.login(username, password);

    if (user != null) {
      // SUCCESS: Navigate to HomePage using the role from the SQL database
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(role: user.role)),
      );
    } else {
      // FAILURE: Either wrong password or server is down
      setState(() {
        _error = 'Login gagal. Periksa koneksi atau akun Anda.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ============================================================
      //                        BACKGROUND BARU
      // ============================================================
      body: Stack(
        children: [
          Positioned.fill(
            child: Transform.rotate(
              angle: -0.35, // miring diagonal vertikal
              child: Opacity(
                opacity: 0.10,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, // jumlah kolom icon
                    childAspectRatio: 1,
                  ),
                  itemCount: 300, // jumlah total item
                  itemBuilder:
                      (_, __) => const Icon(
                        Icons.shopping_cart,
                        size: 48,
                        color: Colors.black,
                      ),
                ),
              ),
            ),
          ),

          // ============================================================
          //                        CARD LOGIN
          // ============================================================
          Center(
            child: Container(
              width: 430,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "LOGIN",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Username
                  TextField(
                    controller: _userC,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _passC,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // tombol login
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white, // <=== tambahkan ini
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _login,
                      child: const Text(
                        "Login",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
