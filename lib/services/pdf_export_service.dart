import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';

/// Service for exporting notes to PDF format with rich text formatting
class PdfExportService {
  /// Export note as PDF file
  static Future<void> exportAsPdf({
    required String title,
    required quill.QuillController controller,
    required BuildContext context,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
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
                Text('Generating PDF...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get save directory first
      final directory = await _getSaveDirectory();
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create filename
      final sanitizedTitle = _sanitizeFilename(title);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${sanitizedTitle}_$timestamp.pdf';
      final filePath = '${directory.path}/$filename';

      // Create a new PDF document
      final pdf = pw.Document();

      // Convert Quill Delta to PDF with rich formatting
      final delta = controller.document.toDelta();

      // Parse the delta manually to create formatted text widgets
      List<pw.Widget> formattedWidgets = [];
      try {
        formattedWidgets = await _convertDeltaToWidgets(delta);
      } catch (e) {
        debugPrint('Error converting formatted content: $e');
        // Fallback to plain text if formatting fails
        final plainText = controller.document.toPlainText();
        formattedWidgets = [
          pw.Text(
            plainText,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            textAlign: pw.TextAlign.left,
          ),
        ];
      }

      // Create a single combined page with title, metadata, and formatted content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [
            // Title
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),

            // Metadata section
            pw.Row(
              children: [
                if (category != null) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'Category: $category',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),

            pw.SizedBox(height: 8),

            // Timestamps
            pw.Text(
              'Created: ${_formatDateTime(createdAt ?? DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Updated: ${_formatDateTime(updatedAt ?? DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Exported: ${_formatDateTime(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),

            pw.SizedBox(height: 24),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 24),

            // Add formatted content directly after the divider
            ...formattedWidgets,
          ],
        ),
      );

