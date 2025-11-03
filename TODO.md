# TODO: Update ForgetPINScreen

## Steps to Complete

- [x] Create lib/pages/forgetpinscreen.dart: Implement a StatefulWidget with mobile number input field and a "Send OTP" button that navigates to the OTP screen.
- [x] Update lib/pages/pinscreen.dart: Change the "Forgot PIN?" button navigation from '/otp' to '/forgetpin'.
- [x] Verify routes and ensure no errors in navigation.
- [x] Update ForgetPINScreen to include progressive UI: mobile input -> OTP input -> PIN input -> navigate to PIN screen.
- [x] Add OTP input fields (6 digits) after mobile success.
- [x] Add PIN input fields (4 digits) after OTP success.
- [x] Implement logic to verify OTP and set new PIN.
- [x] Navigate to PIN screen after PIN is set successfully.
