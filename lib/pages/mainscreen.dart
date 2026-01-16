import 'package:flutter/material.dart';
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
  int _selectedIndex = 0;
  int _notificationCount = 0;
  final PageController _pageController = PageController();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      _pageController.jumpToPage(0);
      return false;
    } else {
      return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit App'),
              content: const Text('Do you want to exit the app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          ) ??
          false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
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
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.notifications),
            //   label: 'Alerts',
            // ),
          ],
        ),
      ),
    );
  }
}

//       child: Scaffold(
//         appBar: AppBar(
//           automaticallyImplyLeading: false,
//           //show app logo
//           title: Image.asset('assets/images/kt_logo.png', height: 30),
//           // title: const Text('Kiddo Tracker'),
//           //notification icon with default badge count is 0 and clickable to navigate to alerts screen
//           actions: [
//             Stack(
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.notifications),
//                   tooltip: 'Alerts',
//                   iconSize: 24,
//                   splashRadius: 20,
//                   onPressed: () {
//                     _pageController.jumpToPage(
//                       4,
//                     ); // Navigate to ChangedActivity screen
//                   },
//                 ),
//                 if (_notificationCount > 0)
//                   Positioned(
//                     right: 0,
//                     top: 0,
//                     child: Container(
//                       padding: const EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.red,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       constraints: const BoxConstraints(
//                         minWidth: 16,
//                         minHeight: 16,
//                       ),
//                       child: Text(
//                         _notificationCount.toString(),
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ],
//         ),
//         body: PageView(
//           controller: _pageController,
//           physics: const NeverScrollableScrollPhysics(),
//           onPageChanged: (index) {
//             setState(() {
//               _selectedIndex = index;
//             });
//           },
//           children: [
//             HomeScreen(
//               onNewMessage: (count) {
//                 setState(() {
//                   _notificationCount = count;
//                 });
//               },
//             ),
//             const AddChildScreen(),
//             const ActivityScreen(),
//             SettingScreen(),
//             ChangedActivity(
//               onNewMessage: (count) {
//                 setState(() {
//                   _notificationCount = count;
//                 });
//               },
//             ),
//           ],
//         ),
//         bottomNavigationBar: BottomNavigationBar(
//           currentIndex: _selectedIndex,
//           onTap: _onItemTapped,
//           type: BottomNavigationBarType.fixed,
//           items: const [
//             BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.child_care),
//               label: 'Child',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.event),
//               label: 'Activities',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.settings),
//               label: 'Settings',
//             ),
//             // BottomNavigationBarItem(
//             //   icon: Icon(Icons.notifications),
//             //   label: 'Alerts',
//             // ),
//           ],
//         ),
//       ),
//     );
//   }
// }
