import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/routes/routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mobileController.text = '';
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                // Welcome Text
                const Text(
                  'Welcome to Kiddo Tracker',
                  style: TextStyle(
                    color: Color(0xFF755DC1),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please sign in to continue',
                  style: TextStyle(
                    color: Color(0xFF837E93),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                // Login Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: const TextStyle(
                            color: Color(0xFF755DC1),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(
                            Icons.phone,
                            color: Color(0xFF755DC1),
                          ),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),

                      // Sign In Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              // callAPI();
                              Navigator.pushNamed(
                                context,
                                AppRoutes.otp,
                                arguments: "8456029772",
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please fix the errors in the form',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9F7BFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Next',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void callAPI() {
    setState(() {
      _isLoading = true;
    });

    final mobileNumber = _mobileController.text;
    ApiService.sendOTP(mobileNumber)
        .then((response) {
          setState(() {
            _isLoading = false;
          });

          if (response.statusCode == 200) {
            if (response.data[0]['result'] == 'ok') {
              // Success animation before navigation
              Navigator.pushNamed(
                context,
                AppRoutes.otp,
                arguments: mobileNumber,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${response.data['message']}')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send OTP: ${response.statusMessage}'),
              ),
            );
          }
        })
        .catchError((error) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        });
  }
}
