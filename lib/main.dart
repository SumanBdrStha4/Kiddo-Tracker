import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/services/mqtt_task_handler.dart';
import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:kiddo_tracker/services/workmanager_callback.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

// Helper function to get subscribed topics from shared preferences
Future<List<String>> _getSubscribedTopics() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('subscribed_topics') ?? [];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize AndroidAlarmManager
  await AndroidAlarmManager.initialize();
  // Initialize notifications
  await NotificationService.initialize();
  // Initialize port for communication between TaskHandler and UI.
  FlutterForegroundTask.initCommunicationPort();

  //workManager
  Workmanager().initialize(workmanagerDispatcher, isInDebugMode: false);
  // Runs once every 24 hours to reset the alarm
  Workmanager().registerPeriodicTask(
    "reset_daily_alarm",
    "reset_daily_alarm",
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
  );
  // Schedule daily data load
  // await scheduleDailyDataLoad(15, 36);
  //isInitialized the dotenv
  dotenv.isInitialized;
  // Load environment variables with error handling
  try {
    await dotenv.load();
    print('Environment variables loaded successfully');
  } catch (e) {
    print('Error loading .env file: $e');
    print(
      'Please ensure .env file exists in the project root with required variables',
    );
    // Continue with app startup even if .env loading fails
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ChildrenProvider())],
      child: const MainApp(),
    ),
  );

  // Start MQTT foreground task if user is logged in and has subscribed topics
  final isLoggedIn = await SharedPreferenceHelper.getUserLoggedIn();
  if (isLoggedIn == true) {
    final topics = await _getSubscribedTopics();
    if (topics.isNotEmpty) {
      await startMQTTForegroundTask(topics);
    }
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late Future<String> _authState;

  Future<String> _getAuthState() async {
    // First run API to check session
    final userId = await SharedPreferenceHelper.getUserNumber();
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    if (userId != null) {
      try {
        final response = await ApiService.fetchUserStudentList(
          userId,
          sessionId,
        );
        final data = response.data;
        print('Session check response: $data');
        final isLoggedIn = await SharedPreferenceHelper.getUserLoggedIn();
        print('isLoggedIn: $isLoggedIn');

        if (data[0]['result'] == 'ok') {
          // Session is valid, now check userLoggedIn
          if (isLoggedIn == true) {
            print('Session valid and user logged in');
            // Update expiry
            // final newExpiry = DateTime.now().add(const Duration(hours: 24));
            // await SharedPreferenceHelper.setSessionExpiry(newExpiry);
            return 'main';
          } else {
            return 'login';
          }
        } else {
          // Session expired
          if (isLoggedIn == true) {
            return 'pin';
          } else {
            return 'login';
          }
        }
      } catch (e) {
        // API call failed, assume expired
        return 'login';
      }
    } else {
      return 'login';
    }
  }

  @override
  void initState() {
    super.initState();
    _authState = _getAuthState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
      ),
      darkTheme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: FutureBuilder<String>(
        future: _authState,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            final state = snapshot.data!;
            String initialRoute;
            if (state == 'main') {
              print('User is logged in and session active');
              initialRoute = AppRoutes.main;
            } else if (state == 'pin') {
              initialRoute = AppRoutes.pin;
            } else {
              initialRoute = AppRoutes.login;
            }
            return Navigator(
              initialRoute: initialRoute,
              onGenerateRoute: AppRoutes.generateRoute,
            );
          } else {
            return Navigator(
              initialRoute: AppRoutes.login,
              onGenerateRoute: AppRoutes.generateRoute,
            );
          }
        },
      ),
    );
  }
}
