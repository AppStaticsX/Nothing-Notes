import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/lock_screen.dart';
import '../screens/lock_screen_state.dart';
import '../utils/globals.dart';

class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAppLock();
    }
  }

  Future<void> _checkAppLock() async {
    // If the lock screen is already shown, do nothing.
    if (LockScreenState.isShown) return;

    final prefs = await SharedPreferences.getInstance();
    final isAppLockEnabled = prefs.getBool('app_lock_enabled') ?? false;

    if (isAppLockEnabled) {
      // Use the global navigator key to push the lock screen.
      // We push it as a full-screen modal that pops itself on success.
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => LockScreen(
            onSuccess: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
