import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:notes_app/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:typethis/typethis.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../models/note.dart';
import '../widgets/liquid_glass_background.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importFile() async {
    try {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      bool success = await notesProvider.importNotes();

      if (mounted) {
        showSnackBar(
            context,
            success ? 'Notes imported successfully' : 'Import cancelled',
            success ? Severity.success : Severity.warning
        );
        /*ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Notes imported successfully' : 'Import cancelled',
            ),
            duration: const Duration(seconds: 2),
          ),
        );*/
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
            'Error importing file: $e',
            Severity.error
        );
        /*ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error importing file: $e')));*/
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Only rebuilds when theme changes
              _HeaderSection(
                onCategoryPressed: () {
                  final notesProvider = Provider.of<NotesProvider>(
                    context,
                    listen: false,
                  );
                  final themeProvider = Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  );
                  _showCategoriesBottomSheet(
                    context,
                    notesProvider,
                    themeProvider.currentAppTheme,
                  );
                },
              ),
              const SizedBox(height: 24),

              // Search Bar - Only rebuilds when theme changes
              _SearchBar(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {});
                  Provider.of<NotesProvider>(
                    context,
                    listen: false,
                  ).searchNotes(value);
                },
                onClear: () {
                  _searchController.clear();
                  Provider.of<NotesProvider>(
                    context,
                    listen: false,
                  ).clearSearch();
                },
              ),
              const SizedBox(height: 24),

              // Action Buttons - Only rebuilds when theme changes
              _ActionButtons(onImport: _importFile),
              const SizedBox(height: 16),

              // Notes Header - Only rebuilds when notes or category changes
              const _NotesHeader(),
              const SizedBox(height: 24),

              // Notes List or Empty State - Only rebuilds when notes change
              const Expanded(child: _NotesContent()),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoriesBottomSheet(
    BuildContext context,
    NotesProvider notesProvider,
    theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return FutureBuilder<List<String>>(
          future: notesProvider.getAllCategories(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: theme.primaryColor),
                ),
              );
            }

            final categories = snapshot.data ?? [];

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Categories',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Categories List
                  if (categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Iconsax.category,
                              size: 64,
                              color: theme.secondaryTextColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No categories yet',
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create notes with categories to see them here',
                              style: TextStyle(
                                color: theme.secondaryTextColor.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected =
                              notesProvider.selectedCategory == category;
                          final notesInCategory = notesProvider
                              .getNotesByCategory(category)
                              .length;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.primaryColor.withValues(alpha: 0.15)
                                  : theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? theme.primaryColor
                                    : theme.secondaryTextColor.withValues(
                                        alpha: 0.1,
                                      ),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Iconsax.folder_2,
                                  color: theme.primaryColor,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                category,
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$notesInCategory',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              onTap: () {
                                if (isSelected) {
                                  notesProvider.setCategory(null);
                                } else {
                                  notesProvider.setCategory(category);
                                }
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Clear Filter Button (only show if a category is selected)
                  if (notesProvider.selectedCategory != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          notesProvider.setCategory(null);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear Filter'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Extracted Header Section - Only rebuilds when theme changes
class _HeaderSection extends StatelessWidget {
  final VoidCallback onCategoryPressed;

  const _HeaderSection({required this.onCategoryPressed});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentAppTheme;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Your Notes',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                GlassIconButton(
                  icon: CupertinoIcons.collections,
                  size: 48,
                  iconSize: 24,
                  borderRadius: 18,
                  onTap: onCategoryPressed
                ),
                const SizedBox(width: 12),
                GlassIconButton(
                  icon: CupertinoIcons.settings,
                  size: 48,
                  iconSize: 26,
                  borderRadius: 18,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// Extracted Search Bar - Only rebuilds when theme changes or text changes
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentAppTheme;
        return TextField(
          controller: controller,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'Search Notes...',
            hintStyle: TextStyle(color: theme.secondaryTextColor),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: theme.secondaryTextColor,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: theme.secondaryTextColor),
                    onPressed: onClear,
                  )
                : null,
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: onChanged,
        );
      },
    );
  }
}

// Extracted Action Buttons - Only rebuilds when theme changes
class _ActionButtons extends StatelessWidget {
  final VoidCallback onImport;

  const _ActionButtons({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentAppTheme;
        final notesProvider = Provider.of<NotesProvider>(
          context,
          listen: false,
        );

        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final note = await notesProvider.createNote();
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteEditorScreen(note: note),
                      ),
                    );
                    notesProvider.setCategory(null);
                  }
                },
                icon: const Icon(CupertinoIcons.pencil_outline, size: 24),
                label: const Text(
                  'New Note',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  onImport();
                  notesProvider.setCategory(null);
                },
                icon: const Icon(CupertinoIcons.folder_badge_plus, size: 24),
                label: const Text(
                  'Import File',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Extracted Notes Header - Only rebuilds when notes or category changes
class _NotesHeader extends StatelessWidget {
  const _NotesHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotesProvider, ThemeProvider>(
      builder: (context, notesProvider, themeProvider, child) {
        final theme = themeProvider.currentAppTheme;
        final notes = notesProvider.notes;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                notesProvider.selectedCategory != null
                    ? 'Notes: ${notesProvider.selectedCategory}'
                    : 'All Notes',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                notes.isEmpty
                    ? 'No notes yet'
                    : '${notes.length} note${notes.length != 1 ? 's' : ''}',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Extracted Notes Content - Only rebuilds when notes change
class _NotesContent extends StatelessWidget {
  const _NotesContent();

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotesProvider, ThemeProvider>(
      builder: (context, notesProvider, themeProvider, child) {
        final theme = themeProvider.currentAppTheme;
        final notes = notesProvider.notes;

        if (notes.isEmpty) {
          return _EmptyState(theme: theme);
        }

        return _NotesGridView(notes: notes, theme: theme);
      },
    );
  }
}

// Extracted Empty State
class _EmptyState extends StatelessWidget {
  final dynamic theme;

  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.cardColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.note_2_copy,
              size: 72,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          TypeThis(
            key: ValueKey('${settingsProvider.fontFamily}_${settingsProvider.fontSize}_${theme.textColor}'),
            string: 'Start Your Journey',
            speed: 150,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
            textAlign: .center,
          ),
          const SizedBox(height: 4),
          Text(
            'Create your first note and begin\ncapturing your ideas',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final notesProvider = Provider.of<NotesProvider>(
                context,
                listen: false,
              );
              final note = await notesProvider.createNote();
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoteEditorScreen(note: note),
                  ),
                );
                notesProvider.setCategory(null);
              }
            },
            icon: const Icon(CupertinoIcons.pencil_outline, size: 24),
            label: const Text(
              'New Note',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extracted Notes Grid View with staggered layout
class _NotesGridView extends StatelessWidget {
  final List<Note> notes;
  final dynamic theme;

  const _NotesGridView({required this.notes, required this.theme});

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.builder(
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _NoteCard(
          key: ValueKey(note.id),
          note: note,
          theme: theme,
        );
      },
    );
  }
}

