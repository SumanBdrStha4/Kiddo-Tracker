import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  final Logger logger = Logger();
  bool _isLoading = false;
  int _currentStep = 0; // 0: mobile, 1: otp, 2: pin
  int _currentFocusIndex = 0;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _otpFocusNodes.length; i++) {
      _otpFocusNodes[i].canRequestFocus = i == 0;
    }
    _otpFocusNodes[0].requestFocus();
    for (int i = 0; i < _pinFocusNodes.length; i++) {
      _pinFocusNodes[i].canRequestFocus = i == 0;
    }
    _pinFocusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final mobile = _mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      logger.i('Sending OTP to $mobile for PIN reset');
      final response = await ApiService.forgotPasswordOtp(mobile);
      if (response.statusCode == 200) {
        logger.i(response.toString());
        if (response.data[0]['result'] == 'ok') {
          SharedPreferenceHelper.setUserNumber(mobile);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _currentStep = 1; // Move to OTP input
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${response.data[0]['data']}'),
              backgroundColor: Colors.red,
            ),
          );
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
        const SnackBar(
          content: Text('Failed to send OTP. Please try again.'),
          backgroundColor: Colors.red,
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

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final mobile = _mobileController.text.trim();
      logger.i('Verifying OTP $otp for $mobile');
      setState(() {
        _otpControllers.clear();
        for (final controller in _otpControllers) {
          controller.clear();
        }
        _currentFocusIndex = 0;
        _currentStep = 2; // Move to PIN input
      });
    } catch (e, stacktrace) {
      logger.e('Error verifying OTP', error: e, stackTrace: stacktrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid OTP. Please try again.'),
          backgroundColor: Colors.red,
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
            const SnackBar(
              content: Text('PIN set successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, AppRoutes.pin);
        } else if (response.data[1]['data'] == "Invalid OTP") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${response.data[1]['data']}'),
              backgroundColor: Colors.red,
            ),
          );
          for (final controller in _pinControllers) {
            controller.clear();
          }
          setState(() {
            _currentStep--;
          });
          _otpControllers.clear();
          for (final controller in _otpControllers) {
            controller.clear();
          }
          // Set focus to the first field
          _otpFocusNodes[0].requestFocus();
        } else {
          //clear the _controllers.
          for (final controller in _pinControllers) {
            controller.clear();
          }
          // Set focus to the first field
          _pinFocusNodes[0].requestFocus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${response.data[1]['data']}'),
              backgroundColor: Colors.red,
            ),
          );
          // throw Exception('Error: ${response.data[1]['data']}');
        }
      } else {
        throw Exception('Failed to set new PIN: ${response.statusMessage}');
      }
      // if (mounted) {
      // }
    } catch (e, stacktrace) {
      logger.e('Error setting new PIN', error: e, stackTrace: stacktrace);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to set PIN. Please try again.'),
          backgroundColor: Colors.red,
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

  Widget _buildMobileInput() {
    return Column(
      children: [
        Text(
          'Forgot PIN',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Enter your registered mobile number to reset PIN',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 16,
          ),
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
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            prefixIcon: Icon(
              Icons.phone,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOTP,
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
                    'Send OTP',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
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
        Text(
          'Enter OTP',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Please enter the OTP sent to your phone',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
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
                      if (_otpControllers[index].text.isEmpty && index > 0) {
                        setState(() {
                          _currentFocusIndex--;
                        });
                        _otpControllers[_currentFocusIndex].clear();
                        _otpFocusNodes[_currentFocusIndex].requestFocus();
                      }
                    }
                  },
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    obscureText: false,
                    showCursor: index == _currentFocusIndex,
                    enableInteractiveSelection: false,
                    style: const TextStyle(fontSize: 24),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      counterText: '',
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        if (index < 5) {
                          setState(() {
                            _currentFocusIndex++;
                          });
                          _otpFocusNodes[_currentFocusIndex].requestFocus();
                        } else {
                          _otpFocusNodes[index].unfocus();
                        }
                      }
                    },
                  ),
                ),
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
                    'Set OTP',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
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
        Text(
          'Set New PIN',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Please enter your new 4-digit PIN',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
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
                      if (_pinControllers[index].text.isEmpty && index > 0) {
                        setState(() {
                          _currentFocusIndex--;
                        });
                        _pinControllers[_currentFocusIndex].clear();
                        _pinFocusNodes[_currentFocusIndex].requestFocus();
                      }
                    }
                  },
                  child: TextField(
                    controller: _pinControllers[index],
                    focusNode: _pinFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 24),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      counterText: '',
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        if (index < 3) {
                          setState(() {
                            _currentFocusIndex++;
                          });
                          _pinFocusNodes[_currentFocusIndex].requestFocus();
                        } else {
                          _pinFocusNodes[index].unfocus();
                        }
                      }
                    },
                  ),
                ),
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
                    'Set PIN',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
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
                currentWidget,
                const SizedBox(height: 16),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: () {
                      if (_currentStep == 2) {
                        for (final controller in _pinControllers) {
                          controller.clear();
                        }
                        // Set focus to the first field
                        _pinFocusNodes[0].requestFocus();
                      } else if (_currentStep == 1) {
                        for (final controller in _otpControllers) {
                          controller.clear();
                        }
                        // Set focus to the first field
                        _otpFocusNodes[0].requestFocus();
                      }
                      setState(() {
                        _currentStep--;
                      });
                    },
                    child: Text(
                      'Back',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
