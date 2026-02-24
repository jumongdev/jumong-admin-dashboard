import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagePaymentsPage extends StatefulWidget {
  const ManagePaymentsPage({super.key});

  @override
  State<ManagePaymentsPage> createState() => _ManagePaymentsPageState();
}

class _ManagePaymentsPageState extends State<ManagePaymentsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> _stores = [];
  String? _selectedStoreId;
  List<dynamic> _channels = [];
  bool _isLoading = false;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _accNumController = TextEditingController();
  final _accNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accNumController.dispose();
    _accNameController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    try {
      final data = await supabase.from('stores').select('id, name').order('name');
      if (!mounted) return;
      setState(() => _stores = data);
    } catch (e) {
      debugPrint("Store Load Error: $e");
      _showError("Failed to load stores: $e");
    }
  }

  Future<void> _loadChannels(String storeId) async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('payment_channels')
          .select()
          .eq('store_id', storeId)
          .order('name'); // Changed order to name for better readability

      if (!mounted) return;
      setState(() => _channels = data);
    } catch (e) {
      debugPrint("Channel Load Error: $e");
      _showError("Failed to load accounts: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChannel() async {
    final name = _nameController.text.trim();
    if (_selectedStoreId == null) return;
    if (name.isEmpty) {
      _showError("Please enter a Service Name (e.g. GCash)");
      return;
    }

    setState(() => _isSaving = true);
    try {
      // payload matches your public.payment_channels schema exactly
      final Map<String, dynamic> payload = {
        'store_id': _selectedStoreId,
        'name': name,
        'account_number': _accNumController.text.trim(),
        'account_name': _accNameController.text.trim(),
        'is_active': true,
      };

      // select() ensures we get confirmation from the DB
      await supabase.from('payment_channels').insert(payload).select();

      if (!mounted) return;

      _nameController.clear();
      _accNumController.clear();
      _accNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      _loadChannels(_selectedStoreId!);
    } catch (e) {
      debugPrint("Save Error: $e");
      _showError("Error saving account: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Changed id to dynamic because your DB uses bigint (int8)
  Future<void> _confirmDelete(dynamic id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Delete Account?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to remove '$name'?",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('payment_channels').delete().eq('id', id);
        if (mounted) _loadChannels(_selectedStoreId!);
      } catch (e) {
        debugPrint("Delete Error: $e");
        _showError("Error deleting: $e");
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Store List (Left)
          Container(
            width: 280,
            color: Theme.of(context).cardColor.withValues(alpha: 0.5),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Manage Stores",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _stores.length,
                    itemBuilder: (context, i) {
                      final store = _stores[i];
                      final isSelected = _selectedStoreId == store['id'];
                      return ListTile(
                        leading: Icon(Icons.store,
                            color: isSelected ? Colors.blue : null),
                        title: Text(store['name']),
                        selected: isSelected,
                        onTap: () {
                          setState(() => _selectedStoreId = store['id']);
                          _loadChannels(store['id']);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // Management UI (Right)
          Expanded(
            child: _selectedStoreId == null
                ? const Center(child: Text("Select a store to manage payments"))
                : Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Payment Methods",
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),

                  // Input Area
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                      labelText: "Service (e.g. GCash)"))),
                          const SizedBox(width: 15),
                          Expanded(
                              child: TextField(
                                  controller: _accNameController,
                                  decoration: const InputDecoration(
                                      labelText: "Account Name"))),
                          const SizedBox(width: 15),
                          Expanded(
                              child: TextField(
                                  controller: _accNumController,
                                  decoration: const InputDecoration(
                                      labelText: "Account Number"))),
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveChannel,
                            icon: _isSaving
                                ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                                : const Icon(Icons.add),
                            label: const Text("Save"),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Existing List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _channels.isEmpty
                        ? const Center(
                        child: Text("No accounts linked yet."))
                        : ListView.builder(
                      itemCount: _channels.length,
                      itemBuilder: (context, i) => Card(
                        child: ListTile(
                          title: Text(_channels[i]['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              "${_channels[i]['account_name'] ?? 'N/A'} • ${_channels[i]['account_number'] ?? 'N/A'}"),
                          trailing: IconButton(
                            icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _confirmDelete(
                                _channels[i]['id'],
                                _channels[i]['name']),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}