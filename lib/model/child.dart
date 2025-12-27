import 'dart:convert';
import 'package:kiddo_tracker/model/route.dart';
import 'package:logger/logger.dart';

class Child {
  static final Logger logger = Logger();
  final String studentId;
  final String name;
  final String nickname;
  final String school;
  final String class_name;
  final String rollno;
  final int age;
  final String gender;
  final String tagId;
  final List<RouteInfo> routeInfo;
  final List<String> tsp_id;
  final int status;
  final int onboard_status;

  Child({
    required this.studentId,
    required this.name,
    required this.nickname,
    required this.school,
    required this.class_name,
    required this.rollno,
    required this.age,
    required this.gender,
    required this.tagId,
    required this.routeInfo,
    required this.tsp_id,
    required this.status,
    required this.onboard_status,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    List<RouteInfo> routes = [];
    if (json['route_info'] != null) {
      if (json['route_info'] is String) {
        try {
          var decoded = jsonDecode(json['route_info']);
          if (decoded is List) {
            routes = decoded
                .map<RouteInfo>(
                  (e) => RouteInfo.fromJson(
                    e is String ? jsonDecode(e) : e as Map<String, dynamic>,
                  ),
                )
                .toList();
          }
        } catch (e) {
          logger.e('Error decoding route_info string: $e');
        }
      } else if (json['route_info'] is List) {
        routes = (json['route_info'] as List)
            .map<RouteInfo>(
              (e) => RouteInfo.fromJson(
                e is String ? jsonDecode(e) : e as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    }

    logger.i(
      'Child.fromJson: route_info parsed - routes length: ${routes.length}, routes: $routes',
    );

    List<String> tspIds = [];
    if (json['tsp_id'] != null) {
      if (json['tsp_id'] is String) {
        try {
          var decoded = jsonDecode(json['tsp_id']);
          if (decoded is List) {
            tspIds = List<String>.from(decoded);
          }
        } catch (e) {
          logger.e('Error decoding tsp_id string: $e');
        }
      } else if (json['tsp_id'] is List) {
        tspIds = List<String>.from(json['tsp_id']);
      }
    }

    return Child(
      studentId: json['student_id'] ?? '',
      name: json['name'] ?? '',
      nickname: json['nickname'] ?? '',
      school: json['school'] ?? '',
      class_name: json['class_name']?.toString() ?? '',
      rollno: json['rollno']?.toString() ?? '',
      age: json['age'] is int
          ? json['age']
          : int.tryParse(json['age'].toString()) ?? 0,
      gender: json['gender'] ?? '',
      tagId: json['tag_id'] ?? '',
      routeInfo: routes,
      tsp_id: tspIds,
      status: json['status'] is int
          ? json['status']
          : int.tryParse(json['status'].toString()) ?? 0,
      onboard_status: json['onboard_status'] is int
          ? json['onboard_status']
          : int.tryParse(json['onboard_status'].toString()) ?? 0,
    );
  }

  get student_id => studentId;

  Map<String, dynamic> toJson() {
    final routeInfoJson = jsonEncode(routeInfo.map((e) => e.toJson()).toList());
    logger.i(
      'Child.toJson: route_info being saved - length: ${routeInfo.length}, json: $routeInfoJson',
    );
    return {
      'student_id': studentId,
      'name': name,
      'nickname': nickname,
      'school': school,
      'class_name': class_name,
      'rollno': rollno,
      'age': age,
      'gender': gender,
      'tag_id': tagId,
      'route_info': routeInfoJson,
      'tsp_id': jsonEncode(tsp_id.map((e) => e).toList()),
      'status': status,
      'onboard_status': onboard_status,
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
