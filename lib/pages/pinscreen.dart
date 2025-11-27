import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/pages/otpscreen.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:logger/logger.dart';

import '../routes/routes.dart';
import '../services/children_service.dart';

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
  final Logger logger = Logger();

  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signIn() async {
    final pin = _controllers.map((c) => c.text).join();

    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 4-digit PIN')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save mobile number in shared preferences
      String? result = await SharedPreferenceHelper.getUserNumber();
      if (result != null) {
        mobileNumber = result;
      } else {
        mobileNumber = "1234567890";
      }
      final response = await ApiService.verifyPIN(mobileNumber, pin);
      final data = response.data;
      if (response.data[0]['result'] == 'ok') {
        //clear all except mobile number and isLoggedIn
        SharedPreferenceHelper.clearAllExceptNumberAndLogin();
        SharedPreferenceHelper.setUserLoggedIn(true);
        //use ChildrenService _processChildrenData
        final result = await ChildrenService().processChildrenData(data);
        if (result['success'] == true) {
          Navigator.pushNamed(context, AppRoutes.main);
        }
      } else {
        String data = response.data[1]['data'];
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data)));
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
      backgroundColor: Colors.white,
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
                const Text(
                  'Enter PIN',
                  style: TextStyle(
                    color: Color(0xFF755DC1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please enter your 4-digit PIN',
                  style: TextStyle(color: Color(0xFF837E93), fontSize: 16),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      width: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _controllers[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 24),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF837E93),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF9F7BFF),
                              width: 2,
                            ),
                          ),
                          counterText: '',
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 3) {
                            node.nextFocus();
                          } else if (value.isEmpty && index > 0) {
                            node.previousFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9F7BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify PIN',
                            style: TextStyle(
                              color: Colors.white,
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
                  child: const Text(
                    'Forgot PIN?',
                    style: TextStyle(
                      color: Color(0xFF9F7BFF),
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
}
