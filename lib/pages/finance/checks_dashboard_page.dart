// lib/pages/checks_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/check_model.dart';
import 'add_check_page.dart';
import 'check_history_page.dart';

// --- Reusable Sortable Header Widget ---
class SortableHeader extends StatelessWidget {
  final String title;
  final String columnName;
  final String currentSortColumn;
  final bool isAscending;
  final VoidCallback onTap;

  // --- MODIFIED: Added const ---
  const SortableHeader({
    super.key,
    required this.title,
    required this.columnName,
    required this.currentSortColumn,
    required this.isAscending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        // --- MODIFIED: Added const ---
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (currentSortColumn == columnName)
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
// --- END of SortableHeader Widget ---

class ChecksDashboardPage extends StatefulWidget {
  // --- MODIFIED: Added const ---
  const ChecksDashboardPage({super.key});

  @override
  State<ChecksDashboardPage> createState() => _ChecksDashboardPageState();
}

class _ChecksDashboardPageState extends State<ChecksDashboardPage> {
  // ... (State variables and logic functions do not change) ...
  DateTime? _startDate;
  DateTime? _endDate;
  List<BusinessCheck> _allChecks = [];
  List<BusinessCheck> _filteredChecks = [];
  double _totalAmount = 0.0;
  bool _isLoading = true;

  String _sortColumn = 'due_date';
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchAndFilterChecks();
  }

  Future<void> _fetchAndFilterChecks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('business_checks')
          .select()
          .eq('status', 'pending')
          .order(_sortColumn, ascending: _isAscending);

      if (mounted) {
        _allChecks = response.map((map) => BusinessCheck.fromMap(map)).toList();
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error fetching checks: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = true;
      }
      _fetchAndFilterChecks();
    });
  }

  void _applyFilters() {
    List<BusinessCheck> checksToFilter = List.from(_allChecks);

    if (_startDate != null && _endDate != null) {
      checksToFilter = checksToFilter.where((check) {
        return !check.dueDate.isBefore(_startDate!) &&
            check.dueDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    if (mounted) {
      setState(() {
        _filteredChecks = checksToFilter;
        _totalAmount =
            _filteredChecks.fold(0.0, (sum, check) => sum + check.amount);
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _applyFilters();
  }

  Future<void> _updateCheckStatus(int checkId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('business_checks')
          .update({'status': newStatus}).eq('id', checkId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Check marked as $newStatus!'),
              backgroundColor: Colors.green),
        );
        _fetchAndFilterChecks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showStatusUpdateDialog(BusinessCheck check) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Check Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Update status for Check #${check.checkNumber ?? 'N/A'}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _updateCheckStatus(check.id, 'paid');
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Mark as Paid'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _updateCheckStatus(check.id, 'cancelled');
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Mark as Cancelled'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _updateCheckStatus(check.id, 'bounced');
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Mark as Bounced'),
            ),
          ],
        ),
        actions: [
          TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final pesoFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Checks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Check History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const CheckHistoryPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchAndFilterChecks,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            // --- MODIFIED: Added const ---
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                if (_startDate != null && _endDate != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          'Range: ${DateFormat.yMMMd().format(_startDate!)} - ${DateFormat.yMMMd().format(_endDate!)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextButton(
                          onPressed: _clearFilters, child: const Text('Clear'))
                    ],
                  )
                else
                // --- MODIFIED: Added const ---
                  const Text(
                    'Showing All Pending Checks',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                  ),
                // --- MODIFIED: Added const ---
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Pending:',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(pesoFormat.format(_totalAmount),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          // --- MODIFIED: Added const ---
          const Divider(thickness: 2),
          Padding(
            // --- MODIFIED: Added const ---
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // --- MODIFIED: Added const ---
                const SizedBox(width: 10 + 16),
                Expanded(
                    flex: 3,
                    child: SortableHeader(
                        title: 'Payee',
                        columnName: 'payee_name',
                        currentSortColumn: _sortColumn,
                        isAscending: _isAscending,
                        onTap: () => _onSort('payee_name'))),
                Expanded(
                    flex: 2,
                    child: SortableHeader(
                        title: 'Check #',
                        columnName: 'check_number',
                        currentSortColumn: _sortColumn,
                        isAscending: _isAscending,
                        onTap: () => _onSort('check_number'))),
                Expanded(
                    flex: 2,
                    child: SortableHeader(
                        title: 'Amount',
                        columnName: 'amount',
                        currentSortColumn: _sortColumn,
                        isAscending: _isAscending,
                        onTap: () => _onSort('amount'))),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChecks.isEmpty
                ? Center(
              child: RefreshIndicator(
                onRefresh: _fetchAndFilterChecks,
                child: ListView(
                  // --- MODIFIED: Added const ---
                  children: const [
                    SizedBox(height: 50),
                    Center(
                        child: Text('No pending checks found.',
                            style: TextStyle(fontSize: 18))),
                  ],
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchAndFilterChecks,
              child: ListView.builder(
                itemCount: _filteredChecks.length,
                itemBuilder: (context, index) {
                  final check = _filteredChecks[index];
                  final formattedDueDate =
                  DateFormat.yMMMd().format(check.dueDate);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: Container(
                          width: 10,
                          color: _getStatusColor(check.status)),
                      title: Text(check.payeeName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'Due: $formattedDueDate\nMemo: ${check.memo ?? 'N/A'}'),
                      trailing: SizedBox(
                        width: 150,
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(
                                    check.checkNumber?.toString() ??
                                        'N/A',
                                    textAlign: TextAlign.center)),
                            Expanded(
                                child: Text(
                                    pesoFormat.format(check.amount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      onTap: () async {
                        final result =
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) =>
                                AddCheckPage(checkToEdit: check),
                          ),
                        );
                        if (result == true) {
                          _fetchAndFilterChecks();
                        }
                      },
                      onLongPress: () {
                        if (check.status == 'pending') {
                          _showStatusUpdateDialog(check);
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                'This check has already been processed (Status: ${check.status}).'),
                            backgroundColor: Colors.blueGrey,
                          ));
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => const AddCheckPage(),
            ),
          );
          if (result == true) {
            _fetchAndFilterChecks();
          }
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'bounced':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
