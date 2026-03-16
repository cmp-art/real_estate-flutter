import 'package:flutter/material.dart';
import '../../../../core/utils/snackbar_utils.dart';

class RateUsHandler {
  static void openAppStore(BuildContext context) {
    // In a real app, this would open the appropriate app store
    // For now, just show a message
    SnackbarUtils.showInfo(
      context,
      'This would open the app store for rating',
    );
  }
}