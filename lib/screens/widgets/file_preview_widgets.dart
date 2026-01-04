import 'package:flutter/material.dart';
import 'package:notes_app/providers/settings_provider.dart';
import 'package:notes_app/providers/theme_provider.dart';
import 'package:notes_app/screens/configs/quill_file_helper.dart';
import 'package:notes_app/screens/widgets/file_viewer_bottom_sheet.dart';
import 'package:provider/provider.dart';

/// File preview list widget - only rebuilds when files change
class FilePreviewList extends StatelessWidget {
  final List<String> files;
  final double marginLineOffset;
  final Function(String) onDeleteFile;

  const FilePreviewList({
    super.key,
    required this.files,
    required this.marginLineOffset,
    required this.onDeleteFile,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: ListView.builder(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: marginLineOffset + 16, right: 16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final filePath = files[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: _FileCard(
                  key: ValueKey(
                    filePath,
                  ), // Added ValueKey for efficient list updates
                  filePath: filePath,
                  onDelete: () => onDeleteFile(filePath),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Individual file card widget - Only rebuilds when theme or settings change
class _FileCard extends StatelessWidget {
  final String filePath;
  final VoidCallback onDelete;

  const _FileCard({super.key, required this.filePath, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    // Pre-calculate file info (doesn't depend on providers)
    final fileName = QuillFileHelper.getFileName(filePath);
    final fileExtension = QuillFileHelper.getFileExtension(filePath);
    final fileSize = QuillFileHelper.getFileSize(filePath);
    final fileIcon = QuillFileHelper.getFileIcon(filePath);
    final fileIconColor = QuillFileHelper.getFileIconColor(filePath);

    // Use Consumer2 to only rebuild when theme or settings change
    return Consumer2<ThemeProvider, SettingsProvider>(
      builder: (context, themeProvider, settingsProvider, child) {
        final theme = themeProvider.currentAppTheme;

        return GestureDetector(
          onTap: () => _showFileViewer(context),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: 50,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.secondaryTextColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // File icon
                      Icon(fileIcon, size: 44, color: fileIconColor),
                      const SizedBox(width: 12),
                      // File name (truncated)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName.length > 20
                                ? '${fileName.substring(0, 20)}...'
                                : fileName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.textColor,
                              fontFamily: settingsProvider.fontFamily,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: fileIconColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  fileExtension,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: fileIconColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                fileSize,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete button
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFileViewer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FileViewerBottomSheet(
        filePath: filePath,
        onDelete: () {
          Navigator.pop(context);
          onDelete();
        },
      ),
    );
  }
}
