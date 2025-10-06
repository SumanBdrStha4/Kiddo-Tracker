import 'dart:convert';
import 'package:kiddo_tracker/model/child.dart';
import 'package:kiddo_tracker/model/parent.dart';
import 'package:kiddo_tracker/model/route.dart';
import 'package:kiddo_tracker/model/subscribe.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqfliteHelper {
  static final SqfliteHelper _instance = SqfliteHelper._internal();
  factory SqfliteHelper() => _instance;
  SqfliteHelper._internal();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'kiddo_tracker.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade,
      readOnly: false,
    );
  }

  Future _onCreate(Database db, int version) async {
    //user table
    await db.execute('''
      CREATE TABLE user(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userid TEXT,
        name TEXT,
        city TEXT,
        state TEXT,
        address TEXT,
        contact TEXT,
        email TEXT,
        mobile TEXT,
        wards INTEGER,
        status INTEGER,
        sessionid TEXT
      )
    ''');

    //child of user table
    await db.execute('''
      CREATE TABLE child(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id TEXT,
      name TEXT,
      nickname TEXT,
      school TEXT,
      class_name TEXT,
      rollno TEXT,
      age INTEGER,
      gender TEXT,
      tag_id TEXT,
      route_info TEXT,
      tsp_id TEXT,
      status INTEGER,
      onboard_status INTEGER
      )
    ''');

    //routes table
    await db.execute('''
      CREATE TABLE routes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT,
        timing TEXT,
        oprid INTEGER,
        route_name TEXT,
        type INTEGER,
        stop_list TEXT,
        vehicle_id TEXT
        stop_details TEXT
      )
    ''');

    //set the message activity
    await db.execute('''
      CREATE TABLE activityStatus(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id TEXT,
      student_name TEXT,
      status TEXT,
      on_location TEXT,
      off_location TEXT,
      route_id TEXT,
      oprid TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    //studentSubscriptions table
    await db.execute('''
      CREATE TABLE studentSubscriptions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        plan_name TEXT,
        plan_details TEXT,
        validity INTEGER,
        price INTEGER,
        startdate TEXT,
        enddate TEXT,
        status INTEGER,
        userid TEXT
      )
    ''');
  }

  //activity CURD
  Future<int> insertActivity(Map<String, dynamic> activity) async {
    final dbClient = await db;
    return await dbClient.insert('activityStatus', activity);
  }

  Future<List<Map<String, dynamic>>> getActivities() async {
    final dbClient = await db;
    return await dbClient.query('activityStatus');
  }

  Future<Map<String, String>> getActivityTimesForRoute(
    String routeId,
    String oprid,
    String studentId,
  ) async {
    final dbClient = await db;
    final String today = DateTime.now().toIso8601String().split(
      'T',
    )[0]; // Get current date in YYYY-MM-DD format
    final List<Map<String, dynamic>> results = await dbClient.query(
      'activityStatus',
      where:
          'route_id = ? AND oprid = ? AND student_id = ? AND DATE(created_at) = ?',
      whereArgs: [routeId, oprid, studentId, today],
      orderBy: 'created_at ASC',
    );
    Logger().i(results);
    String onboardTime = '_';
    String offboardTime = '_';
    String onLocation = '_';
    String offLocation = '_';

    // Sort results by created_at descending to get the latest
    List<Map<String, dynamic>> sortedResults = List.from(results);
    sortedResults.sort((a, b) => b['created_at'].compareTo(a['created_at']));

    Map<String, dynamic>? latest = sortedResults.isNotEmpty
        ? sortedResults.first
        : null;

    if (latest != null) {
      // Check if the latest entry's status is 'onboarded'
      if (latest['status'] == 'onboarded') {
        onboardTime = latest['created_at'].toString();
        onLocation = latest['on_location'];
      }
      // Check if the latest entry's status is 'offboarded'
      else if (latest['status'] == 'offboarded') {
        offboardTime = latest['created_at'].toString();
        offLocation = latest['off_location'];
      }
    }

    return {
      'onboardTime': onboardTime,
      'offboardTime': offboardTime,
      'onLocation': onLocation,
      'offLocation': offLocation,
    };
  }

  // User CRUD
  Future<int> insertUser(Parent user) async {
    final dbClient = await db;
    return await dbClient.insert('user', user.toJson());
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final dbClient = await db;
    return await dbClient.query('user');
  }

  // Child CRUD
  Future<int> insertChild(Child child) async {
    final dbClient = await db;
    return await dbClient.insert('child', child.toJson());
  }

  Future<List<Map<String, dynamic>>> getChildren() async {
    final dbClient = await db;
    return await dbClient.query('child');
  }

  //update the child
  Future<int> updateChild(Child child) async {
    final dbClient = await db;
    return await dbClient.update(
      'child',
      child.toJson(),
      where: 'student_id = ?',
      whereArgs: [child.student_id],
    );
  }

  //delete the child
  Future<int> deleteChild(String studentId) async {
    final dbClient = await db;
    return await dbClient.delete(
      'child',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  //get child tsp_id in list
  Future<List<String>> getChildTspId() async {
    final dbClient = await db;
    final results = await dbClient.query(
      'child',
      columns: ['tsp_id'],
      distinct: true,
    );
    return results
        .map((e) => e['tsp_id'] as String)
        .where((element) => element.isNotEmpty)
        .toList();
  }

  //get route_info by student_id
  Future<String?> getRouteInfoByStudentId(String studentId) async {
    final dbClient = await db;
    final results = await dbClient.query(
      'child',
      columns: ['route_info'],
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    if (results.isNotEmpty) {
      return results.first['route_info'] as String?;
    }
    return null;
  }

  //update child status
  Future<int> updateChildStatus(String studentId, int status) async {
    final dbClient = await db;
    return await dbClient.update(
      'child',
      {'status': status},
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  //get all routes in String array oprid base on student_id from child table
  Future<List<String>> getAllRoutesByStudentId(String studentId) async {
    //if no data then it should be [] and if it has then ["", ""]
    //take the oprid from child's route_info
    final routeInfoStr = await getRouteInfoByStudentId(studentId);
    if (routeInfoStr == null || routeInfoStr.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(routeInfoStr);
      if (decoded is List) {
        final routeInfos = decoded
            .map<RouteInfo>(
              (e) => RouteInfo.fromJson(
                e is String ? jsonDecode(e) : e as Map<String, dynamic>,
              ),
            )
            .toList();
        return routeInfos.map((route) => route.oprId).toList();
      }
    } catch (e) {
      // If parsing fails, return empty list
      Logger().e(e);
    }
    return [];
  }

  // add route_info data to child base on student_id
  Future<int> updateRouteInfoByStudentId(
    String studentId,
    String routeInfo,
  ) async {
    final dbClient = await db;
    return await dbClient.update(
      'child',
      {'route_info': routeInfo},
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  //delete the single route from route_info of child base on student_id and opr_id
  Future<int> deleteRouteInfoByStudentIdAndOprId(
    String studentId,
    String oprId,
  ) async {
    final routeInfoStr = await getRouteInfoByStudentId(studentId);
    Logger().i(routeInfoStr);
    if (routeInfoStr == null || routeInfoStr.isEmpty) {
      return 0;
    }
    try {
      final decoded = jsonDecode(routeInfoStr);
      if (decoded is List) {
        List<RouteInfo> routeInfos = decoded
            .map<RouteInfo>(
              (e) => RouteInfo.fromJson(
                e is String ? jsonDecode(e) : e as Map<String, dynamic>,
              ),
            )
            .toList();
        // Remove the route with matching oprId
        routeInfos.removeWhere((route) => route.oprId == oprId);
        // Encode back to JSON string
        final updatedRouteInfoStr = jsonEncode(
          routeInfos.map((e) => e.toJson()).toList(),
        );
        // Update the child table
        return await updateRouteInfoByStudentId(studentId, updatedRouteInfoStr);
      }
    } catch (e) {
      Logger().e('Error deleting route info: $e');
      return 0;
    }
    return 0;
  }

  // Close the database
  Future close() async {
    final dbClient = await db;
    dbClient.close();
    _db = null;
  }

  // studentSubscriptions CRUD
  Future<int> insertStudentSubscription(SubscriptionPlan subscription) async {
    final dbClient = await db;
    return await dbClient.insert('studentSubscriptions', subscription.toJson());
  }

  Future<List<Map<String, dynamic>>> getStudentSubscriptions() async {
    final dbClient = await db;
    return await dbClient.query('studentSubscriptions');
  }

  Future<int> updateStudentSubscription(SubscriptionPlan subscription) async {
    final dbClient = await db;
    return await dbClient.update(
      'studentSubscriptions',
      subscription.toJson(),
      where: 'student_id = ?',
      whereArgs: [subscription.student_id],
    );
  }

  Future<int> deleteStudentSubscription(String studentId) async {
    final dbClient = await db;
    return await dbClient.delete(
      'studentSubscriptions',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  void clearAllData() async {
    //clear all data from the database
    await db.then((client) {
      client.execute('DELETE FROM user;');
      client.execute('DELETE FROM child;');
      client.execute('DELETE FROM activityStatus;');
      client.execute('DELETE FROM studentSubscriptions;');
      client.execute('DELETE FROM routes;');
    });
  }

  //insert route
  void insertRoute(item, item2, item3, item4, item5, item6, item7, item8) {
    //insert route into routes table
    db.then((client) {
      client.insert('routes', {
        'oprid': item,
        'route_id': item2,
        'timing': item3,
        'vehicle_id': item4,
        'route_name': item5,
        'type': item6,
        'stop_list': item7,
        'stop_details': item8,
      });
    });
  }

  //get all data from routes table
  // Future<List<Map<String, dynamic>>> getAllRoutes() async {
  //   final dbClient = await db;
  //   return await dbClient.query('routes');
  // }

  //get only stop_list from route base on oprid and route_id
  Future<List<Map<String, dynamic>>> getStopListByOprIdAndRouteId(
    String oprId,
    String routeId,
  ) async {
    final dbClient = await db;
    return await dbClient.query(
      'routes',
      columns: ['stop_list'],
      where: 'oprid = ? AND route_id = ?',
      whereArgs: [oprId, routeId],
    );
  }

  // get stop list name and location from route base on oprid and route_id
  Future<List<Map<String, dynamic>>> getStopDetailsByOprIdAndRouteId(
    String oprId,
    String routeId,
  ) async {
    final dbdata = getStopListByOprIdAndRouteId(oprId, routeId);
    Logger().i(dbdata);
    //from dbdata get stop_list and decode it
    return dbdata.then((value) {
      if (value.isNotEmpty) {
        final stopListStr = value.first['stop_list'] as String;
        final decoded = jsonDecode(stopListStr);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
      return [];
    });
  }
}
