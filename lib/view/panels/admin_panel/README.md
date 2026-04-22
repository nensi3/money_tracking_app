# Admin Panel

The Admin Panel provides system administrators with tools to manage users, transactions, view analytics, and configure system settings.

## Features

- **Dashboard Statistics**:
  - Total Users: Display active user count
  - Total Transactions: Show transaction volume
  - Revenue: Display total revenue
  - System Health: Monitor system status

- **Management Actions**:
  - User Management: Add/remove users, manage permissions
  - Approve Transactions: Review and approve pending transactions
  - View Analytics: Access system analytics and reports
  - System Settings: Configure system-wide settings

## Files

- `admin_panel_screen.dart` - Admin dashboard with stats and management tools

## Usage

```dart
import 'lib/panels/admin_panel/admin_panel_screen.dart';

// Navigate to Admin Panel
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
);
```

## Components

- **\_StatCard**: Displays key metrics in a grid format
- **\_AdminAction**: Action buttons for management tasks

## Styling

- Uses shared `GlassCard` widget
- Uses `AppGradientBackground` for consistent backgrounds
- Color-coded stat cards for quick visual identification
- Responsive grid layout
