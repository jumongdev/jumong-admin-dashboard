// lib/pages/product_sub_pages/payee_list_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PayeeListPage extends StatefulWidget {
  const PayeeListPage({super.key});

  @override
  State<PayeeListPage> createState() => _PayeeListPageState();
}

class _PayeeListPageState extends State<PayeeListPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _payees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPayees();
  }

  Future<void> _fetchPayees() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('payees').select().order('name');
      setState(() {
        _payees = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPayeeDialog({Map<String, dynamic>? payee}) async {
    final nameCtrl = TextEditingController(text: payee?['name']);
    final personCtrl = TextEditingController(text: payee?['contact_person']);
    final mobileCtrl = TextEditingController(text: payee?['mobile_number']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B), // surfaceSlate
        title: Text(
          payee == null ? "Add New Supplier" : "Edit Supplier",
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Company Name
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Company Name",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                ),
              ),
              const SizedBox(height: 15),
              // 2. Contact Person (NEW)
              TextField(
                controller: personCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Contact Person",
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.person_outline, color: Colors.white24, size: 20),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                ),
              ),
              const SizedBox(height: 15),
              // 3. Mobile Number (UPDATED COLUMN NAME)
              TextField(
                controller: mobileCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Mobile Number",
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.phone_android_outlined, color: Colors.white24, size: 20),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;

              final data = {
                'name': nameCtrl.text.trim(),
                'contact_person': personCtrl.text.trim(),
                'mobile_number': mobileCtrl.text.trim(),
              };

              try {
                if (payee == null) {
                  await _supabase.from('payees').insert(data);
                } else {
                  await _supabase.from('payees').update(data).eq('id', payee['id']);
                }
                if (!mounted) return;
                Navigator.pop(context);
                _fetchPayees();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Save Supplier"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPayeeDialog(),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text("Add Supplier"),
      ),
      body: _payees.isEmpty
          ? const Center(child: Text("No suppliers found", style: TextStyle(color: Colors.white24)))
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _payees.length,
        separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final p = _payees[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            leading: const CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(Icons.business_rounded, color: Colors.white54, size: 20),
            ),
            title: Text(
              p['name'] ?? 'Unnamed',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p['contact_person'] != null && p['contact_person'].toString().isNotEmpty)
                  Text(
                    "Attn: ${p['contact_person']}",
                    style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11),
                  ),
                Text(
                  p['mobile_number'] ?? 'No contact number',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
                  onPressed: () => _showPayeeDialog(payee: p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  onPressed: () async {
                    bool? confirm = await _showDeleteConfirm(p['name']);
                    if (confirm == true) {
                      try {
                        await _supabase.from('payees').delete().eq('id', p['id']);
                        _fetchPayees();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Cannot delete: Supplier is linked to products.")),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(String name) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Delete Supplier?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to remove $name?", style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
