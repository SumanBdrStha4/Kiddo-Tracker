import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';

import '../routes/routes.dart';

class PINScreen extends StatefulWidget {
  const PINScreen({super.key});

  @override
  State<PINScreen> createState() => _PINScreenState();
}

class _PINScreenState extends State<PINScreen> {
  late String mobileNumber;
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  final Logger logger = Logger();
  final SqfliteHelper _sqfliteHelper = SqfliteHelper();

  bool _isLoading = false;
  int _currentFocusIndex = 0;

  @override
  void initState() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].canRequestFocus = i == 0;
    }
    _focusNodes[0].requestFocus();
    super.initState();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _signIn() async {
    final pin = _controllers.map((c) => c.text).join();

    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid 4-digit PIN'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save mobile number in shared preferences
      String? result = await SharedPreferenceHelper.getUserNumber();
      Logger().d("debug: $result");
      if (result != null) {
        mobileNumber = result;
      } else {
        mobileNumber = "1234567890";
      }
      final response = await ApiService.verifyPIN(mobileNumber, pin);
      Logger().d("debug: $response");
      final data = response.data;
      if (response.data[0]['result'] == 'ok') {
        //update new session token
        String newSessionToken = response.data[1]['userdata'][0]['sessionid']
            .toString();
        // handle the empty case.
        if (response.data[2]['studentdata'] ==
            'ktuserstudentlist Data not found') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No student data found for this user.'),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        } else {
          Logger().d("debug: ${response.data[2]['studentdata']}");
          //update the tag_id in sqflite base on student_id
          await _sqfliteHelper.updateTagId(
            response.data[2]['studentdata'][0]['tag_id'].toString(),
            response.data[2]['studentdata'][0]['student_id'].toString(),
          );
        }
        /*
        [{result: ok}, {userdata: [{userid: 8456029772, name: Suman Shrestha, city: BBS, state: Odisha, address: khandagiri, contact: 8456029772, email: suman123@gmail.com, mobile: 1234567890, wards: 0, status: 1, pin: 1234, sessionid: 363708456029772}]}, {studentdata: ktuserstudentlist Data not found}]
        */
        //tempory
        // Parent parent = Parent(
        //   userid: response.data[1]['userdata'][0]['userid'],
        //   name: response.data[1]['userdata'][0]['name'],
        //   city: response.data[1]['userdata'][0]['city'],
        //   state: response.data[1]['userdata'][0]['state'],
        //   address: response.data[1]['userdata'][0]['address'],
        //   contact: response.data[1]['userdata'][0]['contact'],
        //   email: response.data[1]['userdata'][0]['email'],
        //   mobile: response.data[1]['userdata'][0]['mobile'],
        //   wards: response.data[1]['userdata'][0]['wards'],
        //   status: response.data[1]['userdata'][0]['status'],
        //   pin: response.data[1]['userdata'][0]['pin'],
        // );
        // await _sqfliteHelper.insertUser(parent);

        await SharedPreferenceHelper.setUserSessionId(newSessionToken);
        //clear all except mobile number and isLoggedIn
        // SharedPreferenceHelper.clearAllExceptNumberAndLogin();
        // SharedPreferenceHelper.setUserLoggedIn(true);
        //use ChildrenService _processChildrenData
        // final result = await ChildrenService().processChildrenData(data);
        // if (result['success'] == true) {
        SharedPreferenceHelper.setUserLoggedIn(true);
        Navigator.pushNamed(context, AppRoutes.main);
        // }
      } else {
        String data = response.data[1]['data'];
        //clear the _controllers.
        for (final controller in _controllers) {
          controller.clear();
        }
        // Reset focus to the first field
        for (int i = 0; i < _focusNodes.length; i++) {
          _focusNodes[i].canRequestFocus = i == 0;
        }
        _currentFocusIndex = 0;
        _focusNodes[0].requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data), backgroundColor: Colors.red),
        );
      }
    } catch (e, stacktrace) {
      logger.e(
        'Error during PIN verification',
        error: e,
        stackTrace: stacktrace,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = FocusScope.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20.0),
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Enter PIN',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please enter your 4-digit PIN',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, _pinField),
                ),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: List.generate(4, (index) {
                //     return Container(
                //       width: 48,
                //       margin: const EdgeInsets.symmetric(horizontal: 4),
                //       child: AbsorbPointer(
                //         absorbing: index != _currentFocusIndex,
                //         child: TextField(
                //           controller: _controllers[index],
                //           focusNode: _focusNodes[index],
                //           keyboardType: TextInputType.number,
                //           textAlign: TextAlign.center,
                //           maxLength: 1,
                //           obscureText: true,
                //           enableInteractiveSelection: false,
                //           style: const TextStyle(fontSize: 24),
                //           decoration: InputDecoration(
                //             border: OutlineInputBorder(
                //               borderRadius: BorderRadius.circular(12),
                //               borderSide: const BorderSide(
                //                 color: Color(0xFF837E93),
                //               ),
                //             ),
                //             focusedBorder: OutlineInputBorder(
                //               borderRadius: BorderRadius.circular(12),
                //               borderSide: const BorderSide(
                //                 color: Color(0xFF9F7BFF),
                //                 width: 2,
                //               ),
                //             ),
                //             counterText: '',
                //           ),
                //           onChanged: (value) {
                //             if (value.isNotEmpty && index < 3) {
                //               _currentFocusIndex = index + 1;
                //               _focusNodes[_currentFocusIndex].canRequestFocus =
                //                   true;
                //               _focusNodes[_currentFocusIndex].requestFocus();
                //             } else if (value.isEmpty && index > 0) {
                //               _currentFocusIndex = index - 1;
                //               _focusNodes[_currentFocusIndex].requestFocus();
                //             }
                //           },
                //         ),
                //       ),
                //     );
                //   }),
                // ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            'Verify PIN',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.forgetPin);
                  },
                  child: Text(
                    'Forgot PIN?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Future<void> _fetchChildren() async {
  //   try {
  //     final result = await ChildrenService().fetchChildren();
  //     if (result['success'] == true) {
  //       // Get list of child route timings
  //       List<String> childRouteTimings = [];
  //       final children = result['result']['children'] as List<dynamic>;
  //       for (var child in children) {
  //         for (var route in child.routeInfo) {
  //           if (route.stopArrivalTime.isNotEmpty) {
  //             childRouteTimings.add(route.stopArrivalTime);
  //           }
  //         }
  //       }
  //       logger.i('List of child route timings: $childRouteTimings');

  //       if (mounted) {
  //         Navigator.pushNamed(context, AppRoutes.main);
  //       }
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     } else if (result['success'] == false) {
  //       if (mounted) {
  //         Navigator.pushNamed(context, AppRoutes.signup);
  //       }
  //       Logger().e('Error fetching children: ${result['data']}');
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     } else {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //       Logger().e(
  //         'Error fetching children: ${result['error'] ?? 'Unknown error'}',
  //       );
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //     Logger().e('Error fetching children: $e');
  //   }
  // }

  Widget _pinField(int index) {
    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: AbsorbPointer(
        absorbing: index != _currentFocusIndex, // 🔒 block clicks
        child: RawKeyboardListener(
          focusNode: FocusNode(), // required
          onKey: (event) {
            if (event is RawKeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace) {
              if (_controllers[index].text.isEmpty && index > 0) {
                setState(() {
                  _currentFocusIndex--;
                });
                _controllers[_currentFocusIndex].clear();
                _focusNodes[_currentFocusIndex].requestFocus();
              }
            }
          },
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            obscureText: false,
            showCursor: index == _currentFocusIndex,
            enableInteractiveSelection: false,
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                if (index < 3) {
                  setState(() {
                    _currentFocusIndex++;
                  });
                  _focusNodes[_currentFocusIndex].requestFocus();
                } else {
                  _focusNodes[index].unfocus();
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
