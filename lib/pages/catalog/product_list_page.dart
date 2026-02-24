// lib/pages/product_sub_pages/product_list_page.dart
//dashboard > Product Management > Catalog
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final supabase = Supabase.instance.client;

  // Controllers for Add/Edit
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();

  // Filter States
  final _searchController = TextEditingController();
  String? _filterCategoryId;
  String? _filterPayeeId;
  String _filterStatus = 'Active';

  // Data Cache
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _payees = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final catsRes = await supabase.from('categories').select('id, name').order('name');
      final payeesRes = await supabase.from('payees').select('id, name').order('name');

      final productsRes = await supabase.from('products').select('''
            *,
            categories(name),
            units(name),
            payees(name),
            price_rules(*, units(name))
          ''').order('name');

      if (!mounted) return;

      setState(() {
        _categories = List<Map<String, dynamic>>.from(catsRes);
        _payees = List<Map<String, dynamic>>.from(payeesRes);
        _allProducts = List<Map<String, dynamic>>.from(productsRes);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final query = _searchController.text.toLowerCase();
        final matchesSearch = p['name'].toString().toLowerCase().contains(query) ||
            p['sku'].toString().toLowerCase().contains(query);

        final matchesCategory = _filterCategoryId == null || p['category_id'].toString() == _filterCategoryId;
        final matchesPayee = _filterPayeeId == null || p['payee_id'].toString() == _filterPayeeId;

        final bool isActive = p['is_active'] ?? true;
        bool matchesStatus = true;
        if (_filterStatus == 'Active') {
          matchesStatus = isActive == true;
        } else if (_filterStatus == 'Archived') {
          matchesStatus = isActive == false;
        }

        return matchesSearch && matchesCategory && matchesPayee && matchesStatus;
      }).toList();
    });
  }

  void _refresh() => _loadInitialData();

  @override
  Widget build(BuildContext context) {
    const backgroundDeep = Color(0xFF0F172A);
    const surfaceSlate = Color(0xFF1E293B);
    const primaryIndigo = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: backgroundDeep,
      body: Column(
        children: [
          // === HEADER SECTION ===
          Container(
            padding: const EdgeInsets.all(16),
            color: surfaceSlate,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search name or barcode...",
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: primaryIndigo, size: 18),
                      filled: true,
                      fillColor: backgroundDeep,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildFilterDropdown("Category", _categories, _filterCategoryId, (val) {
                    setState(() => _filterCategoryId = val);
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildFilterDropdown("Supplier", _payees, _filterPayeeId, (val) {
                    setState(() => _filterPayeeId = val);
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: backgroundDeep,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        dropdownColor: surfaceSlate,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list, color: primaryIndigo, size: 18),
                        items: const [
                          DropdownMenuItem(value: 'Active', child: Text("Active Only")),
                          DropdownMenuItem(value: 'Archived', child: Text("Archived Only")),
                          DropdownMenuItem(value: 'All', child: Text("All Statuses")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _filterStatus = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryIndigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryIndigo.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    "Items: ${_filteredProducts.length}",
                    style: const TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                  tooltip: "Refresh List",
                )
              ],
            ),
          ),
          // === LIST SECTION ===
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryIndigo))
                : _filteredProducts.isEmpty
                ? const Center(child: Text("No products found", style: TextStyle(color: Colors.white24)))
                : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, i) {
                final p = _filteredProducts[i];
                final List rules = p['price_rules'] ?? [];
                final bool hasWholesale = rules.isNotEmpty;
                final bool isActive = p['is_active'] ?? true;

                return Card(
                  color: isActive ? surfaceSlate : const Color(0xFF282222),
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    iconColor: primaryIndigo,
                    collapsedIconColor: Colors.white24,
                    leading: Icon(
                        isActive ? (hasWholesale ? Icons.auto_awesome : Icons.inventory_2) : Icons.archive,
                        color: isActive ? (hasWholesale ? Colors.orangeAccent : primaryIndigo) : Colors.grey),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p['name'] ?? 'No Name',
                            style: TextStyle(
                                color: isActive ? Colors.white : Colors.white38,
                                fontWeight: FontWeight.bold,
                                decoration: isActive ? null : TextDecoration.lineThrough),
                          ),
                        ),
                        if (hasWholesale && isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3))),
                            child: const Text("WHOLESALE",
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                            child: const Text("ARCHIVED",
                                style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    subtitle: Text("SKU: ${p['sku']} | Supp: ${p['payees']?['name'] ?? 'None'}",
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: Text("₱${(p['base_price'] as num? ?? 0).toStringAsFixed(2)}",
                        style: TextStyle(
                            color: isActive ? Colors.greenAccent : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    children: [
                      Container(
                        color: Colors.white.withValues(alpha: 0.02),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.edit, size: 16, color: Colors.white38),
                          title: const Text("Edit Details, Status or Rules",
                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                          onTap: () => _editProduct(p),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // === SITEMAP FOOTER SECTION ===
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          color: surfaceSlate,
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_tree_outlined, color: Colors.white24, size: 14),
            const SizedBox(width: 8),
            Text(
              "Dashboard > Product Management > Catalog",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              "Items: ${_filteredProducts.length}",
              style: TextStyle(
                color: primaryIndigo.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryIndigo,
        onPressed: () => _showAddProductDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- HELPER WIDGETS & METHODS ---

  Widget _buildFilterDropdown(String hint, List<Map<String, dynamic>> items, String? value, Function(String?) onChanged) {
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
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6366F1), size: 18),
          items: [
            DropdownMenuItem<String>(value: null, child: Text("All $hint")),
            ...items.map((item) => DropdownMenuItem<String>(
              value: item['id'].toString(),
              child: Text(item['name'] ?? '', overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _editProduct(Map<String, dynamic> product) async {
    final String productId = product['id'].toString();
    try {
      final rulesRes = await supabase.from('price_rules').select('*, units(name)').eq('product_id', productId);
      final invRes = await supabase.from('inventory').select('store_id').eq('product_id', productId);
      List<String> assignedStoreIds = invRes.map((r) => r['store_id'].toString()).toList();

      if (!context.mounted) return;
      _showAddProductDialog(
        isEditing: true,
        existingProduct: product,
        initialAssignedStores: assignedStoreIds,
        existingRules: List<Map<String, dynamic>>.from(rulesRes),
      );
    } catch (e) {
      debugPrint("Edit Load Error: $e");
    }
  }

  void _showAddProductDialog({
    bool isEditing = false,
    Map<String, dynamic>? existingProduct,
    List<String>? initialAssignedStores,
    List<Map<String, dynamic>>? existingRules,
  }) async {
    final storesRes = await supabase.from('stores').select('id, name').order('name');
    final catsRes = await supabase.from('categories').select('id, name').order('name');
    final unitsRes = await supabase.from('units').select('id, name').order('name');
    final payeesRes = await supabase.from('payees').select('id, name').order('name');

    if (!context.mounted) return;

    final allStores = List<Map<String, dynamic>>.from(storesRes);
    final allCategories = List<Map<String, dynamic>>.from(catsRes);
    final allUnits = List<Map<String, dynamic>>.from(unitsRes);
    final allPayees = List<Map<String, dynamic>>.from(payeesRes);

    List<Map<String, dynamic>> tempRules = List.from(existingRules ?? []);
    bool isActive = true;

    if (isEditing && existingProduct != null) {
      _skuController.text = existingProduct['sku'] ?? '';
      _nameController.text = existingProduct['name'] ?? '';
      _priceController.text = (existingProduct['base_price'] ?? 0).toString();
      _costController.text = (existingProduct['cost_price'] ?? 0).toString();
      isActive = existingProduct['is_active'] ?? true;
    } else {
      _skuController.clear();
      _nameController.clear();
      _priceController.clear();
      _costController.clear();
      isActive = true;
    }

    String? selectedCategoryId = isEditing ? existingProduct!['category_id']?.toString() : null;
    String? selectedUnitId = isEditing ? existingProduct!['unit_id']?.toString() : null;
    int? selectedPayeeId = isEditing ? (existingProduct!['payee_id'] as int?) : null;

    final safeInitialStores = initialAssignedStores ?? [];
    Map<String, bool> selectedStores = {
      for (var s in allStores)
        s['id'].toString(): isEditing ? safeInitialStores.contains(s['id'].toString()) : false
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isEditing ? "Edit Master Product" : "Add Master Product",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text(isActive ? "Active" : "Archived",
                      style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                  Switch(
                    value: isActive,
                    // FIXED: activeColor is deprecated. Using activeTrackColor + thumbColor.
                    activeTrackColor: Colors.greenAccent,
                    inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                    thumbColor: WidgetStateProperty.all(Colors.white),
                    onChanged: (val) {
                      setDialogState(() => isActive = val);
                    },
                  ),
                ],
              )
            ],
          ),
          content: SizedBox(
            width: 950,
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("PRIMARY DETAILS"),
                        _dialogField("SKU / Barcode", _skuController, Icons.qr_code, enabled: true),
                        _dialogField("Product Name", _nameController, Icons.label),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _dialogField("Cost Price", _costController, Icons.account_balance_wallet, isNumber: true)),
                            const SizedBox(width: 15),
                            Expanded(child: _dialogField("Selling Price", _priceController, Icons.payments, isNumber: true)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle("CATEGORIZATION & SUPPLIER"),
                        // FIXED: Replaced 'value' with 'initialValue'
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategoryId,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputStyle("Category", Icons.category),
                          items: allCategories.map((cat) => DropdownMenuItem(value: cat['id'].toString(), child: Text(cat['name']))).toList(),
                          onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                        ),
                        const SizedBox(height: 15),
                        // FIXED: Replaced 'value' with 'initialValue'
                        DropdownButtonFormField<String>(
                          initialValue: selectedUnitId,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputStyle("Base Unit", Icons.straighten),
                          items: allUnits.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text(u['name']))).toList(),
                          onChanged: (val) => setDialogState(() => selectedUnitId = val),
                        ),
                        const SizedBox(height: 15),
                        // FIXED: Replaced 'value' with 'initialValue'
                        DropdownButtonFormField<int>(
                          initialValue: selectedPayeeId,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputStyle("Supplier / Payee", Icons.business_center_outlined),
                          items: allPayees.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['name']))).toList(),
                          onChanged: (val) => setDialogState(() => selectedPayeeId = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  const VerticalDivider(color: Colors.white10, width: 1),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("WHOLESALE PRICE RULES"),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                          child: ListView(
                            children: [
                              ...tempRules.map((rule) => ListTile(
                                dense: true,
                                title: Text("${rule['min_quantity']}+ ${rule['units']?['name'] ?? rule['unit_name'] ?? ''}", style: const TextStyle(color: Colors.white)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("₱${(rule['unit_price'] as num? ?? 0).toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                      onPressed: () => setDialogState(() => tempRules.remove(rule)),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _addPriceRulePopup(context, allUnits, (newRule) => setDialogState(() => tempRules.add(newRule))),
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6366F1)),
                          label: const Text("Add Wholesale Price", style: TextStyle(color: Color(0xFF6366F1))),
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle("STORE AVAILABILITY"),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                          child: ListView(
                            children: [
                              ...allStores.map((store) => CheckboxListTile(
                                activeColor: const Color(0xFF6366F1),
                                title: Text(store['name'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                value: selectedStores[store['id'].toString()],
                                onChanged: (val) => setDialogState(() => selectedStores[store['id'].toString()] = val!),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
              onPressed: () async {
                final String sku = _skuController.text.trim();
                final currentSelectedIds = selectedStores.entries.where((e) => e.value).map((e) => e.key).toList();

                if (sku.isEmpty) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SKU is required")));
                  return;
                }

                try {
                  var duplicateQuery = supabase.from('products').select('id, name').eq('sku', sku);
                  if (isEditing) duplicateQuery = duplicateQuery.neq('id', existingProduct!['id']);
                  final duplicateRes = await duplicateQuery.maybeSingle();

                  // FIXED: Async Gap Check
                  if (!context.mounted) return;

                  if (duplicateRes != null) {
                    showDialog(context: context, builder: (ctx) => AlertDialog(content: Text("Barcode exists on '${duplicateRes['name']}'")));
                    return;
                  }

                  if (isEditing) {
                    final String productId = existingProduct!['id'].toString();
                    await supabase.from('products').update({
                      'sku': sku,
                      'name': _nameController.text.trim(),
                      'cost_price': double.tryParse(_costController.text) ?? 0.0,
                      'base_price': double.tryParse(_priceController.text) ?? 0.0,
                      'category_id': selectedCategoryId,
                      'unit_id': selectedUnitId,
                      'payee_id': selectedPayeeId,
                      'is_active': isActive,
                    }).eq('id', productId);

                    final toRemove = safeInitialStores.where((id) => !currentSelectedIds.contains(id)).toList();
                    if (toRemove.isNotEmpty) await supabase.from('inventory').delete().eq('product_id', productId).inFilter('store_id', toRemove);

                    final toAdd = currentSelectedIds.where((id) => !safeInitialStores.contains(id)).toList();
                    if (toAdd.isNotEmpty) {
                      final List<Map<String, dynamic>> newInv = toAdd.map((sId) => {'store_id': sId, 'product_id': productId, 'stock_quantity': 0}).toList();
                      await supabase.from('inventory').upsert(newInv).select();
                    }

                    await supabase.from('price_rules').delete().eq('product_id', productId);
                    if (tempRules.isNotEmpty) {
                      final rules = tempRules.map((r) => {'product_id': productId, 'unit_id': r['unit_id'], 'min_quantity': r['min_quantity'], 'unit_price': r['unit_price']}).toList();
                      await supabase.from('price_rules').insert(rules);
                    }
                  } else {
                    final newProduct = await supabase.from('products').insert({
                      'sku': sku,
                      'name': _nameController.text.trim(),
                      'cost_price': double.tryParse(_costController.text) ?? 0.0,
                      'base_price': double.tryParse(_priceController.text) ?? 0.0,
                      'category_id': selectedCategoryId,
                      'unit_id': selectedUnitId,
                      'payee_id': selectedPayeeId,
                      'is_active': isActive,
                    }).select().single();

                    final newPid = newProduct['id'];

                    if (currentSelectedIds.isNotEmpty) {
                      final List<Map<String, dynamic>> invRows = currentSelectedIds.map((sId) => {'store_id': sId, 'product_id': newPid, 'stock_quantity': 0}).toList();
                      await supabase.from('inventory').upsert(invRows).select();
                    }

                    if (tempRules.isNotEmpty) {
                      final rules = tempRules.map((r) => {'product_id': newPid, 'unit_id': r['unit_id'], 'min_quantity': r['min_quantity'], 'unit_price': r['unit_price']}).toList();
                      await supabase.from('price_rules').insert(rules);
                    }
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    _refresh();
                  }
                } catch (e) {
                  debugPrint("Save Error: $e");
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: Text(isEditing ? "Save & Sync" : "Create Master Product", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _addPriceRulePopup(BuildContext context, List<Map<String, dynamic>> allUnits, Function(Map<String, dynamic>) onSave) {
    final qtyController = TextEditingController();
    final priceController = TextEditingController();
    String? selectedUnitId;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setIntState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Add Wholesale Rule", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField("Min Quantity", qtyController, Icons.numbers, isNumber: true),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedUnitId,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: _inputStyle("Unit", Icons.straighten),
                items: allUnits.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text(u['name']))).toList(),
                onChanged: (val) => setIntState(() => selectedUnitId = val),
              ),
              const SizedBox(height: 10),
              _dialogField("Price per Unit", priceController, Icons.payments, isNumber: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () {
                if (qtyController.text.isNotEmpty && priceController.text.isNotEmpty && selectedUnitId != null) {
                  onSave({'unit_id': selectedUnitId, 'min_quantity': int.parse(qtyController.text), 'unit_price': double.parse(priceController.text), 'unit_name': allUnits.firstWhere((u) => u['id'].toString() == selectedUnitId.toString())['name']});
                  Navigator.pop(context);
                }
              },
              child: const Text("Add Rule"),
            )
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 5), child: Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)));

  Widget _dialogField(String label, TextEditingController ctrl, IconData icon, {bool enabled = true, bool isNumber = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: enabled ? Colors.white : Colors.white24),
      decoration: _inputStyle(label, icon),
    ),
  );

  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
    prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 18),
    filled: true,
    fillColor: const Color(0xFF0F172A),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
  );
}