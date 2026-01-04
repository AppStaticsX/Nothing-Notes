import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class QuillFileHelper {
  /// Pick file and save to app directory
  static Future<String?> pickAndSaveFile(String noteId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'csv',
          'ppt',
          'pptx',
          'mp3',
          'wav',
          'm4a',
        ],
      );

      if (result == null || result.files.single.path == null) return null;

      final pickedFile = result.files.single;
      final filePath = pickedFile.path!;

      // Get app directory
      final appDir = await getApplicationDocumentsDirectory();
      final notesFilesDir = Directory('${appDir.path}/note_files/$noteId');

      // Create directory if it doesn't exist
      if (!await notesFilesDir.exists()) {
        await notesFilesDir.create(recursive: true);
      }

      // Generate unique filename while preserving original name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalFileName = path.basename(filePath);
      final newPath = '${notesFilesDir.path}/${timestamp}_$originalFileName';

      // Copy file to app directory
      final File savedFile = await File(filePath).copy(newPath);

      return savedFile.path;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }

  /// Delete file from storage
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  /// Delete all files for a note
  static Future<void> deleteAllNoteFiles(String noteId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final notesFilesDir = Directory('${appDir.path}/note_files/$noteId');

      if (await notesFilesDir.exists()) {
        await notesFilesDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting note files: $e');
    }
  }

  /// Get all files for a note
  static Future<List<String>> getNoteFiles(String noteId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final notesFilesDir = Directory('${appDir.path}/note_files/$noteId');

      if (!await notesFilesDir.exists()) {
        return [];
      }

      final files = await notesFilesDir.list().toList();
      return files.whereType<File>().map((file) => file.path).toList()
        ..sort((a, b) => b.compareTo(a)); // Sort by newest first
    } catch (e) {
      debugPrint('Error getting note files: $e');
      return [];
    }
  }

  /// Get file size in formatted string
  static String getFileSize(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return '0 KB';

      final bytes = file.lengthSync();
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      debugPrint('Error getting file size: $e');
      return '0 KB';
    }
  }

  /// Get file extension
  static String getFileExtension(String filePath) {
    return path.extension(filePath).replaceAll('.', '').toUpperCase();
  }

  /// Get file name with extension
  static String getFileName(String filePath) {
    final basename = path.basename(filePath);
    // Remove timestamp prefix if present (format: timestamp_originalname.ext)
    final parts = basename.split('_');
    if (parts.length > 1 && parts[0].length == 13) {
      // If first part is 13 digits (timestamp), remove it
      return parts.sublist(1).join('_');
    }
    return basename;
  }

  /// Get file type icon based on extension
  static IconData getFileIcon(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.csv':
        return Icons.grid_on;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.mp3':
      case '.wav':
      case '.m4a':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Color getFileIconColor(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.pdf':
        return Colors.red;
      case '.doc':
      case '.docx':
        return Colors.blue;
      case '.xls':
      case '.xlsx':
        return Colors.green;
      case '.csv':
        return Colors.orange;
      case '.ppt':
      case '.pptx':
        return Colors.yellow;
      case '.mp3':
      case '.wav':
      case '.m4a':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  /// Open file in default application
  static Future<void> openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      final result = await OpenFilex.open(filePath);

      // Check if file was opened successfully
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      rethrow;
    }
  }

  /// Share file with other apps
  static Future<void> shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      final fileName = getFileName(filePath);
      await SharePlus.instance.share(
        ShareParams(text: 'Sharing: $fileName', files: [XFile(filePath)]),
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
      rethrow;
    }
  }
}
