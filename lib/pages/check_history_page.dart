// lib/pages/check_history_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../models/check_model.dart';

class CheckHistoryPage extends StatefulWidget {
  const CheckHistoryPage({super.key});

  @override
  State<CheckHistoryPage> createState() => _CheckHistoryPageState();
}

class _CheckHistoryPageState extends State<CheckHistoryPage> {
  List<BusinessCheck> _allChecks = [];
  List<BusinessCheck> _filteredChecks = [];
  bool _isLoading = true;

  // --- NEW: State for filtering by status ---
  String? _statusFilter; // Can be 'paid', 'cancelled', 'bounced', or null

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      // Fetch all checks that are NOT pending
      final response = await Supabase.instance.client
          .from('business_checks')
          .select()
          .not('status', 'eq', 'pending') // The key query change!
          .order('due_date', ascending: false); // Show newest first

      _allChecks = response.map((map) => BusinessCheck.fromMap(map)).toList();
      _applyStatusFilter(); // Apply the current filter

    } catch (e) {
      // Error handling...
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Filter the fetched checks based on the selected status
  void _applyStatusFilter() {
    if (_statusFilter == null) {
      _filteredChecks = List.from(_allChecks);
    } else {
      _filteredChecks = _allChecks.where((c) => c.status == _statusFilter).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pesoFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- NEW: Filter chips for status ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8.0,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (selected) {
                    setState(() { _statusFilter = null; });
                    _applyStatusFilter();
                  },
                ),
                FilterChip(
                  label: const Text('Paid'),
                  selectedColor: Colors.green,
                  selected: _statusFilter == 'paid',
                  onSelected: (selected) {
                    setState(() { _statusFilter = selected ? 'paid' : null; });
                    _applyStatusFilter();
                  },
                ),
                FilterChip(
                  label: const Text('Cancelled'),
                  selectedColor: Colors.orange,
                  selected: _statusFilter == 'cancelled',
                  onSelected: (selected) {
                    setState(() { _statusFilter = selected ? 'cancelled' : null; });
                    _applyStatusFilter();
                  },
                ),
                FilterChip(
                  label: const Text('Bounced'),
                  selectedColor: Colors.red,
                  selected: _statusFilter == 'bounced',
                  onSelected: (selected) {
                    setState(() { _statusFilter = selected ? 'bounced' : null; });
                    _applyStatusFilter();
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChecks.isEmpty
                ? const Center(child: Text('No historical checks found.'))
                : ListView.builder(
              itemCount: _filteredChecks.length,
              itemBuilder: (context, index) {
                final check = _filteredChecks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: Container(
                      width: 10,
                      color: _getStatusColor(check.status),
                    ),
                    title: Text(check.payeeName),
                    subtitle: Text(
                      'Due: ${DateFormat.yMMMd().format(check.dueDate)}\nStatus: ${check.status.toUpperCase()}',
                    ),
                    trailing: Text(pesoFormat.format(check.amount)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to get status color (can be moved to a shared utils file later)
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid': return Colors.green;
      case 'bounced': return Colors.red;
      case 'cancelled': return Colors.orange;
      case 'pending': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
