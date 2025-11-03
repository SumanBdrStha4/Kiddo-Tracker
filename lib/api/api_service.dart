import 'package:dio/dio.dart';
import 'apimanage.dart';

class ApiService {
  static Future<Response> verifyPIN(String mobile, String pin) async {
    return await ApiManager().post(
      'ktrackuserlogin/',
      data: {'userid': mobile, 'pin': pin},
    );
  }

  static Future<Response> sendOTP(String mobile) async {
    return await ApiManager().post('ktrackuserotp/', data: {'mobile': mobile});
  }

  static Future<Response> verifyOTP(String mobile, String otp) async {
    return await ApiManager().post(
      'ktrackuserverifyotp/',
      data: {'mobile': mobile, 'otpval': otp},
    );
  }

  static Future<Response> fetchUserByMobile(String mobile) async {
    return await ApiManager().post(
      'ktrackuserbymobile',
      data: {'passkey': "Usr.KdTrac4\$Dat", 'mobile': mobile},
    );
  }

  static Future<Response> forgotPassword(
    String mobile,
    String otp,
    String pin,
  ) async {
    return await ApiManager().post(
      'ktuserforgotpwd/',
      data: {'mobile': mobile, 'otpval': otp, 'newpin': pin},
    );
  }

  static Future<Response> fetchSubscriptionPlans(
    String userId,
    String sessionId,
  ) async {
    return await ApiManager().post(
      'ktusersubplansbyuid',
      data: {'userid': userId, 'sessionid': sessionId},
    );
  }

  static Future<Response> fetchVehicleInfo(
    String userId,
    String sessionId,
    String vehicleId,
  ) async {
    return await ApiManager().post(
      'ktuvehicleinfo/',
      data: {'userid': userId, 'sessionid': sessionId, 'vehicle_id': vehicleId},
    );
  }

  static Future<Response> fetchOperationStatus(
    String userId,
    String oprId,
    String sessionId,
  ) async {
    return await ApiManager().post(
      'ktuoperationstatus/',
      data: {'userid': userId, 'oprid': oprId, 'sessionid': sessionId},
    );
  }

  static Future<Response> fetchUserStudentList(
    String userId,
    String? sessionId,
  ) async {
    return await ApiManager().post(
      'ktuserstudentlist/',
      data: {'userid': userId, 'sessionid': sessionId},
    );
  }

  static Future<Response> deleteStudentRoute(
    String studentId,
    String oprId,
    String sessionId,
    String userId,
  ) async {
    return await ApiManager().post(
      'ktuserstdroutedel/',
      data: {
        'student_id': studentId,
        'oprid': oprId,
        'sessionid': sessionId,
        'userid': userId,
      },
    );
  }

  static Future<Response> addStudent(
    String userId,
    String sessionId,
    String name,
    String nickname,
    String school,
    String className,
    String rollNo,
    String gender,
    String age,
    String state,
  ) async {
    return await ApiManager().post(
      'ktuseraddstudent',
      data: {
        'userid': userId,
        'sessionid': sessionId,
        'name': name,
        'nickname': nickname,
        'school': school,
        'class': className,
        'rollno': rollNo,
        'gender': gender,
        'age': age,
        'state': state,
      },
    );
  }

  static Future<Response> editStudent(
    String userId,
    String sessionId,
    String studentId,
    String name,
    String nickname,
    String school,
    String className,
    String rollNo,
    String gender,
    String age,
    String state,
  ) async {
    return await ApiManager().post(
      'ktuserstudentedit',
      data: {
        'userid': userId,
        'sessionid': sessionId,
        'student_id': studentId,
        'name': name,
        'nickname': nickname,
        'school': school,
        'class': className,
        'rollno': rollNo,
        'gender': gender,
        'age': age,
        'state': state,
      },
    );
  }

  static Future<Response> checkSession(String userId, String sessionId) async {
    return await ApiManager().post(
      'ktrackusersessioncheck/',
      data: {'userid': userId, 'sessionid': sessionId},
    );
  }

  static Future<Response> fetchHolidays(
    String userId,
    String opId,
    String routeId,
    String sessionId,
  ) async {
    return await ApiManager().post(
      'ktutsprouteoffdays/',
      data: {
        'userid': userId,
        'oprid': opId,
        'route_id': routeId,
        'sessionid': sessionId,
      },
    );
  }

  static Future<Response> sendAbsentDays(
    String startDate,
    String endDate,
    String tspId,
    String studentId,
    String sessionId,
    String userId,
  ) async {
    return await ApiManager().post(
      'ktuserstdoffdayadd/',
      data: {
        'userid': userId,
        'start_date': startDate,
        'end_date': endDate,
        'tsp_id': tspId,
        'student_id': studentId,
        'sessionid': sessionId,
      },
    );
  }
}
