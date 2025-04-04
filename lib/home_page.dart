// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // <--- CORRECTED IMPORT: Import main.dart to access LoginPage

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? apiKey;
  bool _isLoadingKey = true; // Flag to track if API key is loading

  @override
  void initState() {
    super.initState();
    _loadApiKey(); // Load the key when the page loads
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    // Use mounted check in case widget is disposed before async operation completes
    if (!mounted) return;
    setState(() {
      apiKey = prefs.getString('api_key');
      _isLoadingKey = false; // Mark loading as complete
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key'); // Remove the key
    if (!mounted) return;
    // Navigate back to login screen (defined in main.dart) and remove all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      // Use the LoginPage class directly (it's available via the main.dart import)
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false, // Predicate to remove all routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Use the primary color from the theme if needed, or define one
        backgroundColor: const Color(0xFFE53935), // Example: Use the red color
        foregroundColor: Colors.white, // Make AppBar icons/text white
        title: const Text('Jungle Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout, // Call the logout function
          ),
        ],
        // No back arrow needed if we used pushReplacement or pushAndRemoveUntil
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding( // Added padding for better spacing
          padding: const EdgeInsets.all(20.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome! You are logged in.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center, // Center text if it wraps
                ),
                const SizedBox(height: 30),
                // Display the key (optional, for demonstration)
                // Show loading indicator while fetching the key
                _isLoadingKey
                    ? const CircularProgressIndicator()
                    : Text(
                  'Your API Key:\n${apiKey ?? "Not found"}', // Handle null case
                  textAlign: TextAlign.center, // Center text
                  style: const TextStyle(fontSize: 16),
                ),
              ]
          ),
        ),
      ),
    );
  }
}