      // Save the PDF document
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Share or show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await _showExportSuccess(
          context: context,
          filePath: filePath,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('PDF Export Error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
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
          final notesDir = Directory('${directory.path}/Documents/Notes/PDFs');
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
        final notesDir = Directory('${directory.path}/Exports/PDFs');
        if (!await notesDir.exists()) {
          await notesDir.create(recursive: true);
        }
        return notesDir;
      } else {
        // For other platforms (Desktop), use downloads directory
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final notesDir = Directory('${directory.path}/Notes/PDFs');
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

  /// Show export success dialog with share and open options
  static Future<void> _showExportSuccess({
    required BuildContext context,
    required String filePath,
  }) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('PDF Exported', overflow: TextOverflow.ellipsis),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PDF file has been saved successfully!'),
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
              'What would you like to do?',
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
            onPressed: () => Navigator.pop(context, 'open'),
            icon: const Icon(CupertinoIcons.eye, size: 18),
            label: const Text('Open PDF'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'share'),
            icon: const Icon(CupertinoIcons.share, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
    );

    if (result == 'share') {
      // Share the PDF file
      try {
        final xFile = XFile(filePath);
        await SharePlus.instance.share(
          ShareParams(
            subject: 'Exported Note - PDF',
            text: 'Here\'s my exported note in PDF format',
            files: [xFile]
          )
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
    } else if (result == 'open') {
      // Open the PDF file with default viewer
      try {
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open PDF: ${result.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open file: ${e.toString()}'),
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

  /// Convert Quill Delta to formatted PDF widgets
  static Future<List<pw.Widget>> _convertDeltaToWidgets(dynamic delta) async {
    final widgets = <pw.Widget>[];
    final spans = <pw.InlineSpan>[];

    for (final op in delta.toList()) {
      if (op.data is String) {
        String text = op.data as String;
        final attributes = op.attributes;

        // Handle line breaks
        if (text.contains('\n')) {
          // Split by newlines and process each part
          final parts = text.split('\n');
          for (int i = 0; i < parts.length; i++) {
            if (parts[i].isNotEmpty) {
              spans.add(_createTextSpan(parts[i], attributes));
            }

            // Add the accumulated spans as a paragraph if we hit a newline
            if (i < parts.length - 1 || text.endsWith('\n')) {
              if (spans.isNotEmpty) {
                widgets.add(
                  pw.RichText(
                    text: pw.TextSpan(
                      children: List.from(spans),
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ),
                );
                spans.clear();
              }

              // Add spacing between paragraphs
              if (i < parts.length - 1) {
                widgets.add(pw.SizedBox(height: 8));
              }
            }
          }
        } else {
          spans.add(_createTextSpan(text, attributes));
        }
      }
    }

    // Add any remaining spans
    if (spans.isNotEmpty) {
      widgets.add(
        pw.RichText(
          text: pw.TextSpan(
            children: spans,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
      );
    }

    return widgets;
  }

  /// Create a text span with formatting based on Quill attributes
  static pw.InlineSpan _createTextSpan(String text, Map<String, dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) {
      return pw.TextSpan(text: text);
    }

    // Build text style based on attributes
    pw.FontWeight? fontWeight;
    pw.FontStyle? fontStyle;
    PdfColor? color;
    PdfColor? background;
    bool underline = false;
    bool strikethrough = false;
    double? fontSize;

    // Bold
    if (attributes['bold'] == true) {
      fontWeight = pw.FontWeight.bold;
    }

    // Italic
    if (attributes['italic'] == true) {
      fontStyle = pw.FontStyle.italic;
    }

    // Underline
    if (attributes['underline'] == true) {
      underline = true;
    }

    // Strikethrough
    if (attributes['strike'] == true) {
      strikethrough = true;
    }

    // Font size
    if (attributes['size'] != null) {
      final sizeStr = attributes['size'].toString();
      if (sizeStr == 'small') {
        fontSize = 10;
      } else if (sizeStr == 'large') {
        fontSize = 18;
      } else if (sizeStr == 'huge') {
        fontSize = 24;
      } else {
        // Try to parse as number
        fontSize = double.tryParse(sizeStr);
      }
    }

    // Text color
    if (attributes['color'] != null) {
      color = _parseColor(attributes['color'].toString());
    }

    // Background color
    if (attributes['background'] != null) {
      background = _parseColor(attributes['background'].toString());
    }

    // Header styles
    if (attributes['header'] != null) {
      final level = attributes['header'] as int;
      switch (level) {
        case 1:
          fontSize = 32;
          fontWeight = pw.FontWeight.bold;
          break;
        case 2:
          fontSize = 24;
          fontWeight = pw.FontWeight.bold;
          break;
        case 3:
          fontSize = 18;
          fontWeight = pw.FontWeight.bold;
          break;
      }
    }

    return pw.TextSpan(
      text: text,
      style: pw.TextStyle(
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        background: background != null ? pw.BoxDecoration(color: background) : null,
        decoration: underline
            ? pw.TextDecoration.underline
            : strikethrough
                ? pw.TextDecoration.lineThrough
                : null,
        fontSize: fontSize,
      ),
    );
  }

  /// Parse color string to PdfColor
  static PdfColor _parseColor(String colorStr) {
    // Remove # if present
    colorStr = colorStr.replaceAll('#', '');

    // Handle different color formats
    if (colorStr.length == 6) {
      // RGB format: RRGGBB
      final r = int.parse(colorStr.substring(0, 2), radix: 16);
      final g = int.parse(colorStr.substring(2, 4), radix: 16);
      final b = int.parse(colorStr.substring(4, 6), radix: 16);
      return PdfColor(r / 255, g / 255, b / 255);
    } else if (colorStr.length == 8) {
      // ARGB format: AARRGGBB
      final r = int.parse(colorStr.substring(2, 4), radix: 16);
      final g = int.parse(colorStr.substring(4, 6), radix: 16);
      final b = int.parse(colorStr.substring(6, 8), radix: 16);
      return PdfColor(r / 255, g / 255, b / 255);
    }

    // Default to black if parsing fails
    return PdfColors.black;
  }
}

