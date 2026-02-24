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

  // Helper to extract numbers from strings like "850 pcs"
  double _parseValue(dynamic val) {
    if (val == null) return 0;
    // Remove " pcs" or any other text and keep only numbers/dots
    String cleanStr = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanStr) ?? 0;
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
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
      debugPrint("Fetch Error: $e");
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
            final String type = log['change_type'] ?? 'Stock Update';

            // Format Date safely
            DateTime date;
            try {
              date = DateTime.parse(log['created_at']).toLocal();
            } catch (_) {
              date = DateTime.now();
            }

            // Parse numbers from strings like "850 pcs"
            final double oldVal = _parseValue(log['old_value']);
            final double newVal = _parseValue(log['new_value']);
            final bool isIncrease = newVal > oldVal;
            final double diff = (newVal - oldVal).abs();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: surfaceSlate,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ListTile(
                leading: _getLeadingIcon(type, isIncrease),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        log['products']?['name'] ?? 'Unknown Item',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Display the raw strings from DB ("850 pcs")
                        Text(
                          "${log['old_value'] ?? '0'} ➔ ${log['new_value'] ?? '0'}",
                          style: TextStyle(
                              color: isIncrease ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Calculate difference
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isIncrease ? Colors.green : Colors.red).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${isIncrease ? '+' : '-'}${diff.toStringAsFixed(0)}",
                            style: TextStyle(
                                color: isIncrease ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        )
                      ],
                    ),

                    if (log['notes'] != null && log['notes'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          log['notes'],
                          style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ),

                    const SizedBox(height: 10),
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

  Widget _getLeadingIcon(String type, bool isIncrease) {
    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'sale':
        icon = Icons.shopping_basket;
        color = Colors.orangeAccent;
        break;
      case 'stock adjustment':
      case 'request approved':
        icon = isIncrease ? Icons.add_circle_outline : Icons.remove_circle_outline;
        color = isIncrease ? Colors.greenAccent : Colors.redAccent;
        break;
      default:
        icon = Icons.history;
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