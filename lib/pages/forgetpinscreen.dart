import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:logger/logger.dart';

import '../routes/routes.dart';

class ForgetPINScreen extends StatefulWidget {
  const ForgetPINScreen({super.key});

  @override
  State<ForgetPINScreen> createState() => _ForgetPINScreenState();
}

class _ForgetPINScreenState extends State<ForgetPINScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final Logger logger = Logger();
  bool _isLoading = false;
  int _currentStep = 0; // 0: mobile, 1: otp, 2: pin

  @override
  void dispose() {
    _mobileController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final c in _pinControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final mobile = _mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      logger.i('Sending OTP to $mobile for PIN reset');
      final response = await ApiService.sendOTP(mobile);
      if (response.statusCode == 200) {
        logger.i(response.toString());
        if (response.data[0]['result'] == 'ok') {
          SharedPreferenceHelper.setUserNumber(mobile);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent successfully')),
          );
          setState(() {
            _currentStep = 1; // Move to OTP input
          });
        } else {
          throw Exception('Error: ${response.data['message']}');
        }
      } else {
        throw Exception('Failed to send OTP: ${response.statusMessage}');
      }
      // await Future.delayed(const Duration(seconds: 2));
      // if (mounted) {
      // }
    } catch (e, stacktrace) {
      logger.e('Error sending OTP', error: e, stackTrace: stacktrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send OTP. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();

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
      final mobile = _mobileController.text.trim();
      logger.i('Verifying OTP $otp for $mobile');
      final response = await ApiService.verifyOTP(mobile, otp);

      // await Future.delayed(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        logger.i(response.toString());
        if (response.data[0]['result'] == 'ok') {
          // OTP verified successfully
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP verified successfully')),
          );
          setState(() {
            _currentStep = 2; // Move to PIN input
          });
        } else {
          throw Exception('Error: ${response.data[1]['data']}');
        }
      } else {
        throw Exception('Failed to verify OTP: ${response.statusMessage}');
      }
      // if (mounted) {
      // }
    } catch (e, stacktrace) {
      logger.e('Error verifying OTP', error: e, stackTrace: stacktrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setNewPIN() async {
    final pin = _pinControllers.map((c) => c.text).join();

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
      final mobile = _mobileController.text.trim();
      final otp = _otpControllers.map((c) => c.text).join();
      logger.i('Setting new PIN for $mobile, OTP: $otp, PIN: $pin');

      // await Future.delayed(const Duration(seconds: 2));
      final response = await ApiService.forgotPassword(mobile, otp, pin);

      if (response.statusCode == 200) {
        logger.i(response.toString());
        if (response.data[0]['result'] == 'ok') {
          // PIN set successfully
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN set successfully')),
          );
          Navigator.pushReplacementNamed(context, AppRoutes.pin);
        } else {
          throw Exception('Error: ${response.data[1]['data']}');
        }
      } else {
        throw Exception('Failed to set new PIN: ${response.statusMessage}');
      }
      // if (mounted) {
      // }
    } catch (e, stacktrace) {
      logger.e('Error setting new PIN', error: e, stackTrace: stacktrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to set PIN. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildMobileInput() {
    return Column(
      children: [
        const Text(
          'Forgot PIN',
          style: TextStyle(
            color: Color(0xFF755DC1),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Enter your registered mobile number to reset PIN',
          style: TextStyle(color: Color(0xFF837E93), fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            hintText: 'Enter 10-digit mobile number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF837E93)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9F7BFF), width: 2),
            ),
            prefixIcon: const Icon(Icons.phone, color: Color(0xFF837E93)),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9F7BFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Text(
                    'Send OTP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPInput() {
    final node = FocusScope.of(context);

    return Column(
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
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _otpControllers[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(fontSize: 24),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF837E93)),
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
            onPressed: _isLoading ? null : _verifyOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9F7BFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Text(
                    'Verify OTP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPINInput() {
    final node = FocusScope.of(context);

    return Column(
      children: [
        const Text(
          'Set New PIN',
          style: TextStyle(
            color: Color(0xFF755DC1),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Please enter your new 4-digit PIN',
          style: TextStyle(color: Color(0xFF837E93), fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _pinControllers[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(fontSize: 24),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF837E93)),
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
            onPressed: _isLoading ? null : _setNewPIN,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9F7BFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Text(
                    'Set PIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentWidget;
    switch (_currentStep) {
      case 1:
        currentWidget = _buildOTPInput();
        break;
      case 2:
        currentWidget = _buildPINInput();
        break;
      default:
        currentWidget = _buildMobileInput();
    }

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
                currentWidget,
                const SizedBox(height: 16),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                    },
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF9F7BFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (_currentStep == 0)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Back to PIN Screen',
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
}
