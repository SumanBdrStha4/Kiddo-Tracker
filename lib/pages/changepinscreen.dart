import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';
import 'package:logger/logger.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscureOldPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  String? sessionId = "";
  String? userId = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    sessionId = await SharedPreferenceHelper.getUserSessionId();
    userId = await SharedPreferenceHelper.getUserNumber();
  }

  void _changePin() async {
    if (_oldPinController.text.isEmpty ||
        _newPinController.text.isEmpty ||
        _confirmPinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New PIN and confirm PIN do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Response response = await ApiService.changePin(
      userId!,
      sessionId!,
      _oldPinController.text,
      _newPinController.text,
    );
    if (response.statusCode == 200) {
      Logger().i(response.data);
      if (response.data[0]['result'] == 'ok') {
        // Clear the text fields
        _oldPinController.clear();
        _newPinController.clear();
        _confirmPinController.clear();

        // Hide the keyboard
        FocusScope.of(context).unfocus();

        // TODO: Implement PIN change logic
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${response.data[1]['data']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to change PIN'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _oldPinController,
              obscureText: _obscureOldPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Old PIN',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOldPin ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureOldPin = !_obscureOldPin),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPinController,
              obscureText: _obscureNewPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'New PIN',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPin ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureNewPin = !_obscureNewPin),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPinController,
              obscureText: _obscureConfirmPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Confirm PIN',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPin
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _changePin,
              child: const Text('Change PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
