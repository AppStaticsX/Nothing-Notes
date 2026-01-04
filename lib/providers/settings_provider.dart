import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/editor_style.dart';

class SettingsProvider with ChangeNotifier {
  double _fontSize = 16.0;
  String _fontFamily = 'Nothing Font';
  EditorStyle _editorStyle = EditorStyle.plain;
  double _lineOpacity = 0.60;

  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  EditorStyle get editorStyle => _editorStyle;
  double get lineOpacity => _lineOpacity;
  String? get customFontName => _customFontName;

  List<double> get fontSizes => [12, 14, 16, 18, 20, 22, 24];
  List<String> get fontFamilies => [
    'Inter',
    'Roboto',
    'OpenSans',
    'Nothing Font',
    'Josefin-Sans',
    'Raleway'
  ];
  String? _customFontName;
  List<double> get lineOpacities => [0.0, 0.15, 0.30, 0.45, 0.60, 0.75, 0.90, 1.0];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('fontSize') ?? 16.0;
    _fontFamily = prefs.getString('fontFamily') ?? 'Nothing Font';
    _editorStyle = EditorStyle.values[prefs.getInt('editorStyle') ?? 0];
    _lineOpacity = prefs.getDouble('lineOpacity') ?? 0.60;
    _customFontName = prefs.getString('customFontName');
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', family);
    notifyListeners();
  }

  Future<void> setEditorStyle(EditorStyle style) async {
    _editorStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('editorStyle', style.index);
    notifyListeners();
  }

  Future<void> setLineOpacity(double opacity) async {
    _lineOpacity = opacity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lineOpacity', opacity);
    notifyListeners();
  }


  Future<void> loadCustomFont(String sourcePath, String fontName) async {
    try {
      // Get app's documents directory for persistent storage
      final appDir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory('${appDir.path}/fonts');

      // Create fonts directory if it doesn't exist
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }

      // Copy font file to persistent storage
      final sourceFile = File(sourcePath);
      final extension = sourcePath.split('.').last;
      final persistentPath = '${fontsDir.path}/$fontName.$extension';
      final persistentFile = await sourceFile.copy(persistentPath);

      // Load font into Flutter
      final fontLoader = ui.FontLoader(fontName);
      fontLoader.addFont(persistentFile.readAsBytes().then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
      await fontLoader.load();

      // Save font info to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customFontName', fontName);
      await prefs.setString('customFontPath', persistentPath);

      _customFontName = fontName;
      notifyListeners();
    } catch (e) {
      print('Error loading custom font: $e');
      rethrow;
    }
  }


  Future<void> loadSavedCustomFont() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fontName = prefs.getString('customFontName');
      final fontPath = prefs.getString('customFontPath');

      if (fontName != null && fontPath != null) {
        final fontFile = File(fontPath);
        if (await fontFile.exists()) {
          final fontLoader = ui.FontLoader(fontName);
          fontLoader.addFont(fontFile.readAsBytes().then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
          await fontLoader.load();
          _customFontName = fontName;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading saved custom font: $e');
    }
  }
}