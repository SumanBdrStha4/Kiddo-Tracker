import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kiddo_tracker/api/api_service.dart';
import 'package:kiddo_tracker/api/apimanage.dart';
import 'package:kiddo_tracker/widget/shareperference.dart';

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

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _changePin() async {
    if (_oldPinController.text.isEmpty ||
        _newPinController.text.isEmpty ||
        _confirmPinController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required')));
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New PIN and confirm PIN do not match')),
      );
      return;
    }

    //app session id
    String? sessionId;
    await Future<void>.delayed(const Duration(milliseconds: 100)).then((
      _,
    ) async {
      sessionId = await SharedPreferenceHelper.getUserSessionId();
    });
    //user id
    String? userId;
    await Future<void>.delayed(const Duration(milliseconds: 100)).then((
      _,
    ) async {
      userId = await SharedPreferenceHelper.getUserNumber();
    });

    ApiManager apiManager = ApiManager();
    Response response = await ApiService.changePin(
      userId!,
      sessionId!,
      _oldPinController.text,
      _newPinController.text,
    );

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to change PIN')));
      return;
    }

    if (response.data['result'] != 'ok') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to change PIN')));
      return;
    }

    // Clear the text fields
    _oldPinController.clear();
    _newPinController.clear();
    _confirmPinController.clear();

    // Hide the keyboard
    FocusScope.of(context).unfocus();

    // TODO: Implement PIN change logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN changed successfully')));
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
