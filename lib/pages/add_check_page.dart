// lib/pages/add_check_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../models/check_model.dart';
import '../models/payee_model.dart';
import 'add_payee_page.dart';

class AddCheckPage extends StatefulWidget {
	final BusinessCheck? checkToEdit;

	const AddCheckPage({super.key, this.checkToEdit});

	@override
	State<AddCheckPage> createState() => _AddCheckPageState();
}

class _AddCheckPageState extends State<AddCheckPage> {
	final _formKey = GlobalKey<FormState>();

	Payee? _selectedPayee;
	final _amountController = TextEditingController();
	final _memoController = TextEditingController();
	final _checkNumberController = TextEditingController();

	DateTime? _issueDate;
	DateTime? _dueDate;
	bool _isLoading = false;

	List<Payee> _payeeOptions = [];
	bool _isFetchingPayees = true;

	bool get _isEditMode => widget.checkToEdit != null;

	@override
	void initState() {
		super.initState();
		_initializeFields();
	}

	// --- NEW: A dedicated function to set up all initial fields ---
	Future<void> _initializeFields() async {
		// Set dates first
		if (_isEditMode) {
			final check = widget.checkToEdit!;
			_amountController.text = check.amount.toString();
			_memoController.text = check.memo ?? '';
			_checkNumberController.text = check.checkNumber?.toString() ?? '';
			_issueDate = check.issueDate;
			_dueDate = check.dueDate;
		} else {
			_issueDate = DateTime.now();
			_dueDate = DateTime.now().add(const Duration(days: 30));
		}

		// Then, fetch payees and set the initial selection
		await _getPayees();
	}


	Future<void> _getPayees() async {
		if (!mounted) return;
		setState(() { _isFetchingPayees = true; });

		try {
			final response = await Supabase.instance.client
					.from('payees')
					.select()
					.order('name', ascending: true);

			if (mounted) {
				_payeeOptions = response.map((map) => Payee.fromMap(map)).toList();

				// --- MODIFIED: Logic now only sets the _selectedPayee state variable ---
				if (_isEditMode) {
					final check = widget.checkToEdit!;
					try {
						// Set the state variable that will be used as the initialValue
						_selectedPayee = _payeeOptions.firstWhere((p) => p.name == check.payeeName);
					} catch (e) {
						// Payee might have been deleted. _selectedPayee will remain null.
					}
				}
				// ----------------------------------------------------------------------
			}
		} catch (e) {
			if(mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(
					content: Text('Error fetching payees: ${e.toString()}'),
					backgroundColor: Colors.red,
				));
			}
		} finally {
			if (mounted) setState(() { _isFetchingPayees = false; });
		}
	}

	// _selectDate function remains the same...
	Future<void> _selectDate(BuildContext context, {required bool isDueDate}) async {
		final picked = await showDatePicker(
			context: context,
			initialDate: (isDueDate ? _dueDate : _issueDate) ?? DateTime.now(),
			firstDate: DateTime(2020),
			lastDate: DateTime(2030),
		);
		if (picked != null) {
			setState(() {
				if (isDueDate) {
					_dueDate = picked;
				} else {
					_issueDate = picked;
				}
			});
		}
	}

	// _saveCheck function remains the same...
	Future<void> _saveCheck() async {
		if (!_formKey.currentState!.validate()) return;

		if (_selectedPayee == null || _issueDate == null || _dueDate == null) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
				content: Text('Please select a payee and both issue and due dates.'),
				backgroundColor: Colors.red,
			));
			return;
		}

		setState(() { _isLoading = true; });

		try {
			final data = {
				'payee_name': _selectedPayee!.name,
				'amount': double.parse(_amountController.text.trim()),
				'memo': _memoController.text.trim(),
				'check_number': int.tryParse(_checkNumberController.text.trim()),
				'issue_date': _issueDate!.toIso8601String(),
				'due_date': _dueDate!.toIso8601String(),
			};

			if (_isEditMode) {
				await Supabase.instance.client
						.from('business_checks')
						.update(data)
						.eq('id', widget.checkToEdit!.id);
			} else {
				data['status'] = 'pending';
				await Supabase.instance.client.from('business_checks').insert(data);
			}

			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(
				content: Text('Check successfully ${_isEditMode ? "updated" : "added"}!'),
				backgroundColor: Colors.green,
			));
			Navigator.of(context).pop(true);
		} catch (e) {
			if(mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(
					content: Text('Error saving check: ${e.toString()}'),
					backgroundColor: Colors.red,
				));
			}
		} finally {
			if (mounted) setState(() { _isLoading = false; });
		}
	}

	@override
	void dispose() {
		_amountController.dispose();
		_memoController.dispose();
		_checkNumberController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: Text(_isEditMode ? 'Edit Check' : 'Add New Check')),
			body: Padding(
				padding: const EdgeInsets.all(16.0),
				child: Form(
					key: _formKey,
					child: ListView(
						children: [
							Row(
								crossAxisAlignment: CrossAxisAlignment.end,
								children: [
									Expanded(
										// --- MODIFIED: Replaced 'value' with 'initialValue' ---
										child: DropdownButtonFormField<Payee>(
											// The 'value' property is removed.
											initialValue: _selectedPayee, // This sets the starting value.
											isExpanded: true,
											decoration: InputDecoration(
												labelText: 'Select Payee',
												suffixIcon: _isFetchingPayees
														? const Padding(
													padding: EdgeInsets.all(10.0),
													child: CircularProgressIndicator(strokeWidth: 2),
												)
														: null,
											),
											items: _payeeOptions.map((Payee payee) {
												return DropdownMenuItem<Payee>(
													value: payee, // This value is for the item itself
													child: Text(payee.name, overflow: TextOverflow.ellipsis),
												);
											}).toList(),
											onChanged: (Payee? newValue) {
												setState(() {
													// The 'onChanged' callback now updates our state
													_selectedPayee = newValue;
												});
											},
											validator: (value) => value == null ? 'Please select a payee' : null,
										),
										// -------------------------------------------------------------
									),
									const SizedBox(width: 8),
									IconButton(
										icon: const Icon(Icons.person_add_alt_1),
										tooltip: 'Add New Payee',
										onPressed: () async {
											final newPayeeWasAdded = await Navigator.of(context).push<bool>(
												MaterialPageRoute(builder: (context) => const AddPayeePage()),
											);
											if (newPayeeWasAdded == true) {
												// Await the fetch and then rebuild to see the new value
												await _getPayees();
												setState(() {});
											}
										},
									),
								],
							),
							const SizedBox(height: 16),
							TextFormField(
								controller: _amountController,
								decoration: const InputDecoration(labelText: 'Amount'),
								keyboardType: const TextInputType.numberWithOptions(decimal: true),
								validator: (value) {
									if (value == null || value.isEmpty) return 'Enter amount';
									if (double.tryParse(value) == null) return 'Enter a valid number';
									return null;
								},
							),
							const SizedBox(height: 8),
							TextFormField(
								controller: _memoController,
								decoration: const InputDecoration(labelText: 'Memo'),
							),
							const SizedBox(height: 8),
							TextFormField(
								controller: _checkNumberController,
								decoration: const InputDecoration(labelText: 'Check Number (Optional)'),
								keyboardType: TextInputType.number,
							),
							const SizedBox(height: 16),
							Row(
								children: [
									Expanded(
										child: ListTile(
											title: Text('Issue Date: ${_issueDate == null ? "Not Set" : DateFormat.yMMMd().format(_issueDate!)}'),
											trailing: IconButton(
												icon: const Icon(Icons.calendar_today),
												onPressed: () => _selectDate(context, isDueDate: false),
											),
										),
									),
									Expanded(
										child: ListTile(
											title: Text('Due Date: ${_dueDate == null ? "Not Set" : DateFormat.yMMMd().format(_dueDate!)}'),
											trailing: IconButton(
												icon: const Icon(Icons.calendar_today),
												onPressed: () => _selectDate(context, isDueDate: true),
											),
										),
									),
								],
							),
							const SizedBox(height: 24),
							ElevatedButton(
								onPressed: _isLoading ? null : _saveCheck,
								child: _isLoading
										? const SizedBox(
									height: 24,
									width: 24,
									child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
								)
										: Text(_isEditMode ? 'Update Check' : 'Save Check'),
							),
						],
					),
				),
			),
		);
	}
}

