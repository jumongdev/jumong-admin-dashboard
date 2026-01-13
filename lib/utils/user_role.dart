// lib/utils/user_role.dart

import 'package:flutter/foundation.dart';      // <-- 1. ADD THIS IMPORT
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches both the role and full name for the current user from the 'profiles' table.
/// Returns a Map with 'role' and 'name'.
Future<Map<String, String>> getUserProfileData() async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;

  // Default values for a user who is not logged in or has no profile.
  final defaultProfile = {'role': 'anonymous', 'name': 'Guest'};

  if (currentUser == null) {
    return defaultProfile;
  }

  try {
    // Fetch both columns in a single request for efficiency.
    final response = await supabase
        .from('profiles')
        .select('user_role, full_name')
        .eq('id', currentUser.id)
        .single();

    // Safely extract the data from the response.
    final role = response['user_role'] as String? ?? 'authenticated';
    final name = response['full_name'] as String? ?? 'No Name';

    return {'role': role, 'name': name};

  } catch (e) {
    // --- 2. REPLACE 'print' WITH 'debugPrint' ---
    debugPrint('--- Error fetching user profile data: $e ---');

    // If there's an error (e.g., profile doesn't exist), return safe defaults.
    return {'role': 'authenticated', 'name': currentUser.email ?? 'No Name'};
  }
}
