import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceHelper {
  //constructor
  SharedPreferenceHelper._();
  // logged in
  static Future<void> setUserLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("loggedIn", value);
  }

  static Future<bool?> getUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("loggedIn");
  }

  // user Number
  static Future<void> setUserNumber(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("userNumber", value);
  }

  static Future<String?> getUserNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("userNumber");
  }

  //user session id
  static Future<void> setUserSessionId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("userSessionId", value);
  }

  static Future<String?> getUserSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("userSessionId");
  }

  static Future<void> setEarliestRouteHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("earliestRouteHour", hour);
  }

  static Future<int?> getEarliestRouteHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("earliestRouteHour");
  }

  static Future<void> setEarliestRouteMinute(int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("earliestRouteMinute", minute);
  }

  static Future<int?> getEarliestRouteMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("earliestRouteMinute");
  }

  // session expiry
  // static Future<void> setSessionExpiry(DateTime value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString("sessionExpiry", value.toIso8601String());
  // }

  // static Future<DateTime?> getSessionExpiry() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final string = prefs.getString("sessionExpiry");
  //   return string != null ? DateTime.parse(string) : null;
  // }

  static Future<void> clearAllExceptNumberAndLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("userNumber");
    await prefs.remove("userSessionId");
    await prefs.remove("earliestRouteHour");
    await prefs.remove("earliestRouteMinute");
  }

  static Future<void> clearUserSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("userSessionId");
  }

  // app active status
  static Future<void> setAppActive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("appActive", value);
  }

  static Future<bool> getAppActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("appActive") ?? false;
  }
}
