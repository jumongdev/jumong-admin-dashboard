// lib/pages/add_payee_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddPayeePage extends StatefulWidget {
  const AddPayeePage({super.key});

  @override
  State<AddPayeePage> createState() => _AddPayeePageState();
}

class _AddPayeePageState extends State<AddPayeePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  bool _isLoading = false;

  Future<void> _savePayee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });

    try {
      await Supabase.instance.client.from('payees').insert({
        'name': _nameController.text.trim(),
        'contact_person': _contactPersonController.text.trim(),
        'mobile_number': _mobileNumberController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payee added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Pop the page and return `true` to indicate success
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // Specifically handle the unique constraint violation
      if (e.code == '23505') { // Code for unique violation in PostgreSQL
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: A payee with this name already exists.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving payee: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Payee'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Payee Name*'),
              validator: (value) =>
              value == null || value.isEmpty ? 'Payee name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactPersonController,
              decoration: const InputDecoration(labelText: 'Contact Person (Optional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mobileNumberController,
              decoration: const InputDecoration(labelText: 'Mobile Number (Optional)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _savePayee,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Payee'),
            ),
          ],
        ),
      ),
    );
  }
}
