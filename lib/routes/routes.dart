import 'package:flutter/material.dart';
import 'package:kiddo_tracker/pages/addchildroute.dart';
import 'package:kiddo_tracker/pages/loginscreen.dart';
import 'package:kiddo_tracker/pages/mainscreen.dart';
import 'package:kiddo_tracker/pages/otpscreen.dart';
import 'package:kiddo_tracker/pages/pinscreen.dart';
import 'package:kiddo_tracker/pages/signupscreen.dart';
import 'package:kiddo_tracker/pages/forgetpinscreen.dart';
import 'package:kiddo_tracker/pages/subscriptionscreen.dart';

import '../pages/request_leave_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String otp = '/otp';
  static const String pin = '/pin';
  static const String forgetPin = '/forgetpin';
  static const String signup = '/signup';
  static const String main = '/main';
  static const String subscribe = '/subscribe';
  static const String addRoute = '/addroute';
  static const String requestLeave = '/requestLeave';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case otp:
        final mobileNumber = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => OTPScreen(mobile: mobileNumber),
        );
      case pin:
        return MaterialPageRoute(builder: (_) => PINScreen());
      case forgetPin:
        return MaterialPageRoute(builder: (_) => ForgetPINScreen());
      case signup:
        final mobileNumber = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => SignUpScreen(mobile: mobileNumber),
        );
      case main:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case subscribe:
        final childId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => SubscriptionScreen(childid: childId),
        );
      case addRoute:
        final arguments = settings.arguments as Map;
        final childName = arguments['childName'];
        final childId = arguments['childId'];
        return MaterialPageRoute(
          builder: (_) =>
              AddChildRoutePage(nickName: childName, stdId: childId),
        );
      case requestLeave:
        final child = settings.arguments as Map<String, dynamic>;
        final oprId = child['oprId'];
        final routeId = child['routeId'];
        return MaterialPageRoute(
          builder: (_) => RequestLeaveScreen(child: child, oprId: oprId, routeId: routeId),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }

  // static Map<String, WidgetBuilder> get routes {
  //   return {
  //     login: (context) => const LoginScreen(),
  //     otp: (context) => OTPScreen(),
  //     pin: (context) => PINScreen(),
  //     forgetPin: (context) => ForgetPINScreen(),
  //     signup: (context) => SignUpScreen(),
  //     main: (context) => const MainScreen(),
  //     subscribe: (context) => const SubscriptionScreen(),
  //     addRoute: (context) => AddChildRoutePage(),
  //   };
  // }
}
