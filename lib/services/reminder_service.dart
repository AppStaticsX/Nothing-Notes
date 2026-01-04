import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/note.dart';
import 'dart:io';

class ReminderService {
  static final ReminderService instance = ReminderService._init();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  ReminderService._init();

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Get local timezone with fallback
      try {
        final timeZoneName = await FlutterTimezone.getLocalTimezone();
        final timeZoneString = timeZoneName.toString();
        tz.setLocalLocation(tz.getLocation(timeZoneString));
        print('✅ Timezone set to: $timeZoneString');
      } catch (e) {
        // Fallback to UTC if local timezone detection fails
        print(
          '⚠️ Warning: Could not get local timezone ($e), using UTC as fallback',
        );
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android 8.0+
      await _createNotificationChannel();

      // Request permissions (don't fail if permissions are denied)
      try {
        await requestPermissions();
      } catch (e) {
        print('Warning: Could not request notification permissions: $e');
      }

      _initialized = true;
    } catch (e) {
      print('Error initializing ReminderService: $e');
      // DO NOT mark as initialized - allow retry on next call
      // _initialized remains false so next call will retry
      rethrow; // Re-throw to let the caller handle it
    }
  }

  /// Create notification channel for Android 8.0+
  Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'reminders_channel',
          'Reminders',
          description: 'Note reminders and notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        await androidImplementation.createNotificationChannel(channel);
        print('✅ Notification channel created successfully');
      }
    }
  }

  // ============================================================================
  // PERMISSION HANDLING
  // ============================================================================

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        // Request exact alarm permission for Android 12+
        await androidImplementation.requestExactAlarmsPermission();

        // Request notification permission for Android 13+
        final bool? granted = await androidImplementation
            .requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final bool? granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation
            .areNotificationsEnabled();
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final bool? granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  // ============================================================================
  // NOTIFICATION SCHEDULING
  // ============================================================================

  Future<void> scheduleReminder(Note note, int notificationId) async {
    print('📅 Scheduling reminder for note: ${note.title}');
    print('📅 Reminder time: ${note.reminderDateTime}');
    print('📅 Notification ID: $notificationId');

    if (!_initialized) {
      print('📅 Service not initialized, initializing now...');
      await initialize();
    }

    if (note.reminderDateTime == null) {
      throw Exception('Reminder date/time is required');
    }

    // Convert DateTime to TZDateTime
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      note.reminderDateTime!,
      tz.local,
    );

    // Check if the scheduled time is in the future
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      throw Exception('Reminder time must be in the future');
    }

    // Notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          channelDescription: 'Note reminders and notifications',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule the notification
    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Reminder: ${note.title}',
        _getNotificationBody(note),
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: note.id, // Pass note ID as payload
      );

      print('✅ Notification scheduled successfully!');
      print('📅 Notification ID: $notificationId');
      print('📅 Scheduled for: $scheduledDate');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      rethrow;
    }
  }

  Future<void> cancelReminder(int notificationId) async {
    if (!_initialized) await initialize();
    await _notificationsPlugin.cancel(notificationId);
  }

  Future<void> rescheduleReminder(Note note, int notificationId) async {
    if (note.notificationId != null) {
      await cancelReminder(note.notificationId!);
    }
    await scheduleReminder(note, notificationId);
  }

  Future<void> cancelAllReminders() async {
    if (!_initialized) await initialize();
    await _notificationsPlugin.cancelAll();
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  String _getNotificationBody(Note note) {
    final String preview = note.preview;
    if (preview.isEmpty) {
      return 'Tap to view note';
    }
    return preview.length > 100 ? '${preview.substring(0, 100)}...' : preview;
  }

  void _onNotificationTapped(NotificationResponse response) {
    try {
      // Handle notification tap
      // The payload contains the note ID
      final String? noteId = response.payload;
      if (noteId != null) {
        print('📱 Notification tapped for note ID: $noteId');

        // Call the reminder triggered callback (for clearing "once" reminders)
        _reminderTriggeredCallback?.call(noteId);

        // Call the navigation callback (for opening the note)
        _notificationTapCallback?.call(noteId);
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
      // Don't crash the app if callback fails
    }
  }

  // Callback for notification taps (navigation)
  Function(String noteId)? _notificationTapCallback;

  // Callback for when a reminder is triggered (for clearing "once" reminders)
  Function(String noteId)? _reminderTriggeredCallback;

  void setNotificationTapCallback(Function(String noteId) callback) {
    _notificationTapCallback = callback;
  }

  /// Set callback to be called when a reminder is triggered
  /// This is used to automatically clear "once" reminders after they fire
  void setReminderTriggeredCallback(Function(String noteId) callback) {
    _reminderTriggeredCallback = callback;
  }

  /// Test notification - shows immediately to verify notifications work
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          channelDescription: 'Note reminders and notifications',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        999999,
        '✅ Test Notification',
        'If you see this, notifications are working correctly!',
        notificationDetails,
        payload: 'test',
      );
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Error showing test notification: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PENDING NOTIFICATIONS
  // ============================================================================

  Future<List<PendingNotificationRequest>> getPendingReminders() async {
    if (!_initialized) await initialize();
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  Future<int> getPendingRemindersCount() async {
    final List<PendingNotificationRequest> pending =
        await getPendingReminders();
    return pending.length;
  }
}
