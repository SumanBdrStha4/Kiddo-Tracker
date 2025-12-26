import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/model/parent.dart';
import 'package:kiddo_tracker/routes/routes.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:logger/logger.dart';

class SignUpScreen extends StatefulWidget {
  final String? mobile;
  const SignUpScreen({super.key, this.mobile});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final Logger logger = Logger();
  final _formKey = GlobalKey<FormState>();
  late Future<List<dynamic>> stateList;
  final SqfliteHelper _sqfliteHelper = SqfliteHelper();

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
    stateList = fetchStateList();
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

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      //use ApiService
      await ApiService.SignUpUser(
        _contactController.text,
        _nameController.text,
        _cityController.text,
        _stateController.text,
        _addressController.text,
        _mobileController.text,
        _emailController.text,
        _contactController.text,
        int.parse(_pinController.text),
      ).then((response) async {
        if (response.statusCode == 200) {
          if (response.data[0]['result'] == 'ok') {
            // SharedPreferenceHelper.setUserSessionId(
            //   response.data[1]['sessionid'],
            // );
            //get the session
            String sessionID = response.data[1]['sessionid'];
            //save the user information
            //await _sqfliteHelper.insertUser(parent);
            Parent parent = Parent(
              userid: _contactController.text,
              name: _nameController.text,
              city: _cityController.text,
              state: _stateController.text,
              address: _addressController.text,
              contact: _contactController.text,
              email: _emailController.text,
              mobile: _mobileController.text,
              wards: 0,
              status: 1,
              pin: int.parse(_pinController.text),
            );
            await _sqfliteHelper.insertUser(parent);
            await SharedPreferenceHelper.setUserSessionId(sessionID);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Sign up successful')));
            //call logout api
            await ApiService.logoutUser(_contactController.text, sessionID);
            if (response.statusCode == 200) {
              logger.i(response.toString());
              if (response.data[0]['result'] == 'ok') {
                Navigator.pushNamed(context, AppRoutes.pin);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Logout Response: ${response.data['message']}',
                    ),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to logout: ${response.statusMessage}'),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('SignUp response: ${response.data['message']}'),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to SignUp: ${response.statusMessage}'),
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
                              child: FutureBuilder<List<dynamic>>(
                                future: stateList,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  } else if (snapshot.hasError) {
                                    return Text('Error: ${snapshot.error}');
                                  } else if (snapshot.hasData) {
                                    final states = snapshot.data!;
                                    return DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'State',
                                        prefixIcon: Icon(Icons.map),
                                        border: OutlineInputBorder(),
                                      ),
                                      initialValue:
                                          _stateController.text.isNotEmpty
                                          ? _stateController.text
                                          : null,
                                      items: states
                                          .map<DropdownMenuItem<String>>((
                                            state,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: state['state'],
                                              child: Text(state['state']),
                                            );
                                          })
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _stateController.text = value ?? '';
                                        });
                                      },
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                          ? 'Please select a state'
                                          : null,
                                    );
                                  } else {
                                    return const Text('No states available');
                                  }
                                },
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

  Future<List<dynamic>> fetchStateList() async {
    try {
      final response = await ApiService.getStateList();
      if (response.statusCode == 200 &&
          response.data is List &&
          response.data.length > 1) {
        return response.data[1]['data'] as List<dynamic>;
      } else {
        throw Exception('Failed to load state list');
      }
    } catch (e) {
      logger.e('Error fetching state list: $e');
      return [];
    }
  }
}
