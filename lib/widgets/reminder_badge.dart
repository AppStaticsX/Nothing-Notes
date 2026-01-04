import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Optimized reminder badge widget - only rebuilds when reminder data changes
class ReminderBadge extends StatelessWidget {
  final DateTime? reminderDateTime;
  final bool hasReminder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final dynamic theme;

  const ReminderBadge({
    super.key,
    required this.reminderDateTime,
    required this.hasReminder,
    required this.onTap,
    this.onLongPress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasReminder || reminderDateTime == null) {
      return const SizedBox.shrink();
    }

    final bool isPast = reminderDateTime!.isBefore(DateTime.now());
    final Color badgeColor = isPast ? Colors.red : theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.alarm, size: 14, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              _formatReminderTime(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReminderTime() {
    if (reminderDateTime == null) return '';

    final now = DateTime.now();
    final difference = reminderDateTime!.difference(now);

    if (difference.isNegative) {
      return 'Passed';
    } else if (difference.inMinutes < 60) {
      return 'in ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'in ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Tomorrow ${reminderDateTime!.hour}:${reminderDateTime!.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'in ${difference.inDays}d';
    } else {
      return '${reminderDateTime!.day}/${reminderDateTime!.month}';
    }
  }
}

/// Compact reminder icon for note cards
class ReminderIcon extends StatelessWidget {
  final bool hasReminder;
  final bool isActive;
  final dynamic theme;

  const ReminderIcon({
    super.key,
    required this.hasReminder,
    required this.isActive,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasReminder) {
      return const SizedBox.shrink();
    }

    final Color iconColor = isActive ? theme.primaryColor : Colors.grey;

    return Icon(CupertinoIcons.alarm, size: 16, color: iconColor);
  }
}
