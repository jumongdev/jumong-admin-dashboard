import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnitListPage extends StatefulWidget {
  const UnitListPage({super.key});
  @override
  State<UnitListPage> createState() => _UnitListPageState();
}

class _UnitListPageState extends State<UnitListPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUnits();
  }

  Future<void> _fetchUnits() async {
    setState(() => _isLoading = true);
    final data = await _supabase.from('units').select().order('name');
    setState(() {
      _units = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
    });
  }

  Future<void> _showDialog({Map<String, dynamic>? unit}) async {
    final controller = TextEditingController(text: unit?['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(unit == null ? "Add Unit" : "Edit Unit", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "Unit Name (e.g. pcs, box)", labelStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              if (unit == null) {
                await _supabase.from('units').insert({'name': controller.text.trim()});
              } else {
                await _supabase.from('units').update({'name': controller.text.trim()}).eq('id', unit['id']);
              }
              Navigator.pop(context);
              _fetchUnits();
            },
            child: const Text("Save"),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _units.length,
        itemBuilder: (context, index) {
          final item = _units[index];
          return ListTile(
            title: Text(item['name'], style: const TextStyle(color: Colors.white)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showDialog(unit: item)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    // Note: This will fail if a product is currently using this unit (Foreign Key protection)
                    try {
                      await _supabase.from('units').delete().eq('id', item['id']);
                      _fetchUnits();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot delete: Unit is in use by products")));
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
}