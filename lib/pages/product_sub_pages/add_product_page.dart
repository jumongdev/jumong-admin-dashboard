// lib/pages/product_sub_pages/add_product_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _stockController = TextEditingController(text: "0");

  String? _selectedStoreId;
  List<Map<String, dynamic>> _stores = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    final data = await Supabase.instance.client.from('stores').select('id, name').order('name');
    setState(() {
      _stores = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a store branch")));
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final supabase = Supabase.instance.client;

      // 1. Insert Product (NO STOCK QUANTITY HERE)
      final productRes = await supabase.from('products').insert({
        'sku': _skuController.text.trim(),
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'base_price': double.tryParse(_basePriceController.text.trim()) ?? 0.0,
        // 'stock_quantity': REMOVED - We use inventory table now
        'category': _categoryController.text.trim(),
        'image_url': _imageUrlController.text.trim(),
        'store_id': _selectedStoreId,
      }).select().single();

      final newProductId = productRes['id'];
      final int initialStock = int.tryParse(_stockController.text.trim()) ?? 0;

      // 2. Insert into INVENTORY Table
      await supabase.from('inventory').insert({
        'store_id': _selectedStoreId,
        'product_id': newProductId,
        'stock_quantity': initialStock,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundDeep = Color(0xFF0F172A);
    const surfaceSlate = Color(0xFF1E293B);
    const primaryIndigo = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: backgroundDeep,
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: surfaceSlate,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 900,
          margin: const EdgeInsets.symmetric(vertical: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: surfaceSlate,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Product Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 24),

                  _buildLabel("Assign to Store Branch *"),
                  DropdownButtonFormField<String>(
                    dropdownColor: surfaceSlate,
                    value: _selectedStoreId,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(Icons.store),
                    items: _stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']))).toList(),
                    onChanged: (v) => setState(() => _selectedStoreId = v),
                    validator: (v) => v == null ? "Required" : null,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _buildTextField("Product Name *", _nameController, Icons.label, (v) => v!.isEmpty ? "Required" : null)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildTextField("SKU / Barcode *", _skuController, Icons.qr_code, (v) => v!.isEmpty ? "Required" : null)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _buildTextField("Base Price (₱) *", _basePriceController, Icons.payments, (v) => v!.isEmpty ? "Required" : null, isNumber: true)),
                      const SizedBox(width: 20),
                      // This field now populates the inventory table
                      Expanded(child: _buildTextField("Opening Stock (Inventory)", _stockController, Icons.inventory, null, isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _buildTextField("Category", _categoryController, Icons.category, null)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildTextField("Image URL", _imageUrlController, Icons.image, null)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildTextField("Description", _descriptionController, Icons.description, null, maxLines: 3),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 200,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryIndigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: _isLoading ? null : _saveProduct,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Create Product", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, String? Function(String?)? validator, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: validator,
          decoration: _inputDecoration(icon),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}