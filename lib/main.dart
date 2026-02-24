// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the page files you will create in your 'pages' folder
import 'pages/dashboard/home_page.dart';
import 'pages/auth/login_page.dart';

Future<void> main() async {
  // Ensure that Flutter bindings are initialized before running any other code.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase using the credentials you provided.
  await Supabase.initialize(
    url: 'https://isshdvprjdwtvcxgjldl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzc2hkdnByamR3dHZjeGdqbGRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MTAxNTUsImV4cCI6MjA4MDI4NjE1NX0.XBCjtRi9tRr571En8g5JWyyc2v_Ve72RPrJf8UWY3mU',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jumong Admin Dashboard',
      // A professional dark theme for your admin panel
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1F2937),
        cardColor: const Color(0xFF374151),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal, // Button color
            foregroundColor: Colors.white, // Text on button color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      // This StreamBuilder is the core of your app's navigation.
      // It acts as a guard, showing the correct page based on login state.
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // While waiting for the connection, show a loading circle.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Check if the snapshot has data and a user session exists.
          if (snapshot.hasData && snapshot.data?.session != null) {
            // USER IS LOGGED IN: Show the main dashboard.
            return const HomePage();
          } else {
            // USER IS NOT LOGGED IN: Show the login screen.
            return const LoginPage();
          }
        },
      ),
    );
  }
}
