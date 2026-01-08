import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/services/children_provider.dart';

import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:kiddo_tracker/services/workmanager_callback.dart';
import 'package:kiddo_tracker/services/background_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Helper function to get subscribed topics from shared preferences
Future<List<String>> _getSubscribedTopics() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('subscribed_topics') ?? [];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  rendering.debugRepaintRainbowEnabled = true;
  // Initialize background service
  await BackgroundService.initialize();
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

  // Initialize Google Maps for Android
  AndroidGoogleMapsFlutter.useAndroidViewSurface = false;

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

        //[{result: ok}, {data: [{student_id: OD57164911, name: Son 010, nickname: 010, school: IIT, class: 1, rollno: 5, age: 8, gender: Male, tag_id: 5B:DF:DE:71:5A:BB, route_info:
        if (data[0]['result'] == 'ok') {
          // update the child tag_id in local db
          final studentData = data[1]['data'] as List<dynamic>;
          for (var student in studentData) {
            final studentId = student['student_id'];
            final tagId = student['tag_id'];
            //update the sqflite database child's tag_id
            if (studentId != null && tagId != null) {
              // Check sqflite Db exists or not
              final databasesPath = await getDatabasesPath();
              final dbPath = '$databasesPath/kiddo_tracker.db';
              final dbExists = await databaseExists(dbPath);
              if (dbExists) {
                final db = await openDatabase(dbPath);
                // first check if child exists
                final List<Map<String, dynamic>> existingChild = await db.query(
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
      // showPerformanceOverlay: true,
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
