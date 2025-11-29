import 'package:flutter/material.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:kiddo_tracker/services/workmanager_callback.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/pages/mainscreen.dart';
import 'package:kiddo_tracker/pages/loginscreen.dart';
import 'package:kiddo_tracker/pages/pinscreen.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize AndroidAlarmManager
  await AndroidAlarmManager.initialize();
  // Initialize notifications
  await NotificationService.initialize();
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
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late Future<String> _authState;

  Future<String> _getAuthState() async {
    // final isLoggedIn = await SharedPreferenceHelper.getUserLoggedIn();
    // if (isLoggedIn != true) {
    //   return 'login';
    // }

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
        if (data[0]['result'] == 'ok') {
          // Session is valid, now check userLoggedIn
          final isLoggedIn = await SharedPreferenceHelper.getUserLoggedIn();
          print('isLoggedIn: $isLoggedIn');
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
          return 'pin';
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
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.generateRoute,
      home: FutureBuilder<String>(
        future: _authState,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            final state = snapshot.data!;
            if (state == 'main') {
              print('User is logged in and session active');
              return const MainScreen();
              // return const MainScreen(); // User is logged in and session active
            } else if (state == 'pin') {
              // Get mobile number for PIN screen
              return FutureBuilder<String?>(
                future: SharedPreferenceHelper.getUserNumber(),
                builder: (context, mobileSnapshot) {
                  if (mobileSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  } else {
                    return PINScreen(); // Session expired, show PIN
                  }
                },
              );
            } else {
              return const LoginScreen(); // User is not logged in
            }
          } else {
            return const LoginScreen(); // Default to login
          }
        },
      ),
    );
  }
}
