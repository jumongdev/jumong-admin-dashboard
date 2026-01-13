// lib/pages/product_sub_pages/item_history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ItemHistoryPage extends StatefulWidget {
  const ItemHistoryPage({super.key});

  @override
  State<ItemHistoryPage> createState() => _ItemHistoryPageState();
}

class _ItemHistoryPageState extends State<ItemHistoryPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // FIX: Removed 'auth_users' join which was causing the relationship error.
      // We join products and stores.
      // If you need the staff name, it must be joined via a table in the 'public' schema (like profiles).
      final res = await supabase
          .from('product_logs')
          .select('''
            *,
            products(name, sku),
            stores(name)
          ''')
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundDeep = Color(0xFF0F172A);
    const surfaceSlate = Color(0xFF1E293B);
    const primaryIndigo = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: backgroundDeep,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryIndigo))
          : _logs.isEmpty
          ? const Center(child: Text("No history found.", style: TextStyle(color: Colors.white24)))
          : RefreshIndicator(
        onRefresh: _fetchHistory,
        color: primaryIndigo,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _logs.length,
          itemBuilder: (context, index) {
            final log = _logs[index];
            final String type = log['change_type'] ?? 'Edit';
            final date = DateTime.parse(log['created_at']).toLocal();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: surfaceSlate,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ListTile(
                leading: _getLeadingIcon(type),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        log['products']?['name'] ?? 'Unknown Item',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, hh:mm a').format(date),
                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text("Stock Move: ", style: TextStyle(color: Colors.white38, fontSize: 11)),
                        Text(
                          "${log['old_value']} ➔ ${log['new_value']}",
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (log['notes'] != null && log['notes'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(6)
                          ),
                          child: Text(
                            log['notes'],
                            style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Store: ${log['stores']?['name'] ?? 'Main'}",
                          style: const TextStyle(color: primaryIndigo, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(color: Colors.white24, fontSize: 9, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _getLeadingIcon(String type) {
    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'request approved':
        icon = Icons.add_business_rounded;
        color = Colors.blueAccent;
        break;
      case 'sale':
        icon = Icons.shopping_basket_rounded;
        color = Colors.orangeAccent;
        break;
      case 'stock update':
      case 'stock adjustment':
        icon = Icons.tune_rounded;
        color = Colors.purpleAccent;
        break;
      default:
        icon = Icons.history_rounded;
        color = Colors.white24;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
