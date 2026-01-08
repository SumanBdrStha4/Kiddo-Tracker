# Unify MQTT Message Handling for Active/Deactivate in Background and Foreground

## Tasks

- [x] Add imports for SqfliteHelper and json in background_service.dart
- [x] Modify onMessageReceived callback to parse JSON messages
- [x] Handle msgtype 2 (onboard): Fetch child name, show notification, save activity
- [x] Handle msgtype 3 (offboard): Fetch child names for offlist, show notifications, save activities
- [x] Handle msgtype 1 (bus activate): Fetch route name, show notification
- [x] Handle msgtype 4 (bus deactivate): Fetch route name, show notification
- [x] Test the changes
