import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:notes_app/services/reminder_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_theme.dart';
import 'providers/notes_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'widgets/app_lifecycle_manager.dart';
import 'utils/globals.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload custom fonts
  SettingsProvider settingsProvider = SettingsProvider();
  await settingsProvider.loadSavedCustomFont();

  // Preload theme settings to prevent font flash
  final prefs = await SharedPreferences.getInstance();
  final themeName = prefs.getString('theme') ?? 'OLED Black';
  final appFontFamily = prefs.getString('appFontFamily') ?? 'Nothing Font';

  final initialTheme = AppTheme.allThemes.firstWhere(
    (theme) => theme.name == themeName,
    orElse: () => AppTheme.oledBlack,
  );

  // Initialize reminder service for notifications
  try {
    await ReminderService.instance.initialize();
  } catch (e) {
    // App can still function without reminders
  }

  // Check for app lock status
  final isAppLocked = prefs.getBool('app_lock_enabled') ?? false;

  runApp(
    MyApp(
      initialTheme: initialTheme,
      initialFontFamily: appFontFamily,
      isAppLocked: isAppLocked,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppTheme initialTheme;
  final String initialFontFamily;
  final bool isAppLocked;

  const MyApp({
    super.key,
    required this.initialTheme,
    required this.initialFontFamily,
    required this.isAppLocked,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            initialTheme: initialTheme,
            initialFontFamily: initialFontFamily,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final notesProvider = NotesProvider()..loadNotes();

            // Set up reminder triggered callback to auto-clear "once" reminders
            ReminderService.instance.setReminderTriggeredCallback((
              noteId,
            ) async {
              await notesProvider.clearTriggeredOnceReminder(noteId);
            });

            return notesProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: MaterialApp(
              navigatorKey: navigatorKey, // Add navigatorKey
              builder: (context, child) {
                return AppLifecycleManager(child: child!);
              },
              title: 'Nothing Notes',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.currentTheme,
              home: isAppLocked ? const LockScreen() : const HomeScreen(),

              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                quill.FlutterQuillLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en', 'US')],
            ),
          );
        },
      ),
    );
  }
}
