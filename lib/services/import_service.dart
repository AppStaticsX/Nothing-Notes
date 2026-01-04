import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../models/note.dart';

class ImportService {
  Future<List<Note>?> importNotesFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt', 'md'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();

        if (result.files.single.extension == 'json') {
          return _parseJsonNotes(contents);
        } else {
          return _parseTextNotes(contents);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to import notes: $e');
    }
  }

  List<Note> _parseJsonNotes(String jsonString) {
    List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => Note.fromJson(json)).toList();
  }

  List<Note> _parseTextNotes(String textContent) {
    List<String> lines = textContent.split('\n\n');
    return lines.where((line) => line.trim().isNotEmpty).map((line) {
      return Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: line.split('\n').first,
        content: line,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();
  }
}
