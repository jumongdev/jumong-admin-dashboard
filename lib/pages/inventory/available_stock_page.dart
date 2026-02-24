// lib/pages/inventory/available_stock_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvailableStockPage extends StatefulWidget {
  const AvailableStockPage({super.key});

  @override
  State<AvailableStockPage> createState() => _AvailableStockPageState();
}

class _AvailableStockPageState extends State<AvailableStockPage> {
  final _supabase = Supabase.instance.client;

  // Filter States
  String _searchQuery = '';
  String? _selectedStoreId;
  String? _selectedCategoryId;
  String? _selectedPayeeId;

  // Pagination States
  int _pageSize = 50; // View list of 50 or 100
  int _currentPage = 0; // Current index for previous/next logic

  // Data Lists
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _payees = [];

  // Cache for fast product lookups (Map<ProductId, ProductData>)
  Map<String, Map<String, dynamic>> _productsCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final storesRes = await _supabase.from('stores').select('id, name').order('name');
      final catsRes = await _supabase.from('categories').select('id, name').order('name');
      final payeesRes = await _supabase.from('payees').select('id, name').order('name');

      if (mounted) {
        setState(() {
          _stores = List<Map<String, dynamic>>.from(storesRes);
          _categories = List<Map<String, dynamic>>.from(catsRes);
          _payees = List<Map<String, dynamic>>.from(payeesRes);

          if (_stores.isNotEmpty && _selectedStoreId == null) {
            _selectedStoreId = _stores[0]['id'].toString();
          }
        });
      }

      final productsRes = await _supabase
          .from('products')
          .select('id, name, sku, category_id, payee_id')
          .eq('is_active', true);

      final Map<String, Map<String, dynamic>> tempMap = {};
      for (var p in productsRes) {
        tempMap[p['id'].toString()] = p;
      }

      if (mounted) {
        setState(() {
          _productsCache = tempMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Stream<List<Map<String, dynamic>>> _getStockStream() {
    final streamBuilder = _supabase.from('inventory').stream(primaryKey: ['id']);

    if (_selectedStoreId != null) {
      return streamBuilder.eq('store_id', _selectedStoreId!).order('stock_quantity', ascending: true);
    }
    return streamBuilder.order('stock_quantity', ascending: true);
  }

  @override
  Widget build(BuildContext context) {
    const backgroundDeep = Color(0xFF0F172A);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    return Scaffold(
      backgroundColor: backgroundDeep,
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
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }

                final inventoryItems = snapshot.data ?? [];

                // MERGE & FILTER LOGIC
                final List<Map<String, dynamic>> filteredList = [];
                for (var item in inventoryItems) {
                  final String pId = item['product_id'].toString();
                  final productDetails = _productsCache[pId];

                  if (productDetails != null) {
                    final name = productDetails['name'].toString().toLowerCase();
                    final sku = productDetails['sku'].toString();

                    bool matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase()) || sku.contains(_searchQuery);
                    bool matchesCategory = _selectedCategoryId == null || productDetails['category_id'].toString() == _selectedCategoryId;
                    bool matchesPayee = _selectedPayeeId == null || productDetails['payee_id'].toString() == _selectedPayeeId;

                    if (matchesSearch && matchesCategory && matchesPayee) {
                      filteredList.add({
                        ...item,
                        'product_name': productDetails['name'],
                        'product_sku': productDetails['sku'],
                      });
                    }
                  }
                }

                if (filteredList.isEmpty) {
                  return const Center(child: Text("No active items found.", style: TextStyle(color: Colors.white24)));
                }

                // Apply local pagination
                final int totalItems = filteredList.length;
                final int totalPages = (totalItems / _pageSize).ceil();
                if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;

                final displayList = filteredList.skip(_currentPage * _pageSize).take(_pageSize).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                                "Showing ${displayList.length} of $totalItems items",
                                style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: displayList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildStockCard(displayList[index]);
                        },
                      ),
                    ),
                    _buildPaginationFooter(totalItems, totalPages),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(int totalItems, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text("Items per page: ", style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                height: 35,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(5)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 50, child: Text("50")), // View 50
                      DropdownMenuItem(value: 100, child: Text("100")) // View 100
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 0;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null, // Previous button
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text("Page ${_currentPage + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null, // Next button
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  value: _selectedStoreId,
                  hint: "Select Store",
                  items: _stores,
                  icon: Icons.store,
                  onChanged: (val) => setState(() {
                    _selectedStoreId = val;
                    _currentPage = 0;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _currentPage = 0;
                  }),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search stock...",
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadInitialData();
                },
                icon: const Icon(Icons.refresh, color: Colors.white54),
                tooltip: "Reload Data",
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _selectedCategoryId,
                  hint: "All Categories",
                  items: _categories,
                  icon: Icons.category,
                  isClearable: true,
                  onChanged: (val) => setState(() {
                    _selectedCategoryId = val;
                    _currentPage = 0;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  value: _selectedPayeeId,
                  hint: "All Suppliers",
                  items: _payees,
                  icon: Icons.business,
                  isClearable: true,
                  onChanged: (val) => setState(() {
                    _selectedPayeeId = val;
                    _currentPage = 0;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<Map<String, dynamic>> items,
    required IconData icon,
    required Function(String?) onChanged,
    bool isClearable = false,
  }) {
    final displayItems = [
      if (isClearable) const DropdownMenuItem<String>(value: null, child: Text("All")),
      ...items.map((item) => DropdownMenuItem<String>(
        value: item['id'].toString(),
        child: Text(item['name'] ?? '', overflow: TextOverflow.ellipsis),
      )),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1E293B),
          hint: Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          isExpanded: true,
          icon: Icon(icon, color: const Color(0xFF6366F1), size: 18),
          items: displayItems,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> item) {
    final int stock = item['stock_quantity'] ?? 0;
    Color statusColor = stock <= 0 ? Colors.redAccent : (stock <= 20 ? Colors.orangeAccent : Colors.greenAccent);
    String statusLabel = stock <= 0 ? "OUT OF STOCK" : (stock <= 20 ? "LOW STOCK" : "HEALTHY");

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
                  item['product_name'] ?? 'Unknown Product',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  "SKU: ${item['product_sku'] ?? 'N/A'}",
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text("$stock", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor)),
                Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}