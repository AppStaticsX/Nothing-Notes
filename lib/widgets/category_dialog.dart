import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/theme_provider.dart';

class CategoryDialog extends StatelessWidget {
  final Note note;

  const CategoryDialog({super.key, required this.note});

  // Pre-defined categories with icons and colors
  static final Map<String, Map<String, dynamic>> predefinedCategories = {
    'Work': {'icon': Iconsax.briefcase_copy, 'color': Colors.blue},
    'Personal': {'icon': Iconsax.user_copy, 'color': Colors.green},
    'Ideas': {'icon': Iconsax.lamp_1_copy, 'color': Colors.amber},
    'Study': {'icon': Iconsax.book_1_copy, 'color': Colors.purple},
    'Travel': {'icon': Iconsax.airplane_copy, 'color': Colors.teal},
    'Health': {'icon': Iconsax.heart_copy, 'color': Colors.red},
    'Finance': {'icon': Iconsax.wallet_2_copy, 'color': Colors.orange},
    'Shopping': {'icon': Iconsax.shopping_cart_copy, 'color': Colors.pink},
    'Projects': {'icon': Iconsax.hierarchy_square_3_copy, 'color': Colors.indigo},
    'Goals': {'icon': Iconsax.flag_copy, 'color': Colors.deepOrange},
  };

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentAppTheme;

    // Use Consumer to get updated note when category changes
    return Consumer<NotesProvider>(
      builder: (context, notesProvider, _) {
        // Get the current note from provider to reflect any updates
        final currentNote = notesProvider.getNoteById(note.id) ?? note;

        return FutureBuilder<List<String>>(
          future: notesProvider.getAllCategories(),
          builder: (context, snapshot) {
            final existingCategories = snapshot.data ?? [];

            // Combine predefined and custom categories
            final customCategories = existingCategories
                .where((cat) => !predefinedCategories.containsKey(cat))
                .toList();

            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Select Category',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Pre-defined categories section
                      Text(
                        'SUGGESTED',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pre-defined categories grid
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: predefinedCategories.entries.map((entry) {
                          return _buildCategoryChip(
                            context,
                            theme,
                            notesProvider,
                            currentNote,
                            categoryName: entry.key,
                            icon: entry.value['icon'],
                            color: entry.value['color'],
                          );
                        }).toList(),
                      ),

                      // Custom categories section
                      if (customCategories.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'CUSTOM',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: customCategories.map((category) {
                            return _buildCategoryChip(
                              context,
                              theme,
                              notesProvider,
                              currentNote,
                              categoryName: category,
                              icon: Iconsax.folder_open_copy,
                              color: theme.primaryColor,
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Add new category button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddCategoryDialog(context, currentNote);
                          },
                          icon: Icon(Icons.add, color: theme.primaryColor),
                          label: Text(
                            'Create Custom Category',
                            style: TextStyle(color: theme.primaryColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.primaryColor, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(color: theme.secondaryTextColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryChip(
      BuildContext context,
      theme,
      NotesProvider notesProvider,
      Note currentNote, {
        required String categoryName,
        required IconData icon,
        required Color color,
      }) {
    final isSelected = currentNote.category == categoryName;

    return InkWell(
      onTap: () async {
        await notesProvider.setNoteCategory(currentNote.id, categoryName);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : theme.cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : theme.secondaryTextColor.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : theme.textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              categoryName,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, Note note) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentAppTheme;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Category', style: TextStyle(color: theme.textColor)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'Enter category name',
            hintStyle: TextStyle(color: theme.secondaryTextColor),
            filled: true,
            fillColor: theme.backgroundColor.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.secondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                await notesProvider.setNoteCategory(note.id, controller.text.trim());
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}