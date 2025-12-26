import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiddo_tracker/pages/activityscreen.dart';
import 'package:kiddo_tracker/pages/addchildscreen.dart';
import 'package:kiddo_tracker/pages/changedactivity.dart';
import 'package:kiddo_tracker/pages/homescreen.dart';
import 'package:kiddo_tracker/pages/settingscreen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  //default
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  int _notificationCount = 0;
  DateTime? _lastBackPressTime;

  // void incrementNotificationCount() {
  //   setState(() {
  //     _notificationCount++;
  //   });
  // }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index); // Navigate to the selected page
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose of the PageController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure _selectedIndex is within bounds
    if (_selectedIndex >= 4) {
      _selectedIndex = 0;
    }
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          //show app logo
          title: Image.asset('assets/images/kt_logo.png', height: 30),
          // title: const Text('Kiddo Tracker'),
          //notification icon with default badge count is 0 and clickable to navigate to alerts screen
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Alerts',
                  iconSize: 24,
                  splashRadius: 20,
                  onPressed: () {
                    _pageController.jumpToPage(
                      4,
                    ); // Navigate to ChangedActivity screen
                  },
                ),
                if (_notificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: [
            HomeScreen(
              onNewMessage: (count) {
                setState(() {
                  _notificationCount = count;
                });
              },
            ),
            const AddChildScreen(),
            const ActivityScreen(),
            SettingScreen(),
            ChangedActivity(
              onNewMessage: (count) {
                setState(() {
                  _notificationCount = count;
                });
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.child_care),
              label: 'Child',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event),
              label: 'Activities',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
