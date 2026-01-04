import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for exporting notes to various formats
class PlainTextExportService {

  /// Export note as plain text file
  static Future<void> exportAsPlainText({
    required String title,
    required quill.QuillController controller,
    required BuildContext context,
  }) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Generating text file...'),
              ],
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Get plain text content
      final plainText = controller.document.toPlainText();

      // Create file content with title and metadata
      final content = '''
$title

Exported on ${_formatDateTime(DateTime.now())}
----------------------------------------

$plainText
''';

      // Get save directory
      final directory = await _getSaveDirectory();
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create filename
      final sanitizedTitle = _sanitizeFilename(title);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${sanitizedTitle}_$timestamp.txt';
      final filePath = '${directory.path}/$filename';

      // Save text file
      final file = File(filePath);
      await file.writeAsString(content);

      // Share or show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await _showExportSuccess(
          context: context,
          filePath: filePath,
          format: 'Text',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export text: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Text Export Error: $e');
    }
  }

  /// Get appropriate save directory based on platform
  static Future<Directory?> _getSaveDirectory() async {
    try {
      if (Platform.isAndroid) {
        // For Android 10+ (API 29+), use scoped storage
        // We'll save to app-specific external storage which doesn't require permissions
        final directory = await getExternalStorageDirectory();

        if (directory != null) {
          // Create a Documents/Notes folder in app-specific storage
          // Path will be: /storage/emulated/0/Android/data/com.yourapp/files/Documents/Notes
          final notesDir = Directory('${directory.path}/Documents/Notes');
          if (!await notesDir.exists()) {
            await notesDir.create(recursive: true);
          }
          return notesDir;
        }

        // Fallback to app documents directory
        return await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        // For iOS, use application documents directory
        final directory = await getApplicationDocumentsDirectory();
        final notesDir = Directory('${directory.path}/Exports');
        if (!await notesDir.exists()) {
          await notesDir.create(recursive: true);
        }
        return notesDir;
      } else {
        // For other platforms (Desktop), use downloads directory
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final notesDir = Directory('${directory.path}/Notes');
          if (!await notesDir.exists()) {
            await notesDir.create(recursive: true);
          }
          return notesDir;
        }
        return await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      // Fallback to application documents directory
      debugPrint('Directory Error: $e');
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Show export success dialog with share options
  static Future<void> _showExportSuccess({
    required BuildContext context,
    required String filePath,
    required String format,
  }) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('File Exported', overflow: TextOverflow.ellipsis),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$format file has been saved successfully!'),
            const SizedBox(height: 12),
            const Text(
              'Location:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filePath,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How would you like to share?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'close'),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'share_file'),
            icon: const Icon(Icons.insert_drive_file, size: 18),
            label: const Text('Share File'),
          ),
        ],
      ),
    );

    if (result == 'share_file') {
      // Share the actual file (PDF/TXT/MD)
      try {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Exported Note - $format',
          text: 'Here\'s my exported note',
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to share file: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Sanitize filename by removing invalid characters
  static String _sanitizeFilename(String filename) {
    // Remove invalid filename characters
    String sanitized = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    // Remove leading/trailing dots and underscores
    sanitized = sanitized.replaceAll(RegExp(r'^[._]+|[._]+$'), '');

    // Limit length
    if (sanitized.length > 50) {
      sanitized = sanitized.substring(0, 50);
    }

    return sanitized.isEmpty ? 'note' : sanitized;
  }

  /// Format DateTime to readable string
  static String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day $month $year at $hour:$minute';
  }

  /// Export note as Markdown (bonus feature)
  static Future<void> exportAsMarkdown({
    required String title,
    required quill.QuillController controller,
    required BuildContext context,
  }) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Generating Markdown...'),
              ],
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Convert Quill document to Markdown
      final markdown = _convertToMarkdown(controller.document);

      // Create file content
      final content = '''# $title

*Exported on ${_formatDateTime(DateTime.now())}*

---

$markdown
''';

      // Get save directory
      final directory = await _getSaveDirectory();
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create filename
      final sanitizedTitle = _sanitizeFilename(title);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${sanitizedTitle}_$timestamp.md';
      final filePath = '${directory.path}/$filename';

      // Save markdown file
      final file = File(filePath);
      await file.writeAsString(content);

      // Share or show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await _showExportSuccess(
          context: context,
          filePath: filePath,
          format: 'Markdown',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Markdown: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Markdown Export Error: $e');
    }
  }


  /// Convert Quill document to Markdown format
  static String _convertToMarkdown(quill.Document document) {
    final buffer = StringBuffer();
    final delta = document.toDelta();
    bool inList = false;

    for (final op in delta.toList()) {
      if (op.data is String) {
        String text = op.data as String;
        final attributes = op.attributes;

        if (attributes != null) {
          // Handle headers first
          if (attributes['header'] != null) {
            final level = attributes['header'] as int;
            buffer.write('${'#' * level} ');
          }

          // Handle lists
          if (attributes['list'] == 'bullet') {
            buffer.write('- ');
            inList = true;
          } else if (attributes['list'] == 'ordered') {
            buffer.write('1. ');
            inList = true;
          } else if (attributes['list'] == 'checked') {
            buffer.write('- [x] ');
            inList = true;
          } else if (attributes['list'] == 'unchecked') {
            buffer.write('- [ ] ');
            inList = true;
          } else {
            inList = false;
          }

          // Handle text formatting
          if (attributes['bold'] == true) {
            text = '**$text**';
          }
          if (attributes['italic'] == true) {
            text = '*$text*';
          }
          if (attributes['underline'] == true) {
            text = '<u>$text</u>';
          }
          if (attributes['strike'] == true) {
            text = '~~$text~~';
          }
          if (attributes['code'] == true) {
            text = '`$text`';
          }
          if (attributes['link'] != null) {
            text = '[$text](${attributes['link']})';
          }

          // Handle code blocks
          if (attributes['code-block'] == true) {
            buffer.write('```\n$text\n```');
            continue;
          }

          // Handle blockquotes
          if (attributes['blockquote'] == true) {
            buffer.write('> ');
          }
        }

        buffer.write(text);
      }
    }

    return buffer.toString();
  }
}
