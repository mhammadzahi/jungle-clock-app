// main.dart
import 'dart:ui' as ui;
import 'dart:convert'; // For jsonEncode and jsonDecode
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For making HTTP requests
import 'package:shared_preferences/shared_preferences.dart'; // To store the API key
import 'home_page.dart'; // Import the home page file

// Make main async to await SharedPreferences
Future<void> main() async {
  // --- ADD THIS: Ensure Flutter bindings are initialized before using plugins ---
  WidgetsFlutterBinding.ensureInitialized();

  // --- ADD THIS: Check for stored API key ---
  final prefs = await SharedPreferences.getInstance();
  final String? apiKey = prefs.getString('api_key');

  // --- ADD THIS: Determine the initial page based on the API key ---
  // Check if apiKey is not null AND not empty
  final bool isLoggedIn = apiKey != null && apiKey.isNotEmpty;
  final Widget initialPage = isLoggedIn ? const HomePage() : const LoginPage();

  // Pass the determined initial page to the app
  runApp(JungleClockApp(initialHome: initialPage));
}

class JungleClockApp extends StatelessWidget {
  // --- ADD THIS: Accept the initial widget ---
  final Widget initialHome;

  const JungleClockApp({super.key, required this.initialHome}); // Modified constructor

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jungle Clock',
      theme: ThemeData(
          primarySwatch: Colors.red, // Use red as a base
          scaffoldBackgroundColor: Colors.white, // Default background
          // fontFamily: 'YourCustomFont', // Find font if needed
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: Color(0xFFE53935)), // Red focus border
            ),
            errorBorder: OutlineInputBorder( // Add error border style
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder( // Add focused error border style
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
              borderSide: BorderSide(color: Colors.redAccent, width: 2.0),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935), // Button red
              foregroundColor: Colors.white, // Button text color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE53935), // Link red
              )
          )
      ),
      // --- CHANGE THIS: Use the passed initialHome widget ---
      home: initialHome,
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Login Page Implementation (Keep as is) ---

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Global key to identify the Form and trigger validation
  final _formKey = GlobalKey<FormState>();

  // Controllers to retrieve text field values
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State variable to track checkbox
  bool _agreeToPolicy = false;
  // State variable to track loading status
  bool _isLoading = false;

  // Define the primary red color from the image
  final Color _primaryColor = const Color(0xFFE53935); // A strong red
  // Define your API URL (MUST BE HTTPS for production/real devices)
  final String apiUrl = 'https://api.jungleclock.com'; // <-- Replace with your actual API URL

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use SingleChildScrollView to prevent overflow on smaller screens
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Header Section ---
            _buildHeader(),

            // --- Body/Form Section ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              // Wrap the form elements in a Form widget
              child: Form(
                key: _formKey, // Assign the key
                child: _buildFormFields(), // Use a separate method for form fields
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget for Header ---
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      color: _primaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo Placeholder (Replace with actual Image widget if you have the logo)
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.apps, // Placeholder Icon resembling the shapes
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'JUNGLE CLOCK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'BE ON TIME',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 4.0, // Adjust for spacing
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widget for Form Fields ---
  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Align labels to the left
      children: [
        const Text(
          'Sign in to your account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 30),

        // --- Email Field ---
        const Text(
          'Email address',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'user@example.com',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email address';
            }
            if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 20),

        // --- Password Field ---
        const Text(
          'Password',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: '**********',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 10),

        // --- Privacy Policy Checkbox ---
        Row(
          children: [
            Checkbox(
              value: _agreeToPolicy,
              onChanged: (bool? value) {
                setState(() {
                  _agreeToPolicy = value ?? false;
                });
              },
              activeColor: _primaryColor,
            ),
            Flexible(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('I agree to the '),
                  TextButton(
                    onPressed: () {
                      print('Privacy Policy Tapped!');
                      // You could show a dialog or navigate to a policy screen here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Navigate to Privacy Policy Screen (Not Implemented)')),
                      );
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: ui.Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),

        // --- Sign In Button ---
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            // Disable button while loading, call _signIn otherwise
            onPressed: _isLoading ? null : _signIn,
            child: _isLoading
                ? const SizedBox( // Show loading indicator
              height: 20.0,
              width: 20.0,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.0,
              ),
            )
                : const Text('Sign in'), // Show text
          ),
        ),
      ],
    );
  }

  // --- Sign In Logic ---
  Future<void> _signIn() async {
    // 1. Check if the Privacy Policy is agreed to
    if (!_agreeToPolicy) {
      // Ensure the widget is still mounted before showing SnackBar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Privacy Policy'),
          backgroundColor: Colors.orangeAccent, // Use a warning color
        ),
      );
      return; // Stop the sign-in process
    }

    // 2. Validate the form fields
    if (_formKey.currentState!.validate()) {
      // Form is valid, show loading indicator and proceed
      setState(() {
        _isLoading = true;
      });

      final String email = _emailController.text.trim();
      final String password = _passwordController.text;

      try {
        final response = await http.post(
          Uri.parse('$apiUrl/login'), // Use the defined API URL
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8', // Set content type header
          },
          body: jsonEncode(<String, String>{ // Encode the login data as JSON
            'email': email,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 10)); // Add a timeout

        // Check if the widget is still mounted after the async call
        if (!mounted) return;

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String? apiKey = responseData['api_key']; // Extract API key (make it nullable)
          final int? employee_id = responseData['employee_id'] as int?; // Ensure proper casting


          // Store the API key using SharedPreferences only if it's not null/empty
          if (apiKey != null && apiKey.isNotEmpty && employee_id != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('api_key', apiKey);
            await prefs.setInt('employee_id', employee_id);

            print('Login successful! API Key stored.');

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign in successful!'),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate to the HomePage and remove the LoginPage from the stack
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()), // Use the imported HomePage
            );
          } else {
            // Handle case where API returns success but no key (or empty key)
            print('Login technically successful, but API key was missing or empty.');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login failed: Invalid response from server.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }

        } else if (response.statusCode == 401) {
          // --- INVALID CREDENTIALS ---
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password.'),
              backgroundColor: Colors.redAccent, // Use an error color
            ),
          );
        } else {
          // --- OTHER SERVER ERROR ---
          print('Server Error: ${response.statusCode}');
          print('Response Body: ${response.body}'); // Log body for debugging
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An error occurred: ${response.statusCode}. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        // --- NETWORK OR OTHER ERROR (Timeout, DNS, etc.) ---
        print('Error during sign in: $e');
        // Check if mounted before showing SnackBar
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect. Check connection or try again later.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        // Ensure loading indicator is turned off, regardless of outcome
        // Check if mounted before calling setState
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

    } else {
      // Form validation failed (errors shown by TextFormFields)
      print('Form validation failed.');
    }
  }
}
