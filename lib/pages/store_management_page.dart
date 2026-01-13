import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_store_page.dart'; // We will create this next

// A simple model class to hold store data
class Store {
  final String id;
  final String name;
  final String? location;
  final bool isEcommerceEnabled;

  Store({
    required this.id,
    required this.name,
    this.location,
    required this.isEcommerceEnabled,
  });

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'],
      name: map['name'],
      location: map['location'],
      isEcommerceEnabled: map['is_ecommerce_enabled'],
    );
  }
}

class StoreManagementPage extends StatefulWidget {
  const StoreManagementPage({super.key});

  @override
  State<StoreManagementPage> createState() => _StoreManagementPageState();
}

class _StoreManagementPageState extends State<StoreManagementPage> {
  final _supabase = Supabase.instance.client;
  late Future<List<Store>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = _fetchStores();
  }

  // Fetches all stores from your Supabase table
  Future<List<Store>> _fetchStores() async {
    try {
      final response = await _supabase.from('stores').select().order('name');
      final stores = response.map((map) => Store.fromMap(map)).toList();
      return stores;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching stores: $e'), backgroundColor: Colors.red),
        );
      }
      return [];
    }
  }

  // A helper to refresh the list after a new store is added
  void _refreshStores() {
    setState(() {
      _storesFuture = _fetchStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Management'),
      ),
      body: FutureBuilder<List<Store>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No stores found. Add one!'));
          }

          final stores = snapshot.data!;
          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(store.location ?? 'No location specified'),
                  trailing: Icon(
                    store.isEcommerceEnabled ? Icons.storefront : Icons.store,
                    color: store.isEcommerceEnabled ? Colors.blue : Colors.grey,
                  ),
                  // You can add onTap to edit the store
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to the AddStorePage and wait for a result
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (context) => const AddStorePage()),
          );

          // If the AddStorePage returns 'true', it means a store was added
          if (result == true) {
            _refreshStores();
          }
        },
        label: const Text('Add Store'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
