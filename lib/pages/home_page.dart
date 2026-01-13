// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/user_role.dart';
import 'employee_management_page.dart';
import 'login_page.dart';
import 'checks_dashboard_page.dart';
import 'store_management_page.dart';
import 'products_page.dart';
import 'manage_payments_page.dart'; // Import added

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<Map<String, String>> _userProfileFuture;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = getUserProfileData();
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during sign out: $e')),
        );
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  // FIXED: Added ManagePaymentsPage to match the 6 buttons in the Rail
  final List<Widget> _pages = [
    const EmployeeManagementPage(),    // Index 0
    const ProductsPage(),              // Index 1
    const ChecksDashboardPage(),       // Index 2
    const StoreManagementPage(),       // Index 3
    const ManagePaymentsPage(),        // Index 4
    const Center(child: Text('Reports Page - Coming Soon!', style: TextStyle(fontSize: 24))), // Index 5
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FutureBuilder<Map<String, String>>(
                future: _userProfileFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Welcome, Loading...');
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text('Welcome, User');
                  }
                  final profile = snapshot.data!;
                  final name = profile['name'] ?? 'User';
                  final role = profile['role'] ?? 'N/A';
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Welcome, $name'),
                      Text('Role: $role', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  );
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Employees')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Products')),
              NavigationRailDestination(icon: Icon(Icons.request_quote_outlined), selectedIcon: Icon(Icons.request_quote), label: Text('Checks')),
              NavigationRailDestination(icon: Icon(Icons.store_mall_directory_outlined), selectedIcon: Icon(Icons.store_mall_directory), label: Text('Stores')),
              NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: Text('Payments')),
              NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Reports')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
