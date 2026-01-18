// lib/pages/products_page.dart

import 'package:flutter/material.dart';
import 'product_sub_pages/product_list_page.dart';
import 'product_sub_pages/approve_request_page.dart';
import 'product_sub_pages/available_stock_page.dart';
import 'product_sub_pages/item_history_page.dart';
import 'product_sub_pages/stock_adjustment_page.dart';
import 'product_sub_pages/category_list_page.dart';
import 'product_sub_pages/unit_list_page.dart';
import 'product_sub_pages/payee_list_page.dart'; // 1. ADD THIS IMPORT

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // 2. UPDATED LIST: Added PayeeListPage to the contents
  final List<Widget> _tabsContent = [
    const ProductListPage(),
    const AvailableStockPage(),
    const StockAdjustmentPage(),
    const ItemHistoryPage(),
    const ApproveRequestPage(),
    const CategoryListPage(),
    const UnitListPage(),
    const PayeeListPage(), // <--- NEW TAB CONTENT
  ];

  @override
  void initState() {
    super.initState();
    // Length is now 8
    _tabController = TabController(length: _tabsContent.length, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF6366F1);
    const backgroundDeep = Color(0xFF0F172A);
    const surfaceSlate = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: backgroundDeep,
      appBar: AppBar(
        backgroundColor: surfaceSlate,
        elevation: 0,
        title: const Text(
          "PRODUCT MANAGEMENT",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: primaryIndigo,
          indicatorWeight: 3,
          labelColor: primaryIndigo,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelColor: Colors.white38,
          // 3. UPDATED TABS: Added the Supplier/Payee tab
          tabs: const [
            Tab(icon: Icon(Icons.inventory_sharp), text: 'Catalog'),
            Tab(icon: Icon(Icons.dashboard_customize_outlined), text: 'Available Stock'),
            Tab(icon: Icon(Icons.settings_input_component_outlined), text: 'Adjustment'),
            Tab(icon: Icon(Icons.manage_search_outlined), text: 'Audit Trail'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Approvals'),
            Tab(icon: Icon(Icons.category), text: 'Category'),
            Tab(icon: Icon(Icons.ad_units_outlined), text: 'Unit'),
            Tab(icon: Icon(Icons.person_pin_outlined), text: 'Suppliers'), // <--- NEW TAB
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: _tabsContent,
      ),
    );
  }
}