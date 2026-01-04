import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class QuillImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery and save to app directory
  static Future<String?> pickAndSaveImage(String noteId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Get app directory
      final appDir = await getApplicationDocumentsDirectory();
      final notesImagesDir = Directory('${appDir.path}/note_images/$noteId');

      // Create directory if it doesn't exist
      if (!await notesImagesDir.exists()) {
        await notesImagesDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(image.path);
      final newPath = '${notesImagesDir.path}/$timestamp$extension';

      // Copy image to app directory
      final File savedImage = await File(image.path).copy(newPath);

      return savedImage.path;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Delete image from storage
  static Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Delete all images for a note
  static Future<void> deleteAllNoteImages(String noteId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final notesImagesDir = Directory('${appDir.path}/note_images/$noteId');

      if (await notesImagesDir.exists()) {
        await notesImagesDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting note images: $e');
    }
  }

  /// Get all images for a note
  static Future<List<String>> getNoteImages(String noteId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final notesImagesDir = Directory('${appDir.path}/note_images/$noteId');

      if (!await notesImagesDir.exists()) {
        return [];
      }

      final files = await notesImagesDir.list().toList();
      return files
          .whereType<File>()
          .map((file) => file.path)
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Sort by newest first
    } catch (e) {
      debugPrint('Error getting note images: $e');
      return [];
    }
  }
}