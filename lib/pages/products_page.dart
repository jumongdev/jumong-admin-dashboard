import 'package:flutter/material.dart';
import 'product_sub_pages/product_list_page.dart';
import 'product_sub_pages/approve_request_page.dart';
import 'product_sub_pages/available_stock_page.dart';
import 'product_sub_pages/item_history_page.dart';
import 'product_sub_pages/stock_adjustment_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // The widgets for each tab.
  // Note: We remove 'const' from pages that maintain their own state or fetch data.
  final List<Widget> _tabsContent = [
    const ProductListPage(),
    const AvailableStockPage(),
    const StockAdjustmentPage(),
    const ItemHistoryPage(),     // This is the page we just updated
    const ApproveRequestPage(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabsContent.length, vsync: this);

    // Optional: Refresh data when switching to the History tab
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Triggers a rebuild of the current tab
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
          tabs: const [
            Tab(icon: Icon(Icons.inventory_sharp), text: 'Catalog'),
            Tab(icon: Icon(Icons.dashboard_customize_outlined), text: 'Available Stock'),
            Tab(icon: Icon(Icons.settings_input_component_outlined), text: 'Adjustment'),
            Tab(icon: Icon(Icons.manage_search_outlined), text: 'Audit Trail'), // Renamed to Audit Trail
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Approvals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // This ensures the pages stay in memory so they don't reload every time you tap
        physics: const NeverScrollableScrollPhysics(),
        children: _tabsContent,
      ),
    );
  }
}