// Extracted Note Card - matches the image style
class _NoteCard extends StatelessWidget {
  final Note note;
  final dynamic theme;

  const _NoteCard({
    super.key,
    required this.note,
    required this.theme,
  });

  String _getTimeLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final noteDate = DateTime(date.year, date.month, date.day);

    if (noteDate == today) {
      return 'Today';
    } else if (noteDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }

  List<String> _extractImagePaths() {
    if (note.content.isEmpty || !note.content.trim().startsWith('[')) {
      return [];
    }

    try {
      final List<dynamic> delta = jsonDecode(note.content);
      final List<String> imagePaths = [];

      for (var op in delta) {
        if (op is Map && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is Map && insert.containsKey('image')) {
            final imagePath = insert['image'];
            if (imagePath is String && imagePath.isNotEmpty) {
              imagePaths.add(imagePath);
            }
          }
        }
      }

      return imagePaths;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteEditorScreen(note: note),
              ),
            );
          },
          onLongPress: () {
            _showDeleteConfirmation(context, note);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row - Time and Date label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeFormat.format(note.updatedAt),
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      _getTimeLabel(note.updatedAt),
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  note.title,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),

                // Content preview (if exists)
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note.preview,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Images grid (if note has images)
                _buildImageGrid(),

                // Bottom indicators (if note has special properties)
                if (note.isPinned || note.hasReminder || note.category != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (note.isPinned)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.5),
                                child: Transform.rotate(
                                  angle: math.pi/4,
                                  child: Icon(
                                    CupertinoIcons.pin_fill,
                                    size: 12,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (note.hasReminder)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.secondaryTextColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.5),
                                child: Icon(
                                  CupertinoIcons.alarm,
                                  size: 12,
                                  color: theme.secondaryTextColor,
                                ),
                              ),
                              /*const SizedBox(width: 4),
                              Text(
                                'Reminder',
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),*/
                            ],
                          ),
                        ),
                      if (note.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.secondaryTextColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            note.category!,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final imagePaths = _extractImagePaths();

    if (imagePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to first 4 images for the card preview
    final displayImages = imagePaths.take(4).toList();
    final hasMore = imagePaths.length > 4;

    return Column(
      children: [
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            if (displayImages.length == 1) {
              // Single image - full width
              return _buildImageItem(displayImages[0], width, width * 0.5);
            } else if (displayImages.length == 2) {
              // Two images - side by side
              return Row(
                children: [
                  Expanded(
                    child: _buildImageItem(displayImages[0], width / 2 - 4, width * 0.35),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildImageItem(displayImages[1], width / 2 - 4, width * 0.35),
                  ),
                ],
              );
            } else {
              // 3 or 4 images - grid layout
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildImageItem(displayImages[0], width / 2 - 4, width * 0.25),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildImageItem(displayImages[1], width / 2 - 4, width * 0.25),
                      ),
                    ],
                  ),
                  if (displayImages.length > 2) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildImageItem(displayImages[2], width / 2 - 4, width * 0.25),
                        ),
                        if (displayImages.length > 3) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Stack(
                              children: [
                                _buildImageItem(displayImages[3], width / 2 - 4, width * 0.25),
                                if (hasMore)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '+${imagePaths.length - 4}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildImageItem(String imagePath, double width, double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: height,
        color: theme.secondaryTextColor.withValues(alpha: 0.1),
        child: _buildImage(imagePath),
      ),
    );
  }

  Widget _buildImage(String imagePath) {
    // Check if it's a file path or URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder();
        },
      );
    } else {
      // Local file
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder();
          },
        );
      } else {
        return _buildImagePlaceholder();
      }
    }
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        color: theme.secondaryTextColor.withValues(alpha: 0.5),
        size: 32,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Note note) {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Delete Note', style: TextStyle(color: theme.textColor)),
          content: Text(
            'Are you sure you want to delete "${note.title}"?',
            style: TextStyle(color: theme.secondaryTextColor),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.secondaryTextColor),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                notesProvider.deleteNote(note.id);
                Navigator.of(context).pop();
                showSnackBar(
                  context,
                    'Note deleted',
                    Severity.success
                );
                /*ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Note deleted')));*/
              },
            ),
          ],
        );
      },
    );
  }
}
