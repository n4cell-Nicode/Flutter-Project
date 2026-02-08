import 'package:flutter/material.dart';
import 'CashierPage.dart';
import 'AdminInventoryPage.dart';
import 'ReportsPage.dart'; // Assuming you still need Reports page for admin

class HomePage extends StatefulWidget {
    final String role;
    const HomePage({required this.role, super.key});
    @override
    _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
    // Use 0 for Admin Inventory, 1 for Admin Reports
    int _selectedIndex = 0;
    late final List<Widget> _cashierPages;
    late final List<Widget> _adminPages;

    List<Widget> get _pages =>
        widget.role == 'admin' ? _adminPages : _cashierPages;

    @override
    void initState() {
        super.initState();
        _cashierPages = [const CashierPage()];
        
        // MODIFIED: Removed CashierPage from Admin's pages
        _adminPages = [
            const AdminInventoryPage(), // NEW Index 0: Inventory
            const ReportsPage(), // NEW Index 1: Reports
        ];

        // If the user is an admin, start on the Admin Inventory page (index 0)
        if (widget.role == 'admin') {
            _selectedIndex = 0; // Start on Inventory
        }
    }

    void _onItemTapped(int index) {
        setState(() {
            _selectedIndex = index;
        });
    }

    // Define the items for the new navigation structure
    List<BottomNavigationBarItem> _buildAdminNavItems() {
        return const [
            // REMOVED: Cashier tab
            BottomNavigationBarItem(
                icon: Icon(Icons.inventory),
                label: 'Inventory',
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Reports',
            ),
        ];
    }

    @override
    Widget build(BuildContext context) {
        // Cashier role only gets the CashierPage, no bottom bar needed.
        if (widget.role == 'cashier') {
            return const CashierPage();
        }

        // Admin role needs navigation between pages.
        return Scaffold(
            body: _pages[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
                items: _buildAdminNavItems(),
                currentIndex: _selectedIndex,
                selectedItemColor: Colors.teal,
                onTap: _onItemTapped,
            ),
        );
    }
}