import 'dart:io';
import 'dart:math' as math;
import 'package:floating_menu_panel/floating_menu_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:notes_app/screens/widgets/file_preview_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../services/plain_text_export_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/category_dialog.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/editor_background.dart';
import 'dart:async';
import 'dart:convert';
import '../widgets/liquid_glass_background.dart';
import 'configs/quill_image_helper.dart';
import 'configs/quill_file_helper.dart';
import 'image_preview_screen.dart';
import 'reminder_picker_screen.dart';
import 'audio_recorder_screen.dart';

/// Optimized version of NoteEditorScreen with extracted widgets to prevent unnecessary rebuilds
///
/// Key optimizations:
/// 1. AppBar actions extracted to separate widgets
/// 2. Toolbar configuration extracted to const
/// 3. Editor content wrapped in Consumer for selective rebuilds
/// 4. Bottom bar and image preview use listen: false
class NoteEditorScreen extends StatefulWidget {
  final Note note;

  const NoteEditorScreen({super.key, required this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late quill.QuillController _quillController;
  late TextEditingController _titleController;
  late FocusNode _editorFocusNode;
  int _wordCount = 0;
  Timer? _debounce;
  double _marginLineOffset = 0.0;
  final TextEditingController _searchController = TextEditingController();
  bool _isEditMode = false;

  List<String> _noteImages = [];
  List<String> _noteFiles = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _editorFocusNode = FocusNode();

    // Initialize Quill controller with existing content
    _initializeQuillController();

    _updateCounts();
    _quillController.addListener(_onContentChanged);
    _titleController.addListener(_onTitleChanged);
    _loadMarginLineOffset();
    _loadNoteImages();
    _loadNoteFiles();
  }

  void _initializeQuillController() {
    try {
      // Try to parse JSON content if it exists
      if (widget.note.content.isNotEmpty &&
          widget.note.content.startsWith('[')) {
        final doc = quill.Document.fromJson(jsonDecode(widget.note.content));
        _quillController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        // Plain text content
        _quillController = quill.QuillController.basic();
        if (widget.note.content.isNotEmpty) {
          _quillController.document.insert(0, widget.note.content);
        }
      }
    } catch (e) {
      // Fallback to basic controller with plain text
      _quillController = quill.QuillController.basic();
      if (widget.note.content.isNotEmpty) {
        _quillController.document.insert(0, widget.note.content);
      }
    }
  }

  void _updateCounts() {
    setState(() {
      final text = _quillController.document.toPlainText().trim();
      _wordCount = text.isEmpty
          ? 0
          : text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _quillController.removeListener(_onContentChanged);
    _titleController.removeListener(_onTitleChanged);
    _quillController.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    setState(() {});
    _updateCounts();

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _saveNote();
    });
  }

  void _onTitleChanged() {
    setState(() {});

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _saveNote();
    });
  }

  Future<void> _loadNoteImages() async {
    final images = await QuillImageHelper.getNoteImages(widget.note.id);
    setState(() {
      _noteImages = images;
    });
  }

  Future<void> _loadNoteFiles() async {
    final files = await QuillFileHelper.getNoteFiles(widget.note.id);
    setState(() {
      _noteFiles = files;
    });
  }

  Future<void> _pickAndAddImage() async {
    final imagePath = await QuillImageHelper.pickAndSaveImage(widget.note.id);
    if (imagePath != null) {
      setState(() {
        _noteImages.insert(0, imagePath);
      });
      if (mounted) {
        showSnackBar(
          context,
          'Image added successfully',
          Severity.success,
        );
      }
    }
  }

  Future<void> _pickAndAddFile() async {
    final filePath = await QuillFileHelper.pickAndSaveFile(widget.note.id);
    if (filePath != null) {
      setState(() {
        _noteFiles.insert(0, filePath);
      });
      if (mounted) {
        showSnackBar(
          context,
          'File added successfully',
          Severity.success,
        );
      }
    }
  }

  Future<void> _deleteImage(String imagePath) async {
    final success = await QuillImageHelper.deleteImage(imagePath);
    if (success) {
      setState(() {
        _noteImages.remove(imagePath);
      });
      if (mounted) {
        showSnackBar(
          context,
          'Image deleted',
          Severity.info,
        );
      }
    }
  }

  Future<void> _deleteFile(String filePath) async {
    final success = await QuillFileHelper.deleteFile(filePath);
    if (success) {
      setState(() {
        _noteFiles.remove(filePath);
      });
      if (mounted) {
        showSnackBar(
          context,
          'File deleted',
          Severity.info,
        );
      }
    }
  }

  Future<void> _loadMarginLineOffset() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _marginLineOffset = prefs.getDouble('marginLineOffset') ?? 0.0;
    });
  }

  Future<void> _saveNote() async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Save as JSON for rich text
    final jsonContent = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );

    final updatedNote = widget.note.copyWith(
      title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
      content: jsonContent,
    );
    await notesProvider.updateNote(updatedNote);
    setState(() {});
  }

  Future<void> _togglePin() async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    await notesProvider.togglePinNote(widget.note.id);
    setState(() {});
  }

  void _showExportOptions() {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.secondaryTextColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Export Note',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 20),

            // Export as PDF option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.document,
                  color: theme.primaryColor,
                ),
              ),
              title: Text(
                'Export as PDF',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
              subtitle: Text(
                'Export note with images as PDF',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.secondaryTextColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                final notesProvider = Provider.of<NotesProvider>(
                  context,
                  listen: false,
                );
                final note = notesProvider.notes.firstWhere(
                  (n) => n.id == widget.note.id,
                  orElse: () => widget.note,
                );
                PdfExportService.exportAsPdf(
                  title: _titleController.text.isEmpty
                      ? 'Untitled Note'
                      : _titleController.text,
                  controller: _quillController,
                  context: context,
                  category: note.category,
                  createdAt: note.createdAt,
                  updatedAt: note.updatedAt,
                );
              },
            ),

            const SizedBox(height: 8),

            // Export as Plain Text option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.document_text,
                  color: theme.primaryColor,
                ),
              ),
              title: Text(
                'Export as Plain Text',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
              subtitle: Text(
                'Export note content as text file',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.secondaryTextColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                PlainTextExportService.exportAsPlainText(
                  title: _titleController.text.isEmpty
                      ? 'Untitled Note'
                      : _titleController.text,
                  controller: _quillController,
                  context: context,
                );
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _copyNote() {
    showSnackBar(
      context,
      'Note copied to clipboard',
      Severity.success,
    );
  }

  void _showCategoryDialog() {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final note = notesProvider.notes.firstWhere(
      (n) => n.id == widget.note.id,
      orElse: () => widget.note,
    );
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(note: note),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Delete Note', style: TextStyle(color: theme.textColor)),
        content: Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.secondaryTextColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      // Delete associated images and files
      await QuillImageHelper.deleteAllNoteImages(widget.note.id);
      await QuillFileHelper.deleteAllNoteFiles(widget.note.id);
      await notesProvider.deleteNote(widget.note.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showDeleteImageConfirmDialog(String imagePath) async {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Delete Image', style: TextStyle(color: theme.textColor)),
        content: Text(
          'Are you sure you want to delete this image?',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.secondaryTextColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteImage(imagePath);
    }
  }

  Future<void> _showDeleteFileConfirmDialog(String filePath) async {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Delete File', style: TextStyle(color: theme.textColor)),
        content: Text(
          'Are you sure you want to delete this file?',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.secondaryTextColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteFile(filePath);
    }
  }

  Future<void> _handleAudioRecording() async {
    final audioPath = await showAudioRecorderBottomSheet(
      context: context,
      noteId: widget.note.id,
    );

    if (audioPath != null && mounted) {
      // Add audio file to attachments
      setState(() {
        _noteFiles.insert(0, audioPath);
      });

      showSnackBar(
        context,
        'Audio recording added successfully',
        Severity.success,
      );
    }
  }

  Future<void> _handleReminderTap() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderPickerScreen(noteId: widget.note.id),
    );
  }

  void _toggleEditMode(bool value) {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get theme and settings once with listen: false
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.backgroundColor,
      appBar: _buildAppBar(theme),
      body: _buildBody(theme, settingsProvider),
      bottomNavigationBar: SafeArea(
        child: _EditorBottomBar(
          isEditMode: _isEditMode,
          onToggleEditMode: _toggleEditMode,
          onShare: _showExportOptions,
          onCopy: _copyNote,
          onShowCategory: _showCategoryDialog,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(theme) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      leading: _BackButton(),
      title: TextField(
        controller: _titleController,
        enabled: !_isEditMode,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.textColor,
        ),
        decoration: InputDecoration(
          filled: false,
          hintText: 'Title',
          hintStyle: TextStyle(
            color: theme.secondaryTextColor.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
        ),
        maxLines: 1,
      ),
      actions: [
        // Use Consumer only for actions that depend on note state
        Consumer<NotesProvider>(
          builder: (context, notesProvider, child) {
            final note = notesProvider.notes.firstWhere(
              (n) => n.id == widget.note.id,
              orElse: () => widget.note,
            );
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PinButton(
                  isPinned: note.isPinned,
                  theme: theme,
                  onPressed: _togglePin,
                ),
                _DeleteButton(theme: theme, onPressed: _showDeleteConfirmation),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody(theme, settingsProvider) {
    return Stack(
      children: [
        // Background - doesn't need to rebuild
        Positioned.fill(
          child: EditorBackground(
            style: settingsProvider.editorStyle,
            lineColor: theme.secondaryTextColor.withValues(
              alpha: settingsProvider.lineOpacity,
            ),
            fontSize: settingsProvider.fontSize,
            lineHeight:
                (settingsProvider.fontSize / (settingsProvider.fontSize / 1.5))
                    .toDouble(),
            fontFamily: settingsProvider.fontFamily,
            marginLineOffset: _marginLineOffset,
          ),
        ),
        // Content
        Positioned.fill(
          child: SafeArea(
            child: Column(
              children: [
                // Toolbar - only shown when not in edit mode
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: !_isEditMode
                      ? _EditorToolbar(
                    controller: _quillController,
                    theme: theme,
                  )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
                // Editor content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Date and category info - uses Consumer for note updates
                        Consumer<NotesProvider>(
                          builder: (context, notesProvider, child) {
                            final note = notesProvider.notes.firstWhere(
                              (n) => n.id == widget.note.id,
                              orElse: () => widget.note,
                            );
                            return _NoteMetadata(
                              note: note,
                              wordCount: _wordCount,
                              marginLineOffset: _marginLineOffset,
                              fontSize: settingsProvider.fontSize,
                              theme: theme,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        // Quill Editor
                        _QuillEditorWidget(
                          controller: _quillController,
                          focusNode: _editorFocusNode,
                          isEditMode: _isEditMode,
                          marginLineOffset: _marginLineOffset,
                          settingsProvider: settingsProvider,
                          theme: theme,
                        ),
                        const SizedBox(height: 36),
                        _ImagePreviewList(
                          images: _noteImages,
                          marginLineOffset: _marginLineOffset,
                          onDeleteImage: _showDeleteImageConfirmDialog,
                          onReloadImages: _loadNoteImages,
                        ),
                        FilePreviewList(
                          files: _noteFiles,
                          marginLineOffset: _marginLineOffset,
                          onDeleteFile: _showDeleteFileConfirmDialog,
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Floating action button
        if (!_isEditMode)
        _FloatingAttachmentMenu(
          onAddImage: _pickAndAddImage,
          onAddFile: _pickAndAddFile,
          onAddAudio: _handleAudioRecording,
          onReminder: _handleReminderTap,
          theme: theme,
        ),
      ],
    );
  }

  /*String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }*/
}

// ============================================================================
// EXTRACTED WIDGETS - These prevent unnecessary rebuilds
// ============================================================================

/// Back button widget - doesn't rebuild
class _BackButton extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GlassIconButton(
        icon: CupertinoIcons.chevron_back,
        size: 36,
        iconSize: 20,
        borderRadius: 100,
        onTap: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Pin button widget - only rebuilds when isPinned changes
class _PinButton extends StatelessWidget {
  final bool isPinned;
  final dynamic theme;
  final VoidCallback onPressed;

  const _PinButton({
    required this.isPinned,
    required this.theme,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Transform.rotate(
        angle: math.pi / 6,
        child: Icon(
          isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
          color: isPinned ? theme.primaryColor : theme.textColor,
        ),
      ),
      onPressed: onPressed,
    );
  }
}

/// Delete button widget - doesn't rebuild
class _DeleteButton extends StatelessWidget {
  final dynamic theme;
  final VoidCallback onPressed;

  const _DeleteButton({required this.theme, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Iconsax.trash_copy, color: theme.textColor),
      onPressed: onPressed,
    );
  }
}

/// Editor toolbar widget - doesn't rebuild unless controller changes
class _EditorToolbar extends StatelessWidget {
  final quill.QuillController controller;
  final dynamic theme;

  const _EditorToolbar({required this.controller, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.secondaryTextColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: quill.QuillSimpleToolbar(
        controller: controller,
        config: quill.QuillSimpleToolbarConfig(
          toolbarIconAlignment: WrapAlignment.start,
          toolbarSize: 44,
          multiRowsDisplay: false,
          showDividers: true,
          showClipboardCopy: true,
          showClipboardPaste: true,
          showClipboardCut: true,
          showInlineCode: true,
          showLineHeightButton: true,
          showSmallButton: true,
          showAlignmentButtons: true,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: true,
          showColorButton: true,
          showBackgroundColorButton: true,
          showListNumbers: true,
          showListBullets: true,
          showListCheck: true,
          showCodeBlock: true,
          showQuote: true,
          showIndent: true,
          showLink: true,
          showUndo: true,
          showRedo: true,
          showDirection: true,
          showSearchButton: true,
          showFontFamily: false,
          showFontSize: false,
          showHeaderStyle: true,
          showClearFormat: true,
          embedButtons: FlutterQuillEmbeds.toolbarButtons(
            imageButtonOptions: const QuillToolbarImageButtonOptions(),
            videoButtonOptions: null,
            cameraButtonOptions: null,
          ),
        ),
      ),
    );
  }
}

/// Note metadata widget - only rebuilds when note changes
class _NoteMetadata extends StatelessWidget {
  final Note note;
  final int wordCount;
  final double marginLineOffset;
  final double fontSize;
  final dynamic theme;

  const _NoteMetadata({
    required this.note,
    required this.wordCount,
    required this.marginLineOffset,
    required this.fontSize,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        top: fontSize,
        right: 16,
      ),
      child: Row(
        children: [
          Text(
            _formatDate(note.updatedAt),
            style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
          ),
          if (note.category != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                note.category!,
                style: TextStyle(fontSize: 11, color: theme.primaryColor),
              ),
            ),
          ],
          // Reminder info chip - only shown if reminder exists
          if (note.hasReminder && note.reminderDateTime != null) ...[
            const SizedBox(width: 8),
            _ReminderChip(
              reminderDateTime: note.reminderDateTime!,
              noteId: note.id,
              theme: theme,
              onDelete: () async {
                // Delete reminder using provider
                final notesProvider = Provider.of<NotesProvider>(
                  context,
                  listen: false,
                );
                await notesProvider.clearNoteReminder(note.id);

                // Check if widget is still mounted before using context
                if (context.mounted) {
                  showSnackBar(
                    context,
                    'Reminder removed',
                    Severity.info,
                  );
                }
              },
            ),
          ],
          const Spacer(),
          Text(
            '$wordCount Words',
            style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Reminder chip widget - displays reminder time with close button
/// Extracted as separate widget to prevent unnecessary rebuilds
class _ReminderChip extends StatelessWidget {
  final DateTime reminderDateTime;
  final String noteId;
  final dynamic theme;
  final VoidCallback onDelete;

  const _ReminderChip({
    required this.reminderDateTime,
    required this.noteId,
    required this.theme,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPast = reminderDateTime.isBefore(DateTime.now());
    final Color chipColor = isPast ? Colors.red : theme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.alarm, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            _formatReminderTime(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 14,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatReminderTime() {
    final now = DateTime.now();
    final difference = reminderDateTime.difference(now);

    if (difference.isNegative) {
      return 'Passed';
    } else if (difference.inMinutes < 60) {
      return 'in ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'in ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return 'in ${difference.inDays}d';
    } else {
      return '${reminderDateTime.day}/${reminderDateTime.month}';
    }
  }
}

/// Quill editor widget - doesn't rebuild unless necessary
class _QuillEditorWidget extends StatelessWidget {
  final quill.QuillController controller;
  final FocusNode focusNode;
  final bool isEditMode;
  final double marginLineOffset;
  final dynamic settingsProvider;
  final dynamic theme;

  const _QuillEditorWidget({
    required this.controller,
    required this.focusNode,
    required this.isEditMode,
    required this.marginLineOffset,
    required this.settingsProvider,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final editorWidget = quill.QuillEditor.basic(
      controller: controller,
      focusNode: focusNode,
      config: quill.QuillEditorConfig(
        padding: EdgeInsets.zero,
        scrollable: false,
        autoFocus: false,
        expands: false,
        checkBoxReadOnly: isEditMode,
        onTapUp: isEditMode ? (details, p1) => false : null,
        placeholder: 'Start Noting...',
        embedBuilders: [...FlutterQuillEmbeds.defaultEditorBuilders()],
        customStyles: quill.DefaultStyles(
            paragraph: quill.DefaultTextBlockStyle(
              TextStyle(
                fontSize: settingsProvider.fontSize,
                height:
                    settingsProvider.fontSize /
                    (settingsProvider.fontSize / 1.5),
                color: theme.textColor,
                fontFamily: settingsProvider.fontFamily,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            placeHolder: quill.DefaultListBlockStyle(
              TextStyle(
                fontSize: settingsProvider.fontSize,
                fontWeight: FontWeight.bold,
                height: 1.3,
                color: theme.secondaryTextColor,
                fontFamily: settingsProvider.fontFamily,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
              null,
            ),
            h1: quill.DefaultTextBlockStyle(
              TextStyle(
                fontSize: settingsProvider.fontSize * 2,
                fontWeight: FontWeight.bold,
                height: 1.3,
                color: theme.textColor,
                fontFamily: settingsProvider.fontFamily,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            h2: quill.DefaultTextBlockStyle(
              TextStyle(
                fontSize: settingsProvider.fontSize * 1.5,
                fontWeight: FontWeight.bold,
                height: 1.3,
                color: theme.textColor,
                fontFamily: settingsProvider.fontFamily,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            h3: quill.DefaultTextBlockStyle(
              TextStyle(
                fontSize: settingsProvider.fontSize * 1.25,
                fontWeight: FontWeight.bold,
                height: 1.3,
                color: theme.textColor,
                fontFamily: settingsProvider.fontFamily,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            code: quill.DefaultTextBlockStyle(
              TextStyle(
                fontSize: settingsProvider.fontSize * 0.9,
                fontFamily: 'monospace',
                color: theme.textColor,
                backgroundColor: theme.cardColor,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            lists: quill.DefaultListBlockStyle(
              TextStyle(
                fontSize: settingsProvider.fontSize,
                height:
                    settingsProvider.fontSize /
                    (settingsProvider.fontSize / 1.5),
                color: theme.textColor,
                fontFamily: settingsProvider.fontFamily,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
              null,
            ),
          ),
        ),
    );

    return Container(
      padding: EdgeInsets.only(left: (marginLineOffset/2) + 16, right: (marginLineOffset/2) + 16),
      child: IgnorePointer(
        ignoring: isEditMode,
        child: editorWidget,
      ),
    );
  }
}

/// Bottom bar widget - doesn't rebuild
class _EditorBottomBar extends StatelessWidget {
  final bool isEditMode;
  final Function(bool) onToggleEditMode;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onShowCategory;

  const _EditorBottomBar({
    required this.isEditMode,
    required this.onToggleEditMode,
    required this.onShare,
    required this.onCopy,
    required this.onShowCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(
              top: BorderSide(
                color: theme.secondaryTextColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Export',
                icon: Icon(CupertinoIcons.share, color: theme.textColor),
                onPressed: onShare,
              ),
              IconButton(
                tooltip: 'Copy Content',
                icon: Icon(
                  CupertinoIcons.doc_on_clipboard,
                  color: theme.textColor,
                ),
                onPressed: onCopy,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: isEditMode
                    ? const SizedBox.shrink()
                    : IconButton(
                  tooltip: 'Category',
                  icon: Icon(CupertinoIcons.collections, color: theme.textColor),
                  onPressed: onShowCategory,
                ),
              ),
              IconButton(
                tooltip: 'Note Settings',
                icon: Icon(
                  CupertinoIcons.gear,
                  color: theme.textColor,
                  size: 28,
                ),
                onPressed: onCopy,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reading Mode:',
                    style: TextStyle(color: theme.textColor, fontSize: 12),
                  ),
                  Row(
                    children: [
                      Switch(value: isEditMode, onChanged: onToggleEditMode),
                      const SizedBox(width: 12),
                      Transform.rotate(
                        angle: -math.pi / 2,
                        child: Text(
                          isEditMode ? 'ON' : 'OFF',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Image preview list widget - only rebuilds when images change
class _ImagePreviewList extends StatelessWidget {
  final List<String> images;
  final double marginLineOffset;
  final Function(String) onDeleteImage;
  final Future<void> Function() onReloadImages;

  const _ImagePreviewList({
    required this.images,
    required this.marginLineOffset,
    required this.onDeleteImage,
    required this.onReloadImages,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: marginLineOffset + 16, top: 16),
          child: Row(
            children: [
              const Icon(CupertinoIcons.paperclip),
              const SizedBox(width: 12),
              Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.builder(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: marginLineOffset + 16, right: 16),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final imagePath = images[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: _ImageCard(
                  imagePath: imagePath,
                  allImages: images,
                  currentIndex: index,
                  onDelete: () => onDeleteImage(imagePath),
                  onReloadImages: onReloadImages,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Individual image card widget
class _ImageCard extends StatelessWidget {
  final String imagePath;
  final List<String> allImages;
  final int currentIndex;
  final VoidCallback onDelete;
  final Future<void> Function() onReloadImages;

  const _ImageCard({
    required this.imagePath,
    required this.allImages,
    required this.currentIndex,
    required this.onDelete,
    required this.onReloadImages,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Navigate to image preview screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreviewScreen(
              images: allImages,
              initialIndex: currentIndex,
              onDeleteImage: (deletedImage) async {
                // Delete the image from storage and update the note
                await QuillImageHelper.deleteImage(deletedImage);
              },
            ),
          ),
        );
        // Reload images after returning from preview to reflect any deletions
        await onReloadImages();
      },
      child: SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(
                  File(imagePath),
                  width: 150,
                  height: 150,
                  cacheHeight: 150,
                  cacheWidth: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 150,
                      height: 150,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.delete, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating attachment menu widget
class _FloatingAttachmentMenu extends StatelessWidget {
  final VoidCallback onAddImage;
  final VoidCallback onAddFile;
  final VoidCallback onAddAudio;
  final VoidCallback onReminder;
  final dynamic theme;

  const _FloatingAttachmentMenu({
    required this.onAddImage,
    required this.onAddFile,
    required this.onAddAudio,
    required this.onReminder,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingMenuPanel(
      onPressed: (index) {
        if (index == 0) {
          onAddImage();
        } else if (index == 1) {
          onAddAudio();
        } else if (index == 2) {
          onAddFile();
        } else if (index == 3) {
          onReminder();
        }
      },
      panelIcon: CupertinoIcons.paperclip,
      positionTop: MediaQuery.of(context).size.height * 0.2,
      positionLeft: MediaQuery.of(context).size.width - 60,
      panelShape: PanelShape.rectangle,
      borderRadius: BorderRadius.circular(16),
      backgroundColor: theme.cardColor,
      contentColor: theme.textColor,
      buttons: const [
        Iconsax.gallery_add_copy,
        Iconsax.microphone_copy,
        Iconsax.document_code_copy,
        CupertinoIcons.alarm,
      ],
    );
  }
}
