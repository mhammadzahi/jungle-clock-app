// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Import async library for Timer
import 'main.dart';   // Import main.dart to access LoginPage

// Enum to represent the different states of the timer
enum TimerState { stopped, running, paused }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Timer state variables
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  TimerState _timerState = TimerState.stopped; // Initial state is stopped

  // User data (optional, loaded but not displayed)
  String? apiKey;
  int? employeeId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Ensure timer is cancelled when the widget is disposed
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      apiKey = prefs.getString('api_key');
      employeeId = prefs.getInt('employee_id');
    });
  }

  // --- Timer Control Functions ---

  void _startTimer() {
    if (_timerState == TimerState.stopped) {
      _elapsedTime = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      setState(() {
        _timerState = TimerState.running;
      });
    }
  }

  void _pauseTimer() {
    if (_timerState == TimerState.running) {
      _timer?.cancel();
      setState(() {
        _timerState = TimerState.paused;
      });
    }
  }

  void _resumeTimer() {
    if (_timerState == TimerState.paused) {
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      setState(() {
        _timerState = TimerState.running;
      });
    }
  }

  void _performStopAction() {
    if (_timerState == TimerState.running || _timerState == TimerState.paused) {
      _timer?.cancel();
      print('Timer stopped. Final time: ${_formatDuration(_elapsedTime)}');
      if (mounted) {
        setState(() {
          _elapsedTime = Duration.zero;
          _timerState = TimerState.stopped;
        });
      } else {
        _elapsedTime = Duration.zero;
        _timerState = TimerState.stopped;
      }
    }
  }

  Future<void> _showStopConfirmationDialog() async {
    if (_timerState == TimerState.stopped || !mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Stop'),
          content: const Text('Are you sure you want to stop the timer? The current time will be reset.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Stop', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      _performStopAction();
    }
  }

  void _tick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    setState(() {
      _elapsedTime += const Duration(seconds: 1);
    });
  }

  // --- Helper & Logout ---

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // RENAMED: This function now contains the actual logout logic.
  Future<void> _performLogoutAction() async {
    // Ensure timer is fully stopped and reset before logging out
    _performStopAction(); // Stop timer cleanly
    _timer?.cancel();     // Extra safety cancel

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
    await prefs.remove('employee_id');

    // Check mounted *before* navigation
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  // NEW: Function to show the logout confirmation dialog
  Future<void> _showLogoutConfirmationDialog() async {
    if (!mounted) return; // Check mounted at the beginning

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must choose an action
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out? Any running timer will be stopped.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false
              },
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.error)), // Use error color for emphasis
              onPressed: () {
                Navigator.of(context).pop(true); // Return true
              },
            ),
          ],
        );
      },
    );

    // If the dialog returned true (Logout confirmed), perform the logout action
    // Check mounted again for safety after async gap
    if (confirmed == true && mounted) {
      await _performLogoutAction();
    }
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFE53935);
    const Color accentColor = Color(0xFFFFA000);
    final Color stopColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('JungleClock Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            // MODIFIED: Call the logout confirmation dialog
            onPressed: _showLogoutConfirmationDialog,
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatDuration(_elapsedTime),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 60),
              _buildActionButtons(primaryColor, accentColor, stopColor),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build the buttons based on state (Unchanged from previous version)
  Widget _buildActionButtons(Color startColor, Color pauseResumeColor, Color stopColor) {
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 3,
    );

    switch (_timerState) {
      case TimerState.stopped:
        return ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
          onPressed: _startTimer,
          style: buttonStyle.copyWith(
            backgroundColor: MaterialStateProperty.all(startColor),
          ),
        );
      case TimerState.running:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              onPressed: _pauseTimer,
              style: buttonStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(pauseResumeColor),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              onPressed: _showStopConfirmationDialog,
              style: buttonStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(stopColor),
              ),
            ),
          ],
        );
      case TimerState.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
              onPressed: _resumeTimer,
              style: buttonStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(pauseResumeColor),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              onPressed: _showStopConfirmationDialog,
              style: buttonStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(stopColor),
              ),
            ),
          ],
        );
    }
  }
}