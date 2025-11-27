import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kiddo_tracker/services/children_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:logger/logger.dart';

import '../api/api_service.dart';
import '../routes/routes.dart';

class OTPScreen extends StatefulWidget {
  String? mobile;
  OTPScreen({super.key, this.mobile});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final Logger logger = Logger();

  bool _isLoading = false;
  int _remainingTime = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingTime = 30;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime > 0) {
            _remainingTime--;
          } else {
            _canResend = true;
            _timer?.cancel();
          }
        });
      }
    });
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final mobileNumber = widget.mobile ?? '';
      final response = await ApiService.sendOTP(mobileNumber);

      if (response.statusCode == 200) {
        logger.i(response.toString());
        if (response.data[0]['result'] == 'ok') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent successfully')),
          );
          _startTimer();
        } else {
          throw Exception('Error: ${response.data['message']}');
        }
      } else {
        throw Exception('Failed to send OTP: ${response.statusMessage}');
      }
    } catch (e, stacktrace) {
      logger.e('Error resending OTP', error: e, stackTrace: stacktrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to resend OTP. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signIn() async {
    final otp = _controllers.map((c) => c.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String mobileNumber = widget.mobile ?? '';
      final response = await ApiService.verifyOTP(mobileNumber, otp);

      if (response.statusCode == 200) {
        logger.i(response.toString());
        if (response.data[0]['result'] == 'ok') {
          // Save mobile number in shared preferences
          SharedPreferenceHelper.setUserNumber(widget.mobile ?? '');
          // call another method
          _fetchChildren();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP verified successfully')),
          );
        } else if (response.data[0]['result'] == 'Invaild OTP') {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invaild OTP')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify OTP: ${response.statusMessage}'),
          ),
        );
      }
    } catch (e, stacktrace) {
      logger.e(
        'Error during OTP verification',
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
                  'Enter OTP',
                  style: TextStyle(
                    color: Color(0xFF755DC1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please enter the OTP sent to your phone',
                  style: TextStyle(color: Color(0xFF837E93), fontSize: 16),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
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
                          if (value.isNotEmpty && index < 5) {
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
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _canResend
                          ? 'Didn\'t receive OTP?'
                          : 'Resend OTP in $_remainingTime seconds',
                      style: const TextStyle(
                        color: Color(0xFF837E93),
                        fontSize: 14,
                      ),
                    ),
                    if (_canResend) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _resendOTP,
                        child: const Text(
                          'Resend',
                          style: TextStyle(
                            color: Color(0xFF9F7BFF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchChildren() async {
    try {
      final result = await ChildrenService().fetchChildren();
      if (result['success'] == true) {
        if (mounted) {
          SharedPreferenceHelper.setUserLoggedIn(true);
          Navigator.pushNamed(context, AppRoutes.main);
        }
        setState(() {
          _isLoading = false;
        });
      } else if (result['success'] == false) {
        if (mounted) {
          Navigator.pushNamed(context, AppRoutes.signup);
        }
        Logger().e('Error fetching children: ${result['data']}');
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        Logger().e(
          'Error fetching children: ${result['error'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Logger().e('Error fetching children: $e');
    }
  }
}
