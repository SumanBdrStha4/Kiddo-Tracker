import 'package:flutter/material.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/services/theme_provider.dart';
import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:kiddo_tracker/services/workmanager_callback.dart';
import 'package:kiddo_tracker/services/background_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<void> _initializeApp() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await BackgroundService.initialize();
  await AndroidAlarmManager.initialize();
  await NotificationService.initialize();

  // Initialize WorkManager
  Workmanager().initialize(workmanagerDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    "reset_daily_alarm",
    "reset_daily_alarm",
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  // Load environment variables
  try {
    await dotenv.load();
    print('Environment variables loaded successfully');
  } catch (e) {
    print('Error loading .env file: $e');
    print(
      'Please ensure .env file exists in the project root with required variables',
    );
  }

  // Initialize Google Maps
  AndroidGoogleMapsFlutter.useAndroidViewSurface = false;
}

void main() async {
  await _initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChildrenProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
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

  Future<dynamic?> _checkSession() async {
    final userId = await SharedPreferenceHelper.getUserNumber();
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    if (userId == null || sessionId == null) return null;

    try {
      final response = await ApiService.fetchUserStudentList(userId, sessionId);
      final data = response.data;
      //[{result: error}, {data: Access Denied!}]
      print('Session check response: $data');
      return data;
    } catch (e) {
      print('Session check failed: $e');
      return null;
    }
  }

  Future<void> _updateChildTags(List<dynamic> studentData) async {
    for (var student in studentData) {
      final studentId = student['student_id'];
      final tagId = student['tag_id'];
      if (studentId != null && tagId != null) {
        final databasesPath = await getDatabasesPath();
        final dbPath = '$databasesPath/kiddo_tracker.db';
        final dbExists = await databaseExists(dbPath);
        if (dbExists) {
          final db = await openDatabase(dbPath);
          final existingChild = await db.query(
            'child',
            where: 'student_id = ?',
            whereArgs: [studentId],
          );
          if (existingChild.isNotEmpty) {
            await db.update(
              'child',
              {'tag_id': tagId},
              where: 'student_id = ?',
              whereArgs: [studentId],
            );
          }
          await db.close();
        }
      }
    }
  }

  Future<String> _determineInitialRoute(
    bool isLoggedIn,
    bool sessionValid,
  ) async {
    if (sessionValid) {
      return isLoggedIn ? 'main' : 'login';
    } else {
      return isLoggedIn ? 'pin' : 'login';
    }
  }

  Future<String> _getAuthState() async {
    final sessionData = await _checkSession();
    if (sessionData == null) return 'login';

    final isLoggedIn = await SharedPreferenceHelper.getUserLoggedIn() ?? false;
    print('isLoggedIn: $isLoggedIn');

    late final bool sessionValid;
    if (sessionData is String) {
      sessionValid = false;
    } else {
      sessionValid = sessionData[0]['result'] == 'ok';
      if (sessionValid) {
        await _updateChildTags(sessionData[1]['data'] as List<dynamic>);
        print('Session valid and user logged in');
      }
    }

    return _determineInitialRoute(isLoggedIn, sessionValid);
  }

  @override
  void initState() {
    super.initState();
    _authState = _getAuthState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          // showPerformanceOverlay: true,
          theme: ThemeData.light().copyWith(
            textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
          ),
          darkTheme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
          ),
          themeMode: themeProvider.themeMode,
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
      },
    );
  }
}
