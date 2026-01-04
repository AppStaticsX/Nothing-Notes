import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';

class ReminderPickerScreen extends StatefulWidget {
  final String noteId;

  const ReminderPickerScreen({super.key, required this.noteId});

  @override
  State<ReminderPickerScreen> createState() => _ReminderPickerScreenState();
}

class _ReminderPickerScreenState extends State<ReminderPickerScreen> {
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    // Get initial values from the note
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final note = notesProvider.notes.firstWhere(
      (n) => n.id == widget.noteId,
      orElse: () {
        // Note not found, close the screen after build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note not found')),
            );
          }
        });
        // Return a dummy note to prevent null issues
        return Note(
          id: widget.noteId,
          title: '',
          content: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      },
    );

    _selectedDateTime =
        note.reminderDateTime ?? DateTime.now().add(const Duration(days: 1));
    // Set time to 9:00 AM if it's a new reminder
    if (note.reminderDateTime == null) {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        9,
        0,
      );
    }
  }

  void _resetToDefault() {
    setState(() {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      _selectedDateTime = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        9,
        0,
      );
    });
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDateTime = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  void _onTimeChanged(TimeOfDay newTime) {
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        newTime.hour,
        newTime.minute,
      );
    });
  }


  Future<void> _onConfirm() async {
    if (_selectedDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set the reminder directly
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    try {
      await notesProvider.setNoteReminder(
        widget.noteId,
        _selectedDateTime,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme once with listen: false to prevent rebuilds
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    // Get font family from settings
    final fontFamily = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).fontFamily;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const _DragHandle(),

            // Header
            _Header(textColor: theme.textColor),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Date picker - only rebuilds when date changes
                    _DatePickerSection(
                      selectedDateTime: _selectedDateTime,
                      theme: theme,
                      fontFamily: fontFamily,
                      onDateChanged: _onDateChanged,
                    ),

                    const SizedBox(height: 24),

                    // Time picker - only rebuilds when time changes
                    _TimePickerSection(
                      selectedDateTime: _selectedDateTime,
                      theme: theme,
                      fontFamily: fontFamily,
                      onTimeChanged: _onTimeChanged,
                    ),

                    const SizedBox(height: 24),

                    // Action buttons - static widget with stable callbacks
                    _ActionButtons(
                      theme: theme,
                      onReset: _resetToDefault,
                      onConfirm: _onConfirm,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXTRACTED WIDGETS - Prevent unnecessary rebuilds
// ============================================================================

/// Drag handle widget - doesn't rebuild
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Header widget with title and close button
class _Header extends StatelessWidget {
  final Color textColor;

  const _Header({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Set Reminder',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Iconsax.close_circle_copy, color: textColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Date picker section - only rebuilds when selectedDateTime changes
class _DatePickerSection extends StatelessWidget {
  final DateTime selectedDateTime;
  final dynamic theme;
  final String fontFamily;
  final Function(DateTime) onDateChanged;

  const _DatePickerSection({
    required this.selectedDateTime,
    required this.theme,
    required this.fontFamily,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Date', textColor: theme.secondaryTextColor),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.secondaryTextColor.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: EasyDateTimeLine(
            initialDate: selectedDateTime,
            onDateChange: onDateChanged,
            activeColor: theme.primaryColor,
            headerProps: EasyHeaderProps(
              monthPickerType: MonthPickerType.switcher,
              dateFormatter: const DateFormatter.fullDateDMY(),
              monthStyle: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
              ),
              selectedDateStyle: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontFamily: fontFamily,
              ),
            ),
            dayProps: EasyDayProps(
              height: 56,
              width: 56,
              dayStructure: DayStructure.dayStrDayNum,
              activeDayStyle: DayStyle(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.primaryColor,
                ),
                dayNumStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                ),
                dayStrStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: fontFamily,
                ),
              ),
              inactiveDayStyle: DayStyle(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.cardColor,
                ),
                dayNumStyle: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.7),
                  fontSize: 18,
                  fontFamily: fontFamily,
                ),
                dayStrStyle: TextStyle(
                  color: theme.secondaryTextColor.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFamily: fontFamily,
                ),
              ),
              todayStyle: DayStyle(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.primaryColor,
                    width: 2,
                  ),
                ),
                dayNumStyle: TextStyle(
                  color: theme.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                ),
                dayStrStyle: TextStyle(
                  color: theme.textColor,
                  fontSize: 12,
                  fontFamily: fontFamily,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Time picker section - only rebuilds when selectedDateTime changes
class _TimePickerSection extends StatelessWidget {
  final DateTime selectedDateTime;
  final dynamic theme;
  final String fontFamily;
  final Function(TimeOfDay) onTimeChanged;

  const _TimePickerSection({
    required this.selectedDateTime,
    required this.theme,
    required this.fontFamily,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final TimeOfDay currentTime = TimeOfDay.fromDateTime(selectedDateTime);
    final hour = currentTime.hourOfPeriod == 0 ? 12 : currentTime.hourOfPeriod;
    final minute = currentTime.minute;
    final isPM = currentTime.period == DayPeriod.pm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Time', textColor: theme.secondaryTextColor),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.secondaryTextColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour picker
              _TimeUnit(
                value: hour,
                theme: theme,
                fontFamily: fontFamily,
                onIncrement: () {
                  int newHour = hour + 1;
                  if (newHour > 12) newHour = 1;
                  final totalHour = isPM
                      ? (newHour == 12 ? 12 : newHour + 12)
                      : (newHour == 12 ? 0 : newHour);
                  onTimeChanged(TimeOfDay(hour: totalHour, minute: minute));
                },
                onDecrement: () {
                  int newHour = hour - 1;
                  if (newHour < 1) newHour = 12;
                  final totalHour = isPM
                      ? (newHour == 12 ? 12 : newHour + 12)
                      : (newHour == 12 ? 0 : newHour);
                  onTimeChanged(TimeOfDay(hour: totalHour, minute: minute));
                },
              ),

              // Colon separator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ),

              // Minute picker
              _TimeUnit(
                value: minute,
                theme: theme,
                fontFamily: fontFamily,
                onIncrement: () {
                  int newMinute = minute + 1;
                  if (newMinute > 59) newMinute = 0;
                  onTimeChanged(TimeOfDay(hour: currentTime.hour, minute: newMinute));
                },
                onDecrement: () {
                  int newMinute = minute - 1;
                  if (newMinute < 0) newMinute = 59;
                  onTimeChanged(TimeOfDay(hour: currentTime.hour, minute: newMinute));
                },
              ),

              const SizedBox(width: 16),

              // AM/PM toggle
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.secondaryTextColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        if (isPM) {
                          // Switch to AM
                          int newHour = currentTime.hour - 12;
                          if (newHour < 0) newHour = 0;
                          onTimeChanged(TimeOfDay(hour: newHour, minute: minute));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: !isPM
                              ? theme.primaryColor
                              : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          'AM',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily,
                            color: !isPM
                                ? Colors.white
                                : theme.secondaryTextColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 1,
                      color: theme.secondaryTextColor.withValues(alpha: 0.3),
                    ),
                    InkWell(
                      onTap: () {
                        if (!isPM) {
                          // Switch to PM
                          int newHour = currentTime.hour + 12;
                          if (newHour >= 24) newHour = 12;
                          onTimeChanged(TimeOfDay(hour: newHour, minute: minute));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isPM
                              ? theme.primaryColor
                              : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          'PM',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: fontFamily,
                            color: isPM
                                ? Colors.white
                                : theme.secondaryTextColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section label - reusable static widget
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color textColor;

  const _SectionLabel({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }
}

/// Time unit widget for hour/minute picker with increment/decrement buttons
class _TimeUnit extends StatelessWidget {
  final int value;
  final dynamic theme;
  final String fontFamily;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _TimeUnit({
    required this.value,
    required this.theme,
    required this.fontFamily,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onIncrement,
          child: Container(
            padding: const EdgeInsets.all(0),
            child: Icon(
              Iconsax.arrow_up_2_copy,
              size: 20,
              color: theme.textColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 100,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
              fontFamily: fontFamily,
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onDecrement,
          child: Container(
            padding: const EdgeInsets.all(0),
            child: Icon(
              Iconsax.arrow_down_1_copy,
              size: 20,
              color: theme.textColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Action buttons - never rebuilds (callbacks are stable)
class _ActionButtons extends StatelessWidget {
  final dynamic theme;
  final VoidCallback onReset;
  final VoidCallback onConfirm;

  const _ActionButtons({
    required this.theme,
    required this.onReset,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryColor,
              side: BorderSide(color: theme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: theme.secondaryTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: const Text('Set'),
          ),
        ),
      ],
    );
  }
}
