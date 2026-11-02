import 'package:flutter/material.dart';

import '../screens/budget_settings_screen.dart';
import '../screens/review_uncertain_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/upload_screen.dart';

/// Where a notification leads. The backend stores the destination as a short name.
enum NotificationDestination { budgetSettings, reviewUncertain, transactions, upload, dashboard, none }

NotificationDestination destinationFor(String? action) {
  switch (action) {
    case 'budget_settings':
      return NotificationDestination.budgetSettings;
    case 'review_uncertain':
      return NotificationDestination.reviewUncertain;
    case 'transactions':
      return NotificationDestination.transactions;
    case 'upload':
      return NotificationDestination.upload;
    case 'dashboard':
      return NotificationDestination.dashboard;
    default:
      return NotificationDestination.none;
  }
}

/// Opens the screen a notification points to. The dashboard is already underneath the Activity Centre,
/// so for it (or for no destination) the Activity Centre just closes.
void openNotificationAction(BuildContext context, String? action) {
  Widget? screen;
  switch (destinationFor(action)) {
    case NotificationDestination.budgetSettings:
      screen = const BudgetSettingsScreen();
    case NotificationDestination.reviewUncertain:
      screen = const ReviewUncertainScreen();
    case NotificationDestination.transactions:
      screen = const TransactionsScreen();
    case NotificationDestination.upload:
      screen = const UploadScreen();
    case NotificationDestination.dashboard:
    case NotificationDestination.none:
      screen = null;
  }
  if (screen == null) {
    Navigator.of(context).maybePop();
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
}
