// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';      // For Timer
import 'dart:convert';     // For jsonEncode

import 'package:geolocator/geolocator.dart';        // For location
import 'package:http/http.dart' as http;           // For HTTP requests
import 'package:jungle_clock_app/database_helper.dart'; // *** ADJUST PATH/PACKAGE NAME IF NEEDED ***
import 'main.dart';                                // For LoginPage access

// --- Constants ---
// V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V V
// >>> IMPORTANT: REPLACE THIS URL WITH YOUR ACTUAL API ENDPOINT <<<
const String API_ENDPOINT_URL = "https://api.jungleclock.com/sync-coordinates";
// ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^

// Enum to represent the different states of the timer
enum TimerState { stopped, running, paused }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- State Variables ---
  Timer? _timer;
  Timer? _saveDataTimer;
  Timer? _syncApiTimer;
  Duration _elapsedTime = Duration.zero;
  final Duration _saveInterval = const Duration(seconds: 2);
  final Duration _syncIntervalApi = const Duration(seconds: 21);
  TimerState _timerState = TimerState.stopped;
  bool _locationPermissionGranted = false;
  bool _isSyncing = false;
  String? apiKey;
  int? employeeId;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      _requestLocationPermission();
      _startApiSyncTimer();
    });
  }
  @override
  void dispose() {
    _timer?.cancel();
    _saveDataTimer?.cancel();
    _syncApiTimer?.cancel();
    super.dispose();
  }

  // --- Initialization and Permissions ---
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      apiKey = prefs.getString('api_key');
      employeeId = prefs.getInt('employee_id');
      print("User data loaded: Employee ID: $employeeId, API Key loaded: ${apiKey != null}");
    });
  }
  Future<void> _requestLocationPermission() async {
    // (Permission logic remains the same)
    bool serviceEnabled; LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { print('Location services are disabled.'); if (mounted) { setState(() => _locationPermissionGranted = false); _showEnableLocationServicesDialog(); } return; }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) { print('Location permissions were denied.'); if (mounted) setState(() => _locationPermissionGranted = false); _showPermissionRequiredDialog(isPermanentlyDenied: false); return; }
    }
    if (permission == LocationPermission.deniedForever) { print('Location permissions are permanently denied.'); if (mounted) { setState(() => _locationPermissionGranted = false); _showPermissionRequiredDialog(isPermanentlyDenied: true); } return; }
    print('Location permissions granted.'); if (mounted) setState(() => _locationPermissionGranted = true);
  }

  // --- Data Saving Logic (Location to Local DB) ---
  // (No changes here)
  void _startPeriodicDataSave() { if (_timerState == TimerState.running && _locationPermissionGranted && employeeId != null) { print('Starting periodic data saving (Interval: ${_saveInterval.inMinutes} mins)...'); _saveDataTimer?.cancel(); _saveLocationData(); _saveDataTimer = Timer.periodic(_saveInterval, _saveLocationData); } else { print('Conditions not met for starting local data save: State=$_timerState, Permission=$_locationPermissionGranted, EmployeeID=$employeeId'); if (!_locationPermissionGranted && mounted) { _requestLocationPermission(); } } }
  void _stopPeriodicDataSave() { if (_saveDataTimer != null && _saveDataTimer!.isActive) { print('Stopping periodic data saving.'); _saveDataTimer?.cancel(); _saveDataTimer = null; } }
  Future<void> _saveLocationData([Timer? timer]) async { if (_timerState != TimerState.running || !_locationPermissionGranted || employeeId == null || !mounted) { print('Skipping local data save. State: $_timerState, Permission: $_locationPermissionGranted, EmployeeID: $employeeId, Mounted: $mounted'); if (_timerState != TimerState.running) { _stopPeriodicDataSave(); } return; } print('Attempting to save location data locally (callback triggered)...'); try { Position position = await Geolocator.getCurrentPosition( desiredAccuracy: LocationAccuracy.high ); String timestamp = DateTime.now().toIso8601String(); print('Saving record locally - EmployeeID: $employeeId, Lat: ${position.latitude}, Lng: ${position.longitude}, Time: $timestamp'); await _dbHelper.insertLocationRecord( employeeId: employeeId!, latitude: position.latitude, longitude: position.longitude, timestamp: timestamp, ); } catch (e) { print('Error getting location or saving data locally: $e'); if (e is LocationServiceDisabledException) { print("Location services were disabled while saving."); if (mounted) { setState(() => _locationPermissionGranted = false); _stopPeriodicDataSave(); _showEnableLocationServicesDialog(); } } } }

  // --- API Synchronization Logic ---
  // (No changes here, sync still runs on its own timer if conditions met)
  void _startApiSyncTimer() { print('Starting API sync timer (Interval: ${_syncIntervalApi.inMinutes} mins)...'); _syncApiTimer?.cancel(); _syncApiTimer = Timer.periodic(_syncIntervalApi, (timer) { if (_timerState != TimerState.running) { print("API Sync skipped: UI Timer is not in 'running' state (Current state: $_timerState)."); return; } if (!_isSyncing) { _syncDataToApi(); } else { print("API Sync skipped: Previous sync operation still in progress."); } }); }
  void _stopApiSyncTimer() { if (_syncApiTimer != null && _syncApiTimer!.isActive) { print('Stopping API sync timer.'); _syncApiTimer?.cancel(); _syncApiTimer = null; } }
  Future<void> _syncDataToApi() async { if (_isSyncing) { print("Sync already in progress. Aborting."); return; } if (!mounted) { print("Sync aborted: Widget not mounted."); return; } if (employeeId == null || apiKey == null) { print("Sync aborted: Missing Employee ID or API Key."); return; } setState(() { _isSyncing = true; }); print('Starting data sync to API...'); List<Map<String, dynamic>> localRecords = []; try { localRecords = await _dbHelper.queryAllRecords(); if (localRecords.isEmpty) { print('No local records found to sync.'); setState(() { _isSyncing = false; }); return; } print('Found ${localRecords.length} records to sync.'); List<Map<String, dynamic>> coordinatesPayload = localRecords.map((record) { return { 'latitude': record[DatabaseHelper.colLatitude], 'longitude': record[DatabaseHelper.colLongitude], 'timestamp': record[DatabaseHelper.colTimestamp], }; }).toList(); Map<String, dynamic> apiPayload = { 'employee_id': employeeId, 'coordinates': coordinatesPayload, }; print('Sending payload to $API_ENDPOINT_URL'); final response = await http.post( Uri.parse(API_ENDPOINT_URL), headers: { 'Content-Type': 'application/json; charset=UTF-8', 'Authorization': apiKey!, }, body: jsonEncode(apiPayload), ).timeout(const Duration(seconds: 90)); print('API Response Status Code: ${response.statusCode}'); if (response.statusCode == 201 || response.statusCode == 200) { print('API sync successful.'); await _dbHelper.deleteAllRecords(); } else { print('API sync failed. Status: ${response.statusCode}, Body: ${response.body}'); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Failed to sync data (Server Error: ${response.statusCode}). Retrying later.'), backgroundColor: Colors.orange), ); } } } catch (e) { print('Error during API sync process: $e'); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Sync error: ${e.toString().substring(0, 50)}... Check connection?'), backgroundColor: Colors.red), ); } } finally { if (mounted) { setState(() { _isSyncing = false; }); } else { _isSyncing = false; } print('API sync process finished.'); } }

  // --- UI Timer Control Functions ---
  // (No changes needed here)
  void _startTimer() { if (_timerState == TimerState.stopped) { if (!_locationPermissionGranted) { _showPermissionRequiredDialog(); _requestLocationPermission(); return; } if (employeeId == null) { print("Cannot start timer: Employee ID null."); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Employee ID not available.'))); return; } _elapsedTime = Duration.zero; _timer = Timer.periodic(const Duration(seconds: 1), _tick); if (mounted) { setState(() { _timerState = TimerState.running; }); } _startPeriodicDataSave(); } }
  void _pauseTimer() { if (_timerState == TimerState.running) { _timer?.cancel(); _stopPeriodicDataSave(); if (mounted) { setState(() { _timerState = TimerState.paused; }); } } }
  void _resumeTimer() { if (_timerState == TimerState.paused) { if (!_locationPermissionGranted) { _showPermissionRequiredDialog(); _requestLocationPermission(); return; } if (employeeId == null) { print("Cannot resume timer: Employee ID null."); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Employee ID not available.'))); return; } _timer = Timer.periodic(const Duration(seconds: 1), _tick); if (mounted) { setState(() { _timerState = TimerState.running; }); } _startPeriodicDataSave(); } }

  // --- Stop & Logout Actions ---

  // ***** MODIFICATION HERE *****
  // Added async and the call to deleteAllRecords
  Future<void> _performStopAction() async { // Made async
    if (_timerState == TimerState.running || _timerState == TimerState.paused) {
      _timer?.cancel();
      _stopPeriodicDataSave();
      print('UI Timer stopped. Final displayed time: ${_formatDuration(_elapsedTime)}');

      // --- ADDED DATABASE CLEARING LOGIC ---
      try {
        print("Clearing local database records due to timer stop.");
        await _dbHelper.deleteAllRecords(); // Clear the DB table
        print("Local database records cleared successfully.");
      } catch (e) {
        print("Error clearing local database on stop: $e");
        // Optionally show a message if clearing fails, though unlikely
      }
      // -------------------------------------

      // Reset state (needs to happen after potential await)
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
  // ***** END OF MODIFICATION *****

  Future<void> _performLogoutAction() async {
    // Call the (now async) stop action first
    await _performStopAction(); // Use await as it's now async
    _timer?.cancel();
    _saveDataTimer?.cancel();
    _stopApiSyncTimer();

    // Logout logic (clearing prefs, navigation) remains the same
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
    await prefs.remove('employee_id');
    print("Credentials cleared.");
    if (!mounted) return;
    Navigator.pushAndRemoveUntil( context, MaterialPageRoute(builder: (context) => const LoginPage()), (Route<dynamic> route) => false, );
  }

  // --- Confirmation Dialogs & Permission Dialogs ---
  // (No changes needed here)
  Future<void> _showStopConfirmationDialog() async { if (_timerState == TimerState.stopped || !mounted) return; final bool? confirmed = await showDialog<bool>( context: context, barrierDismissible: false, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirm Stop'), content: const Text('Are you sure you want to stop the timer? All locally saved location data for this session will be cleared.'), actions: <Widget>[ TextButton( child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false), ), TextButton( child: Text('Stop & Clear Data', style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.of(context).pop(true), ), ], ); }, ); if (confirmed == true && mounted) { await _performStopAction(); /* Use await here */ } } // Update Dialog Text
  Future<void> _showLogoutConfirmationDialog() async { if (!mounted) return; final bool? confirmed = await showDialog<bool>( context: context, barrierDismissible: false, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirm Logout'), content: const Text('Are you sure you want to log out? Any running timer will be stopped and local data cleared.'), actions: <Widget>[ TextButton( child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false), ), TextButton( child: Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.of(context).pop(true), ), ], ); }, ); if (confirmed == true && mounted) { await _performLogoutAction(); } } // Update Dialog Text
  Future<void> _showPermissionRequiredDialog({bool isPermanentlyDenied = false}) async { if (!mounted) return; await showDialog( context: context, barrierDismissible: false, builder: (context) => AlertDialog( title: const Text('Location Permission Required'), content: Text(isPermanentlyDenied ? 'Location tracking permission is permanently denied...' : 'This app needs location permission...'), actions: [ if (isPermanentlyDenied || !isPermanentlyDenied) TextButton( child: const Text('Open App Settings'), onPressed: () async { Navigator.of(context).pop(); await Geolocator.openAppSettings(); }, ), TextButton( child: const Text('OK'), onPressed: () => Navigator.of(context).pop(), ), ], ), ); }
  Future<void> _showEnableLocationServicesDialog() async { if (!mounted) return; await showDialog( context: context, barrierDismissible: false, builder: (context) => AlertDialog( title: const Text('Enable Location Services'), content: const Text('Location services seem to be disabled...'), actions: [ TextButton( child: const Text('Open Location Settings'), onPressed: () async { Navigator.of(context).pop(); await Geolocator.openLocationSettings(); }, ), TextButton( child: const Text('OK'), onPressed: () => Navigator.of(context).pop(), ), ], ), ); _requestLocationPermission(); }

  // --- Helper Functions ---
  // (No changes needed here)
  void _tick(Timer timer) { if (!mounted) { timer.cancel(); return; } setState(() { _elapsedTime += const Duration(seconds: 1); }); }
  String _formatDuration(Duration duration) { String twoDigits(int n) => n.toString().padLeft(2, '0'); final hours = twoDigits(duration.inHours); final minutes = twoDigits(duration.inMinutes.remainder(60)); final seconds = twoDigits(duration.inSeconds.remainder(60)); return "$hours:$minutes:$seconds"; }

  // --- Build Method ---
  // (No changes needed here)
  @override
  Widget build(BuildContext context) { const Color primaryColor = Color(0xFFE53935); const Color accentColor = Color(0xFFFFA000); final Color stopColor = Theme.of(context).colorScheme.error; return Scaffold( appBar: AppBar( backgroundColor: primaryColor, foregroundColor: Colors.white, title: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text('JungleClock Home'), if (_isSyncing) const SizedBox( height: 20, width: 20, child: CircularProgressIndicator( valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2.0, ) ), ], ), actions: [ IconButton( icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _showLogoutConfirmationDialog, ), ], automaticallyImplyLeading: false, ), body: Center( child: Padding( padding: const EdgeInsets.all(30.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Text( _formatDuration(_elapsedTime), style: const TextStyle( fontSize: 64, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 2.0,), ), const SizedBox(height: 60), _buildActionButtons(primaryColor, accentColor, stopColor), ], ), ), ), ); }
  Widget _buildActionButtons(Color startColor, Color pauseResumeColor, Color stopColor) { final ButtonStyle buttonStyle = ElevatedButton.styleFrom( foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 3, ); switch (_timerState) { case TimerState.stopped: return ElevatedButton.icon( icon: const Icon(Icons.play_arrow), label: const Text('Start'), onPressed: _startTimer, style: buttonStyle.copyWith( backgroundColor: MaterialStateProperty.all(startColor), ), ); case TimerState.running: return Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ ElevatedButton.icon( icon: const Icon(Icons.pause), label: const Text('Pause'), onPressed: _pauseTimer, style: buttonStyle.copyWith( backgroundColor: MaterialStateProperty.all(pauseResumeColor), ), ), ElevatedButton.icon( icon: const Icon(Icons.stop), label: const Text('Stop'), onPressed: _showStopConfirmationDialog, style: buttonStyle.copyWith( backgroundColor: MaterialStateProperty.all(stopColor), ), ), ], ); case TimerState.paused: return Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ ElevatedButton.icon( icon: const Icon(Icons.play_arrow), label: const Text('Resume'), onPressed: _resumeTimer, style: buttonStyle.copyWith( backgroundColor: MaterialStateProperty.all(pauseResumeColor), ), ), ElevatedButton.icon( icon: const Icon(Icons.stop), label: const Text('Stop'), onPressed: _showStopConfirmationDialog, style: buttonStyle.copyWith( backgroundColor: MaterialStateProperty.all(stopColor), ), ), ], ); } }

} // End of _HomePageState class