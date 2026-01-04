import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../providers/theme_provider.dart';
import '../widgets/liquid_glass_background.dart';

class LocalAuthSetupScreen extends StatefulWidget {
  const LocalAuthSetupScreen({super.key});

  @override
  State<LocalAuthSetupScreen> createState() => _LocalAuthSetupScreenState();
}

class _LocalAuthSetupScreenState extends State<LocalAuthSetupScreen> {

  int initIndex = 0;

  void newPinOnSuccess() {
    setState(() {
      initIndex++;
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
            const ConfirmPinPage()
          ],
        ),
      ),
    );
  }
}

class NewPinPage extends StatefulWidget {

  final VoidCallback onSuccess;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid PIN Length')));
      return;
    } else {
      widget.onSuccess();
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
  const ConfirmPinPage({super.key});

  @override
  State<ConfirmPinPage> createState() => _ConfirmPinPageState();
}

class _ConfirmPinPageState extends State<ConfirmPinPage> {

  late final TextEditingController _confirmPinController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _confirmPinController = TextEditingController();
  }

  Future<void> _validatePin() async {
    if (_confirmPinController.length < 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid PIN Length')));
      return;
    } else {

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


