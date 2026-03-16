// core/utils/app_lifecycle_observer.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  static final AppLifecycleObserver _instance = AppLifecycleObserver._internal();
  
  factory AppLifecycleObserver() {
    return _instance;
  }
  
  AppLifecycleObserver._internal();

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _updateSessionTimestamp();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _updateSessionTimestamp();
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.detached) {
      // App went to background or closed
      // The timestamp will help determine if app was truly closed
    }
  }

  Future<void> _updateSessionTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('last_app_session_timestamp', currentTimestamp);
    } catch (e) {
      debugPrint('Error updating session timestamp: $e');
    }
  }
}