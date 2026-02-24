// lib/pages/inventory/stock_adjustment_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockAdjustmentPage extends StatefulWidget {
  const StockAdjustmentPage({super.key});

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
  final supabase = Supabase.instance.client;

  final _searchController = TextEditingController();
  final _qtyController = TextEditingController();

  String? _selectedStoreId;
  String? _selectedCategoryId;
  Timer? _debounce;

  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _foundProducts = [];
  Map<String, dynamic>? _selectedProduct;

  String _adjustmentType = 'ADD';
  String _reason = 'Receiving';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        supabase.from('stores').select('id, name').order('name'),
        supabase.from('categories').select('id, name').order('name'),
      ]);

      setState(() {
        _stores = List<Map<String, dynamic>>.from(results[0]);
        _categories = List<Map<String, dynamic>>.from(results[1]);

        if (_stores.isNotEmpty && _selectedStoreId == null) {
          _selectedStoreId = _stores[0]['id'].toString();
        }
      });
    } catch (e) {
      debugPrint("Init Load Error: $e");
    }
  }

  Future<void> _searchProducts() async {
    final queryText = _searchController.text.trim();
    if (queryText.isEmpty || _selectedStoreId == null) {
      setState(() => _foundProducts = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Fetch Active Products matching name/SKU
      var productQuery = supabase.from('products')
          .select('id, name, sku, category_id, categories(name)')
          .eq('is_active', true); // FIX: Don't adjust archived items

      if (_selectedCategoryId != null) {
        productQuery = productQuery.eq('category_id', _selectedCategoryId!);
      }

      productQuery = productQuery.or('name.ilike.%$queryText%,sku.ilike.%$queryText%');

      final productsRes = await productQuery.limit(20);
      final List<String> pIds = productsRes.map((p) => p['id'].toString()).toList();

      // 2. Fetch all relevant inventory in ONE query (Better Performance)
      final inventoryRes = await supabase
          .from('inventory')
          .select('product_id, stock_quantity')
          .eq('store_id', _selectedStoreId!)
          .inFilter('product_id', pIds);

      // Create a map for quick lookup
      final Map<String, int> invMap = {
        for (var item in inventoryRes) item['product_id'].toString(): item['stock_quantity'] as int
      };

      // 3. Combine Data
      final List<Map<String, dynamic>> results = productsRes.map((p) {
        return {
          ...p,
          'real_stock': invMap[p['id'].toString()] ?? 0,
          'store_name': _stores.firstWhere((s) => s['id'].toString() == _selectedStoreId.toString())['name']
        };
      }).toList();

      setState(() {
        _foundProducts = results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Search Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAdjustment() async {
    if (_selectedProduct == null || _qtyController.text.isEmpty || _selectedStoreId == null) return;

    final int changeQty = int.tryParse(_qtyController.text) ?? 0;
    if (changeQty <= 0) {
      _showError("Enter a valid quantity.");
      return;
    }

    final int currentQty = _selectedProduct!['real_stock'];
    if (_adjustmentType == 'REDUCE' && changeQty > currentQty) {
      _showError("Insufficient stock at this branch.");
      return;
    }

    final int newQty = _adjustmentType == 'ADD' ? currentQty + changeQty : currentQty - changeQty;
    final String productId = _selectedProduct!['id'].toString();

    setState(() => _isLoading = true);

    try {
      // 1. Update Inventory using upsert (handles missing rows automatically)
      await supabase.from('inventory').upsert({
        'store_id': _selectedStoreId,
        'product_id': productId,
        'stock_quantity': newQty
      });

      // 2. Log change
      await supabase.from('product_logs').insert({
        'product_id': productId,
        'store_id': _selectedStoreId,
        'user_id': supabase.auth.currentUser?.id,
        'change_type': 'Stock Adjustment',
        'old_value': "$currentQty pcs",
        'new_value': "$newQty pcs",
        'notes': '$_reason (${_adjustmentType == 'ADD' ? '+' : '-'}$changeQty)',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adjusted!"), backgroundColor: Colors.green));

      // Reset UI but keep search context
      setState(() {
        _selectedProduct = null;
        _qtyController.clear();
        _isLoading = false;
      });
      _searchProducts(); // Refresh list to show new stock
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError("Failed to update: $e");
    }
  }

  // ... (UI Widgets: _showError, _buildSearchHeader, _filterDrop, _typeBtn, _buildReasonDropdown remain largely the same)
  // Ensure your Dropdowns use .toString() for comparisons to prevent Type Mismatch errors.

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Stock Error", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Color(0xFF6366F1))))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const surfaceSlate = Color(0xFF1E293B);
    const primaryIndigo = Color(0xFF6366F1);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildSearchHeader(),
                const SizedBox(height: 15),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: primaryIndigo))
                      : ListView.builder(
                    itemCount: _foundProducts.length,
                    itemBuilder: (context, i) {
                      final p = _foundProducts[i];
                      bool isSelected = _selectedProduct?['id'] == p['id'];
                      return Card(
                        color: isSelected ? primaryIndigo.withValues(alpha: 0.2) : surfaceSlate,
                        child: ListTile(
                          title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text("SKU: ${p['sku']} | Current: ${p['real_stock']} pcs", style: const TextStyle(color: Colors.white54)),
                          trailing: Text(p['store_name'] ?? '', style: const TextStyle(color: primaryIndigo, fontSize: 10)),
                          onTap: () => setState(() => _selectedProduct = p),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(color: Colors.white10, width: 40),
          Expanded(
            flex: 3,
            child: _selectedProduct == null
                ? const Center(child: Text("Select an item to adjust", style: TextStyle(color: Colors.white24)))
                : Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: surfaceSlate, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedProduct!['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Current Stock: ${_selectedProduct!['real_stock']}", style: const TextStyle(color: primaryIndigo, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(height: 40, color: Colors.white10),
                  const Text("1. DIRECTION", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _typeBtn("ADD", Colors.green),
                      const SizedBox(width: 10),
                      _typeBtn("REDUCE", Colors.redAccent),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text("2. PURPOSE", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
                  _buildReasonDropdown(),
                  const SizedBox(height: 25),
                  const Text("3. QUANTITY", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
                  TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                    decoration: const InputDecoration(
                      hintText: "0",
                      hintStyle: TextStyle(color: Colors.white10),
                      suffixText: "pcs",
                      suffixStyle: TextStyle(color: Colors.white24, fontSize: 14),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitAdjustment,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryIndigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("APPLY ADJUSTMENT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _filterDrop("Store", _stores, _selectedStoreId, (v) {
              setState(() {
                _selectedStoreId = v;
                _foundProducts = [];
                _selectedProduct = null;
              });
              _searchProducts();
            })),
            const SizedBox(width: 10),
            Expanded(child: _filterDrop("Category", _categories, _selectedCategoryId, (v) {
              setState(() => _selectedCategoryId = v);
              _searchProducts();
            })),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          onChanged: (value) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () => _searchProducts());
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Scan Barcode or Type Name...",
            prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
            filled: true, fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _filterDrop(String label, List items, String? val, Function(String?) onCh) {
    return DropdownButtonFormField<String>(
      initialValue: val,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        filled: true, fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      hint: Text("Select $label", style: const TextStyle(color: Colors.white54)),
      items: items.map((i) => DropdownMenuItem<String>(value: i['id'].toString(), child: Text(i['name']))).toList(),
      onChanged: onCh,
    );
  }

  Widget _typeBtn(String type, Color color) {
    bool active = _adjustmentType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _adjustmentType = type;
          _reason = type == 'ADD' ? 'Receiving' : 'Manual Reduce';
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
              border: Border.all(color: active ? color : Colors.white10),
              borderRadius: BorderRadius.circular(8)
          ),
          child: Center(
            child: Text(type, style: TextStyle(color: active ? color : Colors.white38, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonDropdown() {
    List<String> options = _adjustmentType == 'ADD'
        ? ['Receiving', 'Return from Customer', 'Restock', 'Found Item']
        : ['Manual Reduce', 'Expired', 'Lose', 'Damage', 'Personal Use'];

    return DropdownButton<String>(
      value: _reason,
      isExpanded: true,
      dropdownColor: const Color(0xFF1E293B),
      underline: Container(height: 1, color: Colors.white10),
      style: const TextStyle(color: Colors.white),
      items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _reason = v!),
    );
  }
}