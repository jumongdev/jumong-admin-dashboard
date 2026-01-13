import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddStorePage extends StatefulWidget {const AddStorePage({super.key});

@override
State<AddStorePage> createState() => _AddStorePageState();
}

class _AddStorePageState extends State<AddStorePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isEcommerceEnabled = false;
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  Future<void> _addStore() async {
    // First, validate the form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Create a map of data to insert
      // NOTE: Supabase uses snake_case for column names
      final storeData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'is_ecommerce_enabled': _isEcommerceEnabled,
      };

      // Perform the insert operation
      await _supabase.from('stores').insert(storeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop the page and return 'true' to signal a successful addition
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding store: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a New Store'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_center),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a store name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Location Field
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location / Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                // Location can be optional, so no validator
              ),
              const SizedBox(height: 16),

              // Is Ecommerce Enabled Switch
              SwitchListTile(
                title: const Text('Enable for eCommerce'),
                subtitle: const Text('Accept online orders for this store'),
                value: _isEcommerceEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _isEcommerceEnabled = value;
                  });
                },
                secondary: Icon(_isEcommerceEnabled ? Icons.storefront : Icons.store),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _addStore,
                icon: _isLoading
                    ? Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(2.0),
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                    : const Icon(Icons.save),
                label: const Text('Save Store'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
