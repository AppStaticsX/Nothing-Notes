import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/liquid_glass_background.dart';

class LocalAuthSetupScreen extends StatefulWidget {
  const LocalAuthSetupScreen({super.key});

  @override
  State<LocalAuthSetupScreen> createState() => _LocalAuthSetupScreenState();
}

class _LocalAuthSetupScreenState extends State<LocalAuthSetupScreen> {

  int initIndex = 0;
  String? pin;

  void newPinOnSuccess(String newPin) {
    setState(() {
      initIndex++;
      pin = newPin;
    });
  }

  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentAppTheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassIconButton(
            icon: CupertinoIcons.chevron_back,
            size: 36,
            iconSize: 20,
            borderRadius: 100,
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enable App Lock',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Protect your personal notes with app lock',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: IndexedStack(
          index: initIndex,
          children: [
            NewPinPage(onSuccess: newPinOnSuccess),
            ConfirmPinPage(newPin: pin ?? '')
          ],
        ),
      ),
    );
  }
}

class NewPinPage extends StatefulWidget {

  final Function(String) onSuccess;

  const NewPinPage({
    super.key,
    required this.onSuccess
  });

  @override
  State<NewPinPage> createState() => _NewPinPageState();
}

class _NewPinPageState extends State<NewPinPage> {

  late final TextEditingController _newPinController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _newPinController = TextEditingController();
  }

  Future<void> _validatePin() async {
    if (_newPinController.length < 4) {
      showSnackBar(
          context,
          'Invalid PIN Length.',
          Severity.warning
      );
      return;
    } else {
      widget.onSuccess(_newPinController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentAppTheme;

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                Icon(Icons.lock, size: 80),
                const SizedBox(height: 36,),
                Text(
                  'Setup New PIN',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                  child: Text(
                    'Please enter your PIN here to continue app lock setup.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                      color: theme.textColor
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Pinput(
                  controller: _newPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  obscuringCharacter: '●',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // Only allows digits
                  ],
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
                      border: Border.all(color: theme.primaryColor, width: 3)
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    _validatePin();
                  },
                  label: Icon(Icons.arrow_forward),
                  style: OutlinedButton.styleFrom(
                    elevation: 0,
                    shape: CircleBorder(),
                    fixedSize: Size(72, 72),
                    iconSize: 36,
                    iconColor: theme.textColor,
                    padding: EdgeInsets.zero
                  ),
                ),
                const Spacer()
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConfirmPinPage extends StatefulWidget {

  final String newPin;

  const ConfirmPinPage({
    super.key,
    required this.newPin
  });

  @override
  State<ConfirmPinPage> createState() => _ConfirmPinPageState();
}

class _ConfirmPinPageState extends State<ConfirmPinPage> {

  late final TextEditingController _confirmPinController;

  bool _isDisabled = true;

  @override
  void initState() {
    super.initState();
    _confirmPinController = TextEditingController();
    _confirmPinController.addListener(_onPinChanged);
  }

  void _onPinChanged() {
    setState(() {
      _isDisabled = _confirmPinController.text.length < 4;
    });
  }

  Future<void> _validatePin() async {
    if (_confirmPinController.text != widget.newPin) {
      showSnackBar(
          context,
          'PINs do not match. Please try again.',
          Severity.error
      );
      _confirmPinController.clear();
      return;
    } else {
      setState(() {
        _isDisabled = false;
      });
    }
  }

  Future<void> _savePIN() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save the PIN
      await prefs.setString('user_pin', widget.newPin);

      // Save app lock enabled status
      await prefs.setBool('app_lock_enabled', true);

      if (mounted) {
        showSnackBar(context, 'App lock enabled successfully!', Severity.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to save PIN: ${e.toString()}', Severity.error);
      }
    }
  }

  @override
  void dispose() {
    _confirmPinController.removeListener(_onPinChanged);
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentAppTheme;

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                Icon(Icons.lock, size: 80),
                const SizedBox(height: 36,),
                Text(
                  'Confirm Your PIN',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                  child: Text(
                    'Please enter your PIN again here to finish app lock setup.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: theme.textColor
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Pinput(
                  controller: _confirmPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  obscuringCharacter: '●',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // Only allows digits
                  ],
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
                        border: Border.all(color: theme.primaryColor, width: 3)
                    ),
                  ),
                  onCompleted: (pin) {
                    _validatePin();
                  },
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _isDisabled ? null : () async {
                    await _savePIN();
                  },
                  label: Icon(Icons.power_settings_new),
                  style: OutlinedButton.styleFrom(
                      elevation: 0,
                      shape: CircleBorder(),
                      fixedSize: Size(72, 72),
                      iconSize: 36,
                      iconColor: _isDisabled ? theme.secondaryTextColor : theme.textColor,
                      padding: EdgeInsets.zero,
                      disabledIconColor: theme.secondaryTextColor
                  ),
                ),
                const Spacer()
              ],
            ),
          ),
        ),
      ),
    );
  }
}


