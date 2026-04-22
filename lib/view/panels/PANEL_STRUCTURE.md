# Flutter Money Tracking App - Panel Structure

This document outlines the 3-panel architecture for the Flutter Money Tracking application.

## Overview

The app is organized into three main panels, each serving a distinct purpose:

### 1. **User Panel** (`lib/panels/user_panel/`)

- **Purpose**: Manage personal account and preferences
- **Key Features**:
  - Profile information display
  - Quick action shortcuts (history, settings, notifications, support)
- **Main File**: `user_panel_screen.dart`

### 2. **Admin Panel** (`lib/panels/admin_panel/`)

- **Purpose**: System administration and analytics
- **Key Features**:
  - Dashboard statistics (users, transactions, revenue, system health)
  - User management
  - Transaction approval
  - Analytics viewing
  - System configuration
- **Main File**: `admin_panel_screen.dart`

### 3. **Budget & Reports Panel** (`lib/panels/budget_reports_panel/`)

- **Purpose**: Track spending and generate financial reports
- **Key Features**:
  - Monthly budget selection
  - Budget vs. actual summary
  - Category-wise budget tracking
  - Export and email reports
- **Main File**: `budget_reports_screen.dart`

## Accessing the Panels

Use the **Panels Dashboard** to switch between panels:

```dart
// From any screen, navigate to the unified panels dashboard
import 'lib/screens/panels_dashboard_screen.dart';

Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const PanelsDashboardScreen()),
);
```

Or navigate directly to individual panels:

```dart
import 'lib/panels/user_panel/user_panel_screen.dart';
import 'lib/panels/admin_panel/admin_panel_screen.dart';
import 'lib/panels/budget_reports_panel/budget_reports_screen.dart';

// Navigate to User Panel
Navigator.push(context, MaterialPageRoute(builder: (_) => const UserPanelScreen()));

// Navigate to Admin Panel
Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));

// Navigate to Budget Panel
Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetReportsPanelScreen()));
```

## Shared UI Components

All panels use shared utilities for consistent styling:

- **`AppGradientBackground`**: Provides gradient background throughout the app
- **`GlassCard`**: Reusable card widget with glass-morphism styling
- **`AppColors`**: Centralized color palette (wallet accent, gradients, etc.)

## File Structure

```
lib/
├── panels/
│   ├── user_panel/
│   │   ├── user_panel_screen.dart
│   │   └── README.md
│   ├── admin_panel/
│   │   ├── admin_panel_screen.dart
│   │   └── README.md
│   └── budget_reports_panel/
│       ├── budget_reports_screen.dart
│       └── README.md
├── screens/
│   └── panels_dashboard_screen.dart   # Main panel switcher
├── widgets/
│   ├── glass_card.dart
│   ├── auth_form_card.dart
│   └── app_gradient_background.dart
├── utils/
│   ├── app_colors.dart
│   ├── category_ui.dart
│   └── app_input_decorations.dart
└── ...
```

## Extending the Panels

To add new functionality to a panel:

1. Create new screen files in the panel directory
2. Add new widgets as needed
3. Use shared `GlassCard`, `AppGradientBackground`, and `AppColors` for consistent styling
4. Update panel navigation if adding new routes

## API Integration Notes

Currently, panels use mock data for demonstration. To integrate with your Firebase backend:

1. **User Panel**: Fetch user data from `FirebaseAuth.instance.currentUser`
2. **Admin Panel**: Implement queries to get user count, transaction count from Firestore
3. **Budget Panel**: Integrate with existing `FirestoreService` and `BudgetService`

Example integration:

```dart
final user = FirebaseAuth.instance.currentUser;
final transactions = await FirestoreService().getTransactions();
```
