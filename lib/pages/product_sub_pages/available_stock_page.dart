// lib/pages/product_sub_pages/available_stock_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvailableStockPage extends StatefulWidget {
  const AvailableStockPage({super.key});

  @override
  State<AvailableStockPage> createState() => _AvailableStockPageState();
}

class _AvailableStockPageState extends State<AvailableStockPage> {
  final _supabase = Supabase.instance.client;

  String _searchQuery = '';
  String? _selectedStoreId;
  List<Map<String, dynamic>> _stores = [];
  bool _isLoadingStores = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      final data = await _supabase.from('stores').select('id, name').order('name');
      setState(() {
        _stores = List<Map<String, dynamic>>.from(data);
        _isLoadingStores = false;
        if (_stores.isNotEmpty) {
          _selectedStoreId = _stores[0]['id'];
        }
      });
    } catch (e) {
      debugPrint("Error loading stores: $e");
    }
  }

  // FIXED: Correctly handling the Supabase Stream Builder types
  Stream<List<Map<String, dynamic>>> _getStockStream() {
    // 1. Start the stream by defining the primary key
    final streamBuilder = _supabase.from('products').stream(primaryKey: ['id']);

    // 2. Apply the filter if a store is selected
    if (_selectedStoreId != null) {
      return streamBuilder
          .eq('store_id', _selectedStoreId!)
          .order('stock_quantity', ascending: true);
    }

    // 3. Fallback if no store selected (though admin usually has one selected)
    return streamBuilder.order('stock_quantity', ascending: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStores) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: _selectedStoreId == null
                ? const Center(child: Text("Select a branch to view inventory", style: TextStyle(color: Colors.white24)))
                : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getStockStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Stream Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }

                final products = snapshot.data ?? [];

                // Client-side search filtering
                final filtered = products.where((p) {
                  final nameMatch = p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                  final skuMatch = p['sku'].toString().contains(_searchQuery);
                  return nameMatch || skuMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No products found in this branch.", style: TextStyle(color: Colors.white24)));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildStockCard(filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Store Selector Dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStoreId,
                  dropdownColor: const Color(0xFF1E293B),
                  hint: const Text("Filter by Store", style: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  isExpanded: true,
                  icon: const Icon(Icons.store, color: Color(0xFF6366F1)),
                  items: _stores.map((store) {
                    return DropdownMenuItem<String>(
                      value: store['id'].toString(),
                      child: Text(store['name'] ?? 'Unnamed Branch'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedStoreId = val),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Search Bar
          Expanded(
            flex: 3,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search stock by name or SKU...",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> product) {
    final int stock = (product['stock_quantity'] as num? ?? 0).toInt();

    Color statusColor = stock <= 0
        ? Colors.redAccent
        : (stock <= 20 ? Colors.orangeAccent : Colors.greenAccent);

    String statusLabel = stock <= 0
        ? "OUT OF STOCK"
        : (stock <= 20 ? "LOW STOCK" : "HEALTHY");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Unnamed',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  "SKU: ${product['sku'] ?? 'N/A'}",
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  "$stock",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
