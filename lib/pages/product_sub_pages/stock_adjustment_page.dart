import 'dart:async'; // 1. Added for Timer/Debouncing
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockAdjustmentPage extends StatefulWidget {
  const StockAdjustmentPage({super.key});

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
  final supabase = Supabase.instance.client;

  // Search/Filters
  final _searchController = TextEditingController();
  String? _selectedStoreId;
  String? _selectedCategoryId;
  Timer? _debounce; // 2. Added for live search control

  // Selection Data
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _foundProducts = [];
  Map<String, dynamic>? _selectedProduct;

  // Adjustment Logic
  final _qtyController = TextEditingController();
  String _adjustmentType = 'ADD';
  String _reason = 'Receiving';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  @override
  void dispose() {
    _debounce?.cancel(); // 3. Cancel timer on close
    _searchController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final s = await supabase.from('stores').select('id, name').order('name');
    final c = await supabase.from('categories').select('id, name').order('name');
    setState(() {
      _stores = List<Map<String, dynamic>>.from(s);
      _categories = List<Map<String, dynamic>>.from(c);
    });
  }

  Future<void> _searchProducts() async {
    // 4. Improved logic: don't search if empty, just clear list
    if (_searchController.text.trim().isEmpty) {
      setState(() => _foundProducts = []);
      return;
    }

    setState(() => _isLoading = true);

    var query = supabase.from('products').select('*, stores(name), categories(name)');

    if (_selectedStoreId != null) query = query.eq('store_id', _selectedStoreId!);
    if (_selectedCategoryId != null) query = query.eq('category_id', _selectedCategoryId!);

    query = query.or('name.ilike.%${_searchController.text}%,sku.ilike.%${_searchController.text}%');

    final res = await query.limit(20);
    setState(() {
      _foundProducts = List<Map<String, dynamic>>.from(res);
      _isLoading = false;
    });
  }

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

  Future<void> _submitAdjustment() async {
    if (_selectedProduct == null || _qtyController.text.isEmpty) return;

    final double inputQtyDouble = double.tryParse(_qtyController.text) ?? 0;
    final int changeQty = inputQtyDouble.round();

    if (changeQty <= 0) {
      _showError("Please enter a valid quantity greater than 0.");
      return;
    }

    final int currentQty = (_selectedProduct!['stock_quantity'] as num).toInt();

    if (_adjustmentType == 'REDUCE' && changeQty > currentQty) {
      _showError(
          "Insufficient Stock!\n\n"
              "Current available: $currentQty pcs\n"
              "Attempted to deduct: $changeQty pcs\n\n"
              "You cannot deduct more than what is currently in stock."
      );
      return;
    }

    final int newQty = _adjustmentType == 'ADD' ? currentQty + changeQty : currentQty - changeQty;

    setState(() => _isLoading = true);

    try {
      await supabase.from('products').update({
        'stock_quantity': newQty
      }).eq('id', _selectedProduct!['id']);

      await supabase.from('product_logs').insert({
        'product_id': _selectedProduct!['id'],
        'store_id': _selectedProduct!['store_id'],
        'user_id': supabase.auth.currentUser?.id,
        'change_type': 'Stock Adjustment',
        'old_value': "$currentQty pcs",
        'new_value': "$newQty pcs",
        'notes': '$_reason (${_adjustmentType == 'ADD' ? '+' : '-'}$changeQty pcs)',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stock Adjusted Successfully"), backgroundColor: Colors.green)
      );

      setState(() {
        _selectedProduct = null;
        _qtyController.clear();
        _foundProducts.clear();
        _searchController.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Database Update failed: $e");
    }
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
                  child: _isLoading && _foundProducts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                    itemCount: _foundProducts.length,
                    itemBuilder: (context, i) {
                      final p = _foundProducts[i];
                      bool isSelected = _selectedProduct?['id'] == p['id'];
                      return Card(
                        color: isSelected ? primaryIndigo.withOpacity(0.2) : surfaceSlate,
                        child: ListTile(
                          title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text("SKU: ${p['sku']} | Current: ${p['stock_quantity']} pcs", style: const TextStyle(color: Colors.white54)),
                          trailing: Text(p['stores']?['name'] ?? '', style: const TextStyle(color: primaryIndigo, fontSize: 10)),
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
                ? const Center(child: Text("Select an item from the list", style: TextStyle(color: Colors.white24)))
                : Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: surfaceSlate, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedProduct!['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("At: ${_selectedProduct!['stores']?['name']}", style: const TextStyle(color: primaryIndigo)),
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
                          : const Text("APPLY ADJUSTMENT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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
        TextField(
          controller: _searchController,
          // 5. Added onCHanged with Debouncer
          onChanged: (value) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              _searchProducts();
            });
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Scan Barcode or Type Name...",
            prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
            filled: true, fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // 6. Updated Filter triggering
            Expanded(child: _filterDrop("Store", _stores, _selectedStoreId, (v) {
              setState(() => _selectedStoreId = v);
              _searchProducts(); // Instant search on filter change
            })),
            const SizedBox(width: 10),
            Expanded(child: _filterDrop("Category", _categories, _selectedCategoryId, (v) {
              setState(() => _selectedCategoryId = v);
              _searchProducts(); // Instant search on filter change
            })),
          ],
        )
      ],
    );
  }

  Widget _filterDrop(String label, List items, String? val, Function(String?) onCh) {
    return DropdownButtonFormField<String>(
      value: val,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        filled: true, fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text("All $label")),
        ...items.map((i) => DropdownMenuItem(value: i['id'].toString(), child: Text(i['name'])))
      ],
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
              color: active ? color.withOpacity(0.2) : Colors.transparent,
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