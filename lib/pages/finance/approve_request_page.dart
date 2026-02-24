// lib/pages/product_sub_pages/approve_request_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApproveRequestPage extends StatefulWidget {
  const ApproveRequestPage({super.key});
  @override
  State<ApproveRequestPage> createState() => _ApproveRequestPageState();
}

class _ApproveRequestPageState extends State<ApproveRequestPage> {
  // ... (Keep existing State variables and initState/dispose)
  bool _isLoading = true;
  bool _showHistory = false;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      var query = supabase.from('stock_requests').select('*, stores(name)');

      if (_showHistory) {
        query = query.neq('status', 'pending');
      } else {
        query = query.eq('status', 'pending');
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Keep _editItemQuantity helper logic)
  void _editItemQuantity(Map<String, dynamic> request, int itemIndex) {
    // ... (Use same code as before for the dialog) ...
    final List items = List.from(request['items']);
    final TextEditingController qtyController =
    TextEditingController(text: items[itemIndex]['quantity'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Edit Qty for ${items[itemIndex]['name']}",
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: qtyController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Correct Quantity",
            filled: true,
            fillColor: Colors.black26,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newQty = int.tryParse(qtyController.text) ?? 0;
              items[itemIndex]['quantity'] = newQty;

              await Supabase.instance.client
                  .from('stock_requests')
                  .update({'items': items})
                  .eq('id', request['id']);

              if (context.mounted) Navigator.pop(context);
              _fetchRequests();
            },
            child: const Text("Save Change"),
          ),
        ],
      ),
    );
  }

  // FIX: Update INVENTORY logic
  Future<void> _handleApproval(Map<String, dynamic> request) async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final List items = request['items'];
      final String? adminId = supabase.auth.currentUser?.id;
      final String storeId = request['store_id']; // This is critical

      for (var item in items) {
        final productId = item['product_id'];
        final int incomingQty = item['quantity'] ?? 0;

        // 1. Check current inventory for this store/product combo
        final invRes = await supabase
            .from('inventory')
            .select('stock_quantity')
            .eq('product_id', productId)
            .eq('store_id', storeId)
            .maybeSingle();

        int currentQty = invRes != null ? invRes['stock_quantity'] : 0;
        int newTotalQty = currentQty + incomingQty;

        // 2. Update INVENTORY table
        await supabase
            .from('inventory')
            .upsert({
          'store_id': storeId,
          'product_id': productId,
          'stock_quantity': newTotalQty
        }, onConflict: 'store_id, product_id'); // Ensure unique constraint in DB if possible, otherwise Supabase handles logic

        // 3. Insert into History Logs
        await supabase.from('product_logs').insert({
          'product_id': productId,
          'store_id': storeId,
          'user_id': adminId,
          'change_type': 'Request Approved',
          'old_value': '$currentQty pcs',
          'new_value': '$newTotalQty pcs',
          'notes': 'Added $incomingQty pcs (DR: ${request['dr_number']})',
        });
      }

      await supabase.from('stock_requests').update({
        'status': 'approved',
        'approved_by': adminId,
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', request['id']);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Approved & Inventory Updated"), backgroundColor: Colors.green),
        );
        _fetchRequests();
      }
    } catch (e) {
      debugPrint("Approval Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Rest of UI code remains exactly the same as original)
  Future<void> _handleReject(String requestId) async {
    await Supabase.instance.client
        .from('stock_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
    _fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    const surfaceSlate = Color(0xFF1E293B);
    const primaryIndigo = Color(0xFF6366F1);

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_showHistory ? "REQUEST HISTORY" : "STOCK RECEIVING APPROVALS",
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: surfaceSlate, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    _buildToggleButton("Pending", !_showHistory),
                    _buildToggleButton("History", _showHistory),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryIndigo))
                : _requests.isEmpty
                ? const Center(child: Text("No records found.", style: TextStyle(color: Colors.white24)))
                : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final items = req['items'] as List;
                final status = req['status'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: surfaceSlate,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white54,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req['delivery_name'] ?? "No Supplier",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("Store: ${req['stores']?['name'] ?? 'N/A'} | DR#: ${req['dr_number']}",
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    trailing: _showHistory
                        ? _buildStatusBadge(status)
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                          onPressed: () => _handleApproval(req),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
                          onPressed: () => _handleReject(req['id']),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        color: Colors.black12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(status == 'pending' ? "REQUESTED ITEMS (Edit allowed):" : "PROCESSED ITEMS:",
                                style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                            const Divider(color: Colors.white10),
                            ...items.asMap().entries.map((entry) {
                              int idx = entry.key;
                              var item = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['name'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    Row(
                                      children: [
                                        Text("x${item['quantity']}",
                                            style: const TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold)),
                                        if (status == 'pending') ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 16, color: Colors.white38),
                                            onPressed: () => _editItemQuantity(req, idx),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
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
    );
  }

  Widget _buildToggleButton(String label, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() => _showHistory = label == "History");
        _fetchRequests();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'approved' ? Colors.greenAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}