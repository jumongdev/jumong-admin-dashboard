import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String fullName;
  final String role;
  UserProfile({required this.id, required this.fullName, required this.role});

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? 'No Name',
      role: map['user_role'] as String? ?? 'No Role',
    );
  }
}

class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({super.key});

  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  late Future<List<UserProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _profilesFuture = _getProfiles();
  }

  // --- DATABASE & API LOGIC ---

  Future<List<UserProfile>> _getProfiles() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, user_role')
          .order('full_name');
      return (response as List).map((map) => UserProfile.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
      rethrow;
    }
  }

  Future<void> _updateStaffAssignment(String profileId, String storeId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.from('staff_assignments').upsert({
        'profile_id': profileId,
        'store_id': storeId,
      }, onConflict: 'profile_id');

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Store assigned successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      debugPrint('Assignment Error: $e');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Failed to assign store: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<bool> _createNewUser({required String name, required String email, required String password, required String role}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.functions.invoke('create-user', body: {
        'full_name': name,
        'email': email,
        'password': password,
        'role': role
      });
      _refreshEmployeeList();
      return true;
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Create failed: $e'), backgroundColor: Colors.red));
      return false;
    }
  }

  Future<void> _updateUserRole({required String userId, required String newRole}) async {
    try {
      await Supabase.instance.client.functions.invoke('update-user-role', body: {'user_id': userId, 'new_role': newRole});
      _refreshEmployeeList();
    } catch (e) {
      debugPrint('Update Role Error: $e');
    }
  }

  Future<void> _callDeleteUser(UserProfile profile) async {
    try {
      await Supabase.instance.client.functions.invoke('delete-user', body: {'user_id': profile.id});
      _refreshEmployeeList();
    } catch (e) {
      debugPrint('Delete Error: $e');
    }
  }

  // NEW: Call your existing Edge Function for password reset
  Future<void> _updateUserPassword(String userId, String newPassword) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.functions.invoke('update-user-password', body: {
        'user_id': userId,
        'new_password': newPassword,
      });

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Password updated successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      debugPrint("Password update failed: $e");
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Update failed: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _refreshEmployeeList() {
    if (!mounted) return;
    setState(() {
      _profilesFuture = _getProfiles();
    });
  }

  // --- DIALOGS ---

  void _showChangePasswordDialog(UserProfile profile) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password: ${profile.fullName}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              hintText: 'Minimum 6 characters',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _updateUserPassword(profile.id, passwordController.text.trim());
              }
            },
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  void _showAssignStoreDialog(UserProfile profile) async {
    final supabase = Supabase.instance.client;
    String? selectedStoreId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final List<Map<String, dynamic>> stores = List<Map<String, dynamic>>.from(
          await supabase.from('stores').select('id, name').order('name')
      );

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text('Assign Store: ${profile.fullName}'),
                  content: stores.isEmpty
                      ? const Text("No stores available.")
                      : DropdownButtonFormField<String>(
                    value: selectedStoreId,
                    decoration: const InputDecoration(labelText: 'Select Store', border: OutlineInputBorder()),
                    items: stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']))).toList(),
                    onChanged: (val) => setDialogState(() => selectedStoreId = val),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: selectedStoreId == null ? null : () async {
                        Navigator.pop(dialogContext);
                        await _updateStaffAssignment(profile.id, selectedStoreId!);
                      },
                      child: const Text('Assign'),
                    ),
                  ],
                );
              }
          );
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showAddEmployeeDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'cashier';
    bool isPasswordVisible = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Employee'),
              scrollable: true,
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setDialogState(() => isPasswordVisible = !isPasswordVisible),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: ['cashier', 'manager', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) { if (val != null) selectedRole = val; },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final success = await _createNewUser(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        password: passwordController.text,
                        role: selectedRole,
                      );
                      if (success && mounted) Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditRoleDialog(UserProfile profile) {
    String selectedRole = profile.role;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Role'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            items: ['cashier', 'manager', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (val) { if (val != null) selectedRole = val; },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await _updateUserRole(userId: profile.id, newRole: selectedRole);
                if (mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Update'),
            )
          ],
        );
      },
    );
  }

  void _deleteUser(UserProfile profile) {
    if (profile.id == Supabase.instance.client.auth.currentUser!.id) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${profile.fullName}?'),
        content: const Text('This will permanently remove the user and their profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _callDeleteUser(profile);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Employee Management")),
      body: FutureBuilder<List<UserProfile>>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final profiles = snapshot.data ?? [];
          if (profiles.isEmpty) return const Center(child: Text("No employees found."));

          return RefreshIndicator(
            onRefresh: () async => _refreshEmployeeList(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(profile.role.toUpperCase()),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') _showEditRoleDialog(profile);
                        if (val == 'assign') _showAssignStoreDialog(profile);
                        if (val == 'password') _showChangePasswordDialog(profile); // Added item
                        if (val == 'delete') _deleteUser(profile);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Role')])
                        ),
                        const PopupMenuItem(
                            value: 'assign',
                            child: Row(children: [Icon(Icons.store, size: 18), SizedBox(width: 8), Text('Assign Store')])
                        ),
                        const PopupMenuItem(
                            value: 'password',
                            child: Row(children: [Icon(Icons.lock_reset, size: 18), SizedBox(width: 8), Text('Change Password')])
                        ),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete User', style: TextStyle(color: Colors.red))])
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeDialog,
        label: const Text("Add Employee"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
