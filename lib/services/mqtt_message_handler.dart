import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/services/notification_service.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';

/// Unified MQTT message handler for both background and foreground
class MQTTMessageHandler {
  static final Logger logger = Logger();

  /// Main entry point for handling MQTT messages
  static Future<void> handleMQTTMessage(
    String message,
    SqfliteHelper sqfliteHelper, {
    ChildrenProvider? provider,
    BuildContext? context,
  }) async {
    try {
      final Map<String, dynamic> jsonMessage = jsonDecode(message);
      final Map<String, dynamic> data =
          jsonMessage['data'] as Map<String, dynamic>;
      final int? msgtype = data['msgtype'] as int?;

      if (msgtype == 2) {
        Logger().i('Handling onboard message');
        await handleOnboardMessage(
          data,
          jsonMessage,
          sqfliteHelper,
          provider: provider,
          context: context,
        );
      } else if (msgtype == 3) {
        Logger().i('Handling offboard message');
        await handleOffboardMessage(
          data,
          jsonMessage,
          sqfliteHelper,
          provider: provider,
          context: context,
        );
      } else if (msgtype == 1 || msgtype == 4) {
        await handleBusStatusMessage(
          msgtype,
          jsonMessage,
          sqfliteHelper,
          provider: provider,
          context: context,
        );
      } else {
        logger.w('Unknown msgtype: $msgtype');
      }
    } catch (e) {
      logger.e('Error parsing MQTT message: $e');
    }
  }

  /// Handle onboard message (msgtype 2)
  static Future<void> handleOnboardMessage(
    Map<String, dynamic> data,
    Map<String, dynamic> jsonMessage,
    SqfliteHelper sqfliteHelper, {
    ChildrenProvider? provider,
    BuildContext? context,
  }) async {
    final String? studentId = data['studentid'] as String?;
    Logger().i('Handling onboard for studentId: $studentId');
    if (studentId != null) {
      await updateChildStatus(
        studentId,
        1,
        jsonMessage,
        sqfliteHelper,
        provider: provider,
        context: context,
      );
    } else {
      logger.w('Missing studentid in onboard message');
    }
  }

  /// Handle offboard message (msgtype 3)
  static Future<void> handleOffboardMessage(
    Map<String, dynamic> data,
    Map<String, dynamic> jsonMessage,
    SqfliteHelper sqfliteHelper, {
    ChildrenProvider? provider,
    BuildContext? context,
  }) async {
    final List<dynamic>? offlist = data['offlist'] as List<dynamic>?;

    if (offlist != null) {
      for (var id in offlist) {
        if (id is String) {
          await updateChildStatus(
            id,
            2,
            jsonMessage,
            sqfliteHelper,
            provider: provider,
            context: context,
          ); // Offboard status
        }
      }
    } else {
      logger.w('Missing offlist in offboard message');
    }
  }

  /// Handle bus status message (msgtype 1 or 4)
  static Future<void> handleBusStatusMessage(
    int? msgtype,
    Map<String, dynamic> jsonMessage,
    SqfliteHelper sqfliteHelper, {
    ChildrenProvider? provider,
    BuildContext? context,
  }) async {
    String devid = jsonMessage['devid'] ?? '';
    if (devid.isNotEmpty) {
      final parts = devid.split('_');
      if (parts.length == 2) {
        final routeId = parts[0];
        final oprId = parts[1];
        // Fetch route name from DB
        final routes = await sqfliteHelper.getStopListByOprIdAndRouteId(
          oprId,
          routeId,
        );
        String routeName = 'Route $routeId';
        if (routes.isNotEmpty) {
          final stopListStr = routes.first['stop_list'] as String?;
          if (stopListStr != null) {
            try {
              final stopList = jsonDecode(stopListStr) as List<dynamic>;
              if (stopList.isNotEmpty) {
                routeName = stopList.first['route_name'] ?? routeName;
              }
            } catch (e) {
              logger.e('Error parsing stop_list: $e');
            }
          }
        }
        // Show notification
        await NotificationService.notifyBusStatus(
          routeName: routeName,
          isActivated: msgtype == 1,
        );
        // Update provider if in foreground
        if (provider != null && context != null) {
          final children = provider.children;
          for (var child in children) {
            for (var route in child.routeInfo) {
              String key = '${route.routeId}_${route.oprId}';
              if (key == devid) {
                if (msgtype == 1) {
                  provider.updateActiveRoutes(key, true);
                } else if (msgtype == 4) {
                  provider.updateActiveRoutes(key, false);
                }
              }
            }
          }
        }
      }
    } else {
      logger.w('Missing devid in bus active/inactive message');
    }
  }

  /// Update child status
  static Future<void> updateChildStatus(
    String studentId,
    int status,
    Map<String, dynamic> jsonMessage,
    SqfliteHelper sqfliteHelper, {
    ChildrenProvider? provider,
    BuildContext? context,
  }) async {
    // Fetch child name from DB
    final children = await sqfliteHelper.getChildren();
    final child = children.cast<Map<String, dynamic>>().firstWhere(
      (c) => c['student_id'] == studentId,
      orElse: () => <String, dynamic>{},
    );

    if (child.isNotEmpty) {
      final childName = child['name'] as String;
      // Show notification
      await NotificationService.notifyChildStatus(
        childName: childName,
        isOnboard: status == 1,
      );
      // Save to database
      final onBoardLocation = status == 1
          ? jsonMessage['data']['location']
          : '';
      final offBoardLocation = status == 2
          ? jsonMessage['data']['location']
          : '';
      Logger().i(
        'Inserting activity for studentId: $studentId, status: ${status == 1 ? 'onboarded' : 'offboarded'}',
      );
      await sqfliteHelper.insertActivity({
        'student_id': studentId,
        'student_name': childName,
        'status': status == 1 ? 'onboarded' : 'offboarded',
        'on_location': onBoardLocation,
        'off_location': offBoardLocation,
        'route_id': jsonMessage['devid'].split('_')[0],
        'oprid': jsonMessage['devid'].split('_')[1],
        'message_time': jsonMessage['timestamp'],
      });

      // Update provider if in foreground
      if (provider != null && context != null) {
        final childIndex = provider.children.indexWhere(
          (child) => child.studentId == studentId,
        );
        if (childIndex != -1) {
          provider.updateChildOnboardStatus(studentId, status);
          provider.updateActivity();
          logger.i(
            'Updated child $studentId status to ${status == 1 ? 'onboarded' : 'offboarded'} in provider',
          );
        }
      }
    } else {
      logger.w('Child with studentId $studentId not found');
    }
  }
}
