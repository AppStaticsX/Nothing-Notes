import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../widgets/custom_snackbar.dart';
import 'home_screen.dart';
import 'lock_screen_state.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const LockScreen({super.key, this.onSuccess});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _storedPin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    LockScreenState.isShown = true;
    _loadPin();
  }

  Future<void> _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storedPin = prefs.getString('user_pin');
      _isLoading = false;
    });
  }

  void _validatePin(String inputPin) {
    if (_storedPin == null) {
      // Should not happen if app lock is enabled, but safety check
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
      return;
    }

    if (inputPin == _storedPin) {
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      _pinController.clear();
      showSnackBar(context, 'Incorrect PIN. Please try again.', Severity.error);
    }
  }

  @override
  void dispose() {
    LockScreenState.isShown = false;
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentAppTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                Icon(Icons.lock_outline, size: 80, color: theme.textColor),
                const SizedBox(height: 36),
                Text(
                  'App Locked',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12,
                  ),
                  child: Text(
                    'Please enter your PIN to unlock.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Pinput(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  obscuringCharacter: '●',
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  defaultPinTheme: PinTheme(
                    width: 64,
                    height: 64,
                    textStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: theme.primaryColor, width: 3),
                    ),
                  ),
                  onCompleted: (pin) {
                    _validatePin(pin);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
