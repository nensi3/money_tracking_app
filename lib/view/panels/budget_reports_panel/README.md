# Budget & Reports Panel

The Budget & Reports Panel helps users track their spending against budgets and view detailed financial reports.

## Features

- **Monthly Selection**: Switch between months to view different time periods
- **Monthly Summary**:
  - Total Budget Amount
  - Amount Spent
  - Remaining Amount

- **Budget by Category**:
  - Visual progress bars showing spending vs. budget
  - Percentage spent indicator
  - Color-coded warnings (red >80%, green <80%)
  - All tracked categories at a glance

- **Report Actions**:
  - Export Report: Download financial reports as files
  - Email Summary: Send monthly summary via email

## Files

- `budget_reports_screen.dart` - Main budget tracking and reports interface

## Usage

```dart
import 'lib/panels/budget_reports_panel/budget_reports_screen.dart';

// Navigate to Budget & Reports Panel
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const BudgetReportsPanelScreen()),
);
```

## Data Structure

- Budget data stored as `Map<String, double>` for category-wise budgets
- Spent data stored as `Map<String, double>` for actual spending
- Automatic percentage calculation for visual representation

## Styling

- Uses shared `GlassCard` widget
- Uses `AppGradientBackground` for gradient backdrop
- Month selector tabs with active state indication
- Linear progress indicators for budget visualization
- Color-coded status (green when under budget, red when exceeding)
