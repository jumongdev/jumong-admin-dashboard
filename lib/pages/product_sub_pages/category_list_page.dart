import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage({super.key});
  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('categories').select().order('name');
      setState(() {
        _categories = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _showDialog({Map<String, dynamic>? category}) async {
    final controller = TextEditingController(text: category?['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(category == null ? "Add Category" : "Edit Category", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "Category Name", labelStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              if (category == null) {
                await _supabase.from('categories').insert({'name': controller.text.trim()});
              } else {
                await _supabase.from('categories').update({'name': controller.text.trim()}).eq('id', category['id']);
              }
              Navigator.pop(context);
              _fetchCategories();
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
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final item = _categories[index];
          return ListTile(
            title: Text(item['name'], style: const TextStyle(color: Colors.white)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showDialog(category: item)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    await _supabase.from('categories').delete().eq('id', item['id']);
                    _fetchCategories();
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
