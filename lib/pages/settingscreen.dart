import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/pages/addchildscreen.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/services/background_service.dart';
import 'package:kiddo_tracker/services/children_provider.dart';
import 'package:kiddo_tracker/services/theme_provider.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'changepinscreen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  //use sqflite to get user details
  SqfliteHelper sqfliteHelper = SqfliteHelper();

  String userName = '';
  String mobileNumber = '';
  String Address = '';
  String session = '';
  List<Map<String, dynamic>> children = [];
  List<Map<String, dynamic>> subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    // Removed sqfliteHelper.close() to prevent closing the database while async operations are in progress
    super.dispose();
    // Removed clearAllData call to avoid clearing data prematurely
    // clearAllData();
  }

  void clearAllData() {
    userName = '';
    mobileNumber = '';
    Address = '';
    session = '';
    children = [];
  }

  Future<void> _fetchUserData() async {
    List<Map<String, dynamic>> users = await sqfliteHelper.getUsers();
    Logger().d(users);
    List<Map<String, dynamic>> children = await sqfliteHelper.getChildren();
    List<Map<String, dynamic>> subscriptions = await sqfliteHelper
        .getStudentSubscriptions();
    if (mounted) {
      setState(() {
        userName = users[0]['name'] ?? '';
        mobileNumber = users[0]['mobile'] ?? '';
        Address = users[0]['address'] ?? '';
        session = users[0]['sessionid'] ?? '';
        this.children = List.from(children);
        this.subscriptions = List.from(subscriptions);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Settings'),
      //   backgroundColor: Theme.of(context).primaryColor,
      //   foregroundColor: Colors.white,
      // ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // User Profile Section
            Text(
              'User Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Divider(
              thickness: 2,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: 5),
                Icon(
                  Icons.person_4_outlined,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  size: 35,
                ),
                SizedBox(width: 10),
                Text(
                  userName.isNotEmpty ? userName : 'Loading...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                // data sync icon
                Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.update,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    size: 35,
                  ),
                  onPressed: () => dataUpdate(),
                ),
              ],
            ),
            SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.phone,
                    size: 30,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                title: Text('Mobile'),
                subtitle: Text(mobileNumber),
              ),
              // ),
            ),
            SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 30,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                title: Text('Address'),
                subtitle: Text(Address),
              ),
            ),
            SizedBox(height: 30),
            // Children Section
            Text(
              'Children',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Divider(
              thickness: 2,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            // SizedBox(height: 10),
            // Text(
            //   'Total Children: ${children.length}',
            //   style: TextStyle(
            //     fontSize: 16,
            //     fontWeight: FontWeight.w500,
            //     color: Theme.of(context).primaryColorDark,
            //   ),
            // ),
            // SizedBox(height: 15),
            ...children.asMap().entries.map((entry) {
              int idx = entry.key;
              var child = entry.value;
              return Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      child['name'][0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    child['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.w300,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Age: ${child['age']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        'School: ${child['school']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        'Class: ${child['class_name']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        'Plan: ${subscriptions.firstWhere((sub) => sub['student_id'] == child['student_id'], orElse: () => {})['plan_name'] ?? 'No plan selected'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        'Days left: ${_calculateDaysLeft(child)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blueAccent),
                        tooltip: 'Edit child',
                        onPressed: () => editChild(idx),
                      ),
                      SizedBox(height: 4),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.redAccent),
                        tooltip: 'Delete child',
                        onPressed: () =>
                            _confirmDeleteChild(idx, child['tag_id']),
                      ),
                      SizedBox(height: 4),
                      IconButton(
                        icon: Icon(Icons.event_note, color: Colors.green),
                        tooltip: 'Request leave',
                        onPressed: () => requestLeave(child),
                      ),
                    ],
                  ),
                ),
              );
            }),
            SizedBox(height: 30),
            // Preferences Section
            Text(
              'Preferences',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Divider(
              thickness: 2,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            SizedBox(height: 10),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text('Dark Mode'),
                    value: themeProvider.isDarkMode,
                    onChanged: (val) {
                      themeProvider.toggleTheme();
                    },
                    secondary: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      child: Icon(
                        themeProvider.isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        key: ValueKey<bool>(themeProvider.isDarkMode),
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            // Account Section
            Text(
              'Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Divider(
              thickness: 2,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
            SizedBox(height: 10),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lock,
                    size: 30,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                title: Text('Change PIN'),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                onTap: () => _changePin(),
              ),
            ),
            SizedBox(height: 8),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.logout,
                    size: 30,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                title: Text('Logout'),
                trailing: Icon(Icons.arrow_forward_ios, color: Colors.red),
                onTap: () => _logout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChild(int idx, String tagId) {
    // Before deleting, check tag assign to child or not
    // If assigned, show message cannot delete child
    // Else show confirm dialog
    if (tagId.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete child. Tags are assigned to this child.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Child'),
          content: Text('Are you sure you want to delete this child?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                deleteChild(idx);
              },
            ),
          ],
        );
      },
    );
  }

  void editChild(int idx) {
    final child = children[idx];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddChildScreen(childData: child, isEdit: true),
      ),
    ).then((value) {
      // Refresh the list after returning from AddChildScreen
      _fetchUserData();
    });
  }

  void deleteChild(int idx) async {
    final String studentId = children[idx]['student_id'];
    final provider = Provider.of<ChildrenProvider>(context, listen: false);
    final sessionId = await SharedPreferenceHelper.getUserSessionId();
    final oprIdList = await sqfliteHelper.getAllRoutesByStudentId(studentId);
    final logOprIdList = oprIdList.isNotEmpty
        ? oprIdList.map((e) => '"$e"').toList().toString()
        : [];
    //example of logOprIdList: ["oprid1", "oprid2"] or []
    //get the datatype of logOprIdList
    Logger().d('logOprIdList type: ${logOprIdList.runtimeType}');
    Logger().i(
      'Deleting child with ID: $studentId, user ID: $mobileNumber, session ID: $sessionId, oprIdList: $logOprIdList',
    );
    try {
      var response = await ApiManager().post(
        'ktuserstddelete',
        data: {
          'student_id': studentId,
          'oprids': logOprIdList,
          'sessionid': sessionId,
          'userid': mobileNumber,
        },
      );
      print('Delete child response: ${response.data}');
      if (response.statusCode == 200 && response.data[0]['result'] == 'ok') {
        int deletedCount = await sqfliteHelper.deleteChild(studentId);
        if (deletedCount > 0) {
          setState(() {
            children.removeAt(idx);
          });
          provider.updateChildren();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Child deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // provider.removeChildOrRouteOprid('child', studentId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete child locally.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete child. Server error.',
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error deleting child: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting child: $e',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  void dataUpdate() {
    //
  }

  void requestLeave(Map<String, dynamic> child) {
    Navigator.push(
      context,
      // MaterialPageRoute(builder: (context) => RequestLeaveScreen(child: child)),
      AppRoutes.generateRoute(
        RouteSettings(
          name: AppRoutes.requestLeave,
          arguments: {'child': child},
        ),
      ),
    );
  }

  void _changePin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangePinScreen()),
    );
  }

  void _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop(); // close the dialog
                await logout();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> logout() async {
    String? mobileNumber = await SharedPreferenceHelper.getUserNumber() ?? '';
    String? session = await SharedPreferenceHelper.getUserSessionId() ?? '';

    Response response = await ApiManager().post(
      'ktrackuserlogout',
      data: {'userid': mobileNumber, 'sessionid': session},
    );
    if (response.statusCode == 200 && response.data[0]['result'] == 'ok') {
      // Clear shared preferences
      // await SharedPreferenceHelper.clearAllExceptNumberAndLogin();
      // Clear database
      // sqfliteHelper.clearAllData();
      // Stop background service
      await BackgroundService.stop();
      // Show success SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged out successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // close the open AlertDialog
      // Redirect to pinscreen
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.pin, (route) => false);
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to logout. Please try again.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  String _calculateDaysLeft(Map<String, dynamic> child) {
    final sub = subscriptions.firstWhere(
      (sub) => sub['student_id'] == child['student_id'],
      orElse: () => {},
    );
    if (sub.isEmpty || sub['enddate'] == null) {
      return 'N/A';
    }
    try {
      final DateTime endDate = DateTime.parse(sub['enddate']);
      final DateTime now = DateTime.now();
      // trim time (keep only date)
      final DateTime endDateOnly = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      );
      final DateTime nowOnly = DateTime(now.year, now.month, now.day);
      Logger().d("Date: $endDateOnly, $nowOnly rdkjghd");
      //now get the difference.
      final int difference = endDateOnly.difference(nowOnly).inDays;
      return difference >= 0 ? '$difference days' : 'Expired';
    } catch (e) {
      return 'N/A';
    }
  }
}
