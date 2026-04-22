# User Panel

The User Panel provides a simple dashboard for users to manage their account and view personal information.

## Features

- **Profile Information**: Display user email and unique identifier
- **Quick Actions**:
  - View History: Access transaction history
  - Settings: User preferences and account settings
  - Notifications: View system notifications
  - Support: Contact support team

## Files

- `user_panel_screen.dart` - Main user dashboard screen with profile and quick action buttons

## Usage

```dart
import 'lib/panels/user_panel/user_panel_screen.dart';

// Navigate to User Panel
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const UserPanelScreen()),
);
```

## Styling

- Uses shared `GlassCard` widget for consistent card styling
- Uses `AppGradientBackground` for gradient backdrop
- Uses `AppColors` for color consistency across the app
- Icons from Material Design Icons
