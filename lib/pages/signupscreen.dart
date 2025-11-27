import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:logger/logger.dart';

class SignUpScreen extends StatefulWidget {
  String? mobile;
  SignUpScreen({super.key, this.mobile});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final Logger logger = Logger();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contactController.text = widget.mobile ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      //call apimanager
      ApiManager()
          .post(
            'ktrackusersignup',
            data: {
              'userid': _contactController.text,
              'name': _nameController.text,
              'city': _cityController.text,
              'state': _stateController.text,
              'address': _addressController.text,
              'contact': _contactController.text,
              'email': _emailController.text,
              'mobile': _mobileController.text,
              'pin': int.parse(_pinController.text),
              'wards': "0",
              'status': "0",
            },
          )
          .then((response) {
            if (response.statusCode == 200) {
              if (response.data[0]['result'] == 'ok') {
                // SharedPreferenceHelper.setUserSessionId(
                //   response.data[1]['sessionid'],
                // );
                //call logout api
                ApiService.logoutUser(
                  _contactController.text,
                  response.data[1]['sessionid'],
                );
                if (response.statusCode == 200) {
                  logger.i(response.toString());
                  if (response.data[0]['result'] == 'ok') {
                    Navigator.pushNamed(context, AppRoutes.pin);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign up successful')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${response.data['message']}'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to logout: ${response.statusMessage}',
                      ),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${response.data['message']}')),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to send OTP: ${response.statusMessage}',
                  ),
                ),
              );
            }
          });
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    IconData? icon,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Create Your Account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'Name',
                          controller: _nameController,
                          icon: Icons.person,
                        ),
                        _buildTextField(
                          label: 'Mobile No.',
                          controller: _contactController,
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone,
                          enabled: false,
                        ),
                        _buildTextField(
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          icon: Icons.email,
                        ),
                        _buildTextField(
                          label: 'Other Number',
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          icon: Icons.phone_android,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: TextFormField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'PIN',
                              prefixIcon: Icon(Icons.lock),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter PIN';
                              }
                              if (value.length != 4) {
                                return 'PIN must be exactly 4 digits';
                              }
                              return null;
                            },
                          ),
                        ),
                        _buildTextField(
                          label: 'Address',
                          controller: _addressController,
                          icon: Icons.home,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'City',
                                controller: _cityController,
                                keyboardType: TextInputType.streetAddress,
                                icon: Icons.location_city,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                label: 'State',
                                controller: _stateController,
                                icon: Icons.map,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(fontSize: 18),
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
