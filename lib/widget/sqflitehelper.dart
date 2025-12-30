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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
        pin TEXT,
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
        vehicle_id TEXT,
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

    //notifications table
    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        notice_id TEXT,
        type INTEGER,
        priority INTEGER,
        title TEXT,
        description TEXT,
        validity DATETIME,
        route_id TEXT,
        is_read INTEGER DEFAULT 0
      )
    ''');

    //absentDays table
    await db.execute('''
      CREATE TABLE absentDays(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT,
        tsp_id TEXT,
        start_date TEXT,
        end_date TEXT,
        reason TEXT,
        status INTEGER,
        applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create new table
    }
    if (oldVersion < 3) {}
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

  //return array of an object{tspid, oprid, routeid} child tsp_id with route_info's oprid and route_id
  Future<List<Map<String, dynamic>>> getChildTspId() async {
    final dbClient = await db;
    final results = await dbClient.query(
      'child',
      columns: ['tsp_id', 'route_info'],
    );
    List<Map<String, dynamic>> tspData = [];
    for (var e in results) {
      try {
        final tspIdRaw = e['tsp_id'] as String?;
        final routeInfoRaw = e['route_info'] as String?;

        if (tspIdRaw != null && routeInfoRaw != null) {
          final List<dynamic> tspList = jsonDecode(tspIdRaw);
          final List<dynamic> routeList = jsonDecode(routeInfoRaw);
          for (var tspId in tspList) {
            var tspRoutes = routeList
                .where(
                  (route) => route['route_id'].toString().startsWith(tspId),
                )
                .toList();

            tspData.add({'tsp_id': tspId, 'routes': tspRoutes});
          }
        }
      } catch (e) {
        Logger().e('Error parsing tsp_id or route_info: $e');
      }
    }
    return tspData;
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
        return routeInfos.map((route) => route.oprId.toString()).toList();
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

  //update only school_location and start_time in route_info of child base on tsp_id and route_id
  Future<void> updateChildRouteInfo(
    String studentId,
    String tspId,
    String routeId,
    String startTime,
    String schoolLocation,
  ) async {
    try {
      final dbClient = await db;
      // First, get the current child data
      final results = await dbClient.query(
        'child',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      if (results.isEmpty) {
        Logger().w('No child found with student_id: $studentId');
        return;
      }
      final childData = results.first;
      final tspIdRaw = childData['tsp_id'] as String?;
      final routeInfoRaw = childData['route_info'] as String?;
      if (tspIdRaw == null || routeInfoRaw == null) {
        Logger().w('tsp_id or route_info is null for student_id: $studentId');
        return;
      }
      // Check if tspId is in tsp_id list
      final List<dynamic> tspList = jsonDecode(tspIdRaw);
      if (!tspList.contains(tspId)) {
        Logger().w(
          'tspId $tspId not found in tsp_id for student_id: $studentId',
        );
        return;
      }
      // Decode route_info
      final List<dynamic> routeList = jsonDecode(routeInfoRaw);
      // Find and update the route
      bool updated = false;
      for (var route in routeList) {
        if (route['route_id'] == routeId) {
          route['start_time'] = startTime;
          route['school_location'] = schoolLocation;
          updated = true;
          break;
        }
      }
      if (!updated) {
        Logger().w('Route with route_id $routeId not found in route_info');
        return;
      }
      // Encode back to JSON
      final updatedRouteInfo = jsonEncode(routeList);
      // Update the database
      final affectedRows = await dbClient.update(
        'child',
        {'route_info': updatedRouteInfo},
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      if (affectedRows > 0) {
        Logger().i('Route info updated successfully.');
      } else {
        Logger().w('No rows were updated.');
      }
    } catch (e) {
      Logger().e('Error updating route info: $e');
    }
  }

  //update only stopage in route_info of child base on student_id and opr_id
  Future<void> updateChildRouteStopage(
    String childId,
    String routeId,
    Map<String, String> routeData,
  ) async {
    Logger().i(
      "update the stopages: $childId $routeId ${routeData.toString()}",
    );
    try {
      final dbClient = await db;
      // First, get the current child data
      final results = await dbClient.query(
        'child',
        where: 'student_id = ?',
        whereArgs: [childId],
      );
      if (results.isEmpty) {
        Logger().w('No child found with student_id: $childId');
        return;
      }
      final childData = results.first;
      final routeInfoRaw = childData['route_info'] as String?;
      Logger().i("sqlfite: $routeInfoRaw");
      if (routeInfoRaw == null) {
        Logger().w('route_info is null for student_id: $childId');
        return;
      }
      // Decode route_info
      final List<dynamic> routeList = jsonDecode(routeInfoRaw);
      // Find the old route and log details
      Map<String, dynamic>? oldRoute;
      for (var route in routeList) {
        if (route['route_id'] == routeId) {
          oldRoute = Map<String, dynamic>.from(route);
          Logger().i("Old route details: $oldRoute");
          break;
        }
      }
      // Find and update the route
      bool updated = false;
      for (var route in routeList) {
        if (route['route_id'] == routeId) {
          route['stop_id'] = routeData['stop_id'];
          route['stop_name'] = routeData['stop_name'];
          route['location'] = routeData['location'];
          route['stop_arrival_time'] = routeData['stop_arrival_time'];
          updated = true;
          break;
        }
      }
      if (updated) {
        // Find the updated route and log details
        Map<String, dynamic>? updatedRoute;
        for (var route in routeList) {
          if (route['route_id'] == routeId) {
            updatedRoute = Map<String, dynamic>.from(route);
            Logger().i("Updated route details: $updatedRoute");
            break;
          }
        }
      }
      if (!updated) {
        Logger().w('Route with route_id $routeId not found in route_info');
        return;
      }
      // Encode back to JSON
      final updatedRouteInfo = jsonEncode(routeList);
      // Update the database
      final affectedRows = await dbClient.update(
        'child',
        {'route_info': updatedRouteInfo},
        where: 'student_id = ?',
        whereArgs: [childId],
      );
      if (affectedRows > 0) {
        Logger().i('Route stopage updated successfully.');
        Logger().d('Stopage updated successfully in local database.');
      } else {
        Logger().w('No rows were updated.');
      }
    } catch (e) {
      Logger().e('Error updating route stopage: $e');
    }
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

  //absentDays insert
  Future<void> insertAbsentDay(
    String studentId,
    String startDate,
    String endDate,
    String tspId,
  ) async {
    final dbClient = await db;
    await dbClient.insert('absentDays', {
      'student_id': studentId,
      'start_date': startDate,
      'end_date': endDate,
      'tsp_id': tspId,
    });
  }

  //get absentDays by studentId
  Future<List<Map<String, dynamic>>> getAbsentDaysByStudentId(
    String studentId,
  ) async {
    final dbClient = await db;
    return await dbClient.query(
      'absentDays',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
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
      client.execute('DELETE FROM notifications;');
    });
  }

  //insert route
  Future<void> insertRoute(
    int oprid,
    String routeId,
    String timing,
    String vehicleId,
    String routeName,
    int type,
    String stopList,
    String stopDetails,
  ) async {
    try {
      final client = await db;
      await client.insert('routes', {
        'oprid': oprid,
        'route_id': routeId,
        'timing': timing,
        'vehicle_id': vehicleId,
        'route_name': routeName,
        'type': type,
        'stop_list': stopList,
        'stop_details': stopDetails,
      });
    } catch (e) {
      Logger().e('Error inserting route into DB: $e');
    }
  }

  //check if route exists by oprid and route_id
  Future<bool> routeExists(int oprid, String routeId) async {
    final dbClient = await db;
    final results = await dbClient.query(
      'routes',
      where: 'oprid = ? AND route_id = ?',
      whereArgs: [oprid, routeId],
    );
    return results.isNotEmpty;
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
  Future<Map<String, dynamic>> getStopDetailsByOprIdAndRouteId(
    String oprId,
    String routeId,
  ) async {
    final dbdata = await getStopListByOprIdAndRouteId(oprId, routeId);
    Logger().i(dbdata);
    //from dbdata get stop_list and selected
    if (dbdata.isNotEmpty) {
      final stopListStr = dbdata.first['stop_list'] as String?;
      return {'stopListStr': stopListStr};
    }
    return {'stopListStr': null};
  }

  //notification
  Future<void> insertNotification(Map<String, Object> map) async {
    final dbClient = await db;
    await dbClient.insert('notifications', map);
  }

  Future<List<Map<String, Object?>>> getNotifications() async {
    final dbClient = await db;
    return await dbClient.query(
      'notifications',
      orderBy: 'priority DESC, validity DESC',
    );
  }

  Future<int> updateNotificationIsRead(int id, int isRead) async {
    final dbClient = await db;
    return await dbClient.update(
      'notifications',
      {'is_read': isRead},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> getNotificationByNoticeId(String string) async {
    final dbClient = await db;
    final results = await dbClient.query(
      'notifications',
      where: 'notice_id = ?',
      whereArgs: [string],
    );
    return results.isNotEmpty;
  }

  Future<void> clearNotifications() async {
    final dbClient = await db;
    //clear the data from notifications table
    await dbClient.execute('DELETE FROM notifications;');
  }

  Future<int> getUnreadNotificationCount() async {
    final dbClient = await db;
    final result = await dbClient.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE is_read = 0;',
    );
    int count = Sqflite.firstIntValue(result) ?? 0;
    return count;
  }

  Future<void> updateRouteForStudent(
    String childId,
    RouteInfo updatedRoute,
  ) async {
    final dbClient = await db;
    // First, get the current child data
    final results = await dbClient.query(
      'child',
      where: 'student_id = ?',
      whereArgs: [childId],
    );
    if (results.isEmpty) {
      Logger().w('No child found with student_id: $childId');
      return;
    }
    final childData = results.first;
    final routeInfoRaw = childData['route_info'] as String?;
    if (routeInfoRaw == null) {
      Logger().w('route_info is null for student_id: $childId');
      return;
    }
    // Decode route_info
    final List<dynamic> routeList = jsonDecode(routeInfoRaw);
    // Find and update the route
    bool updated = false;
    for (var route in routeList) {
      if (route['route_id'] == updatedRoute.routeId) {
        route['start_time'] = updatedRoute.startTime;
        route['location'] = updatedRoute.stopLocation;
        route['stop_name'] = updatedRoute.stopName;
        route['stop_id'] = updatedRoute.stopId;
        updated = true;
        break;
      }
    }
    if (!updated) {
      Logger().w(
        'Route with route_id ${updatedRoute.routeId} not found in route_info',
      );
      return;
    }
    // Encode back to JSON
    final updatedRouteInfo = jsonEncode(routeList);
    // Update the database
    final affectedRows = await dbClient.update(
      'child',
      {'route_info': updatedRouteInfo},
      where: 'student_id = ?',
      whereArgs: [childId],
    );
    if (affectedRows > 0) {
      Logger().i('Route info updated successfully.');
    } else {
      Logger().w('No rows were updated.');
    }
  }
}
