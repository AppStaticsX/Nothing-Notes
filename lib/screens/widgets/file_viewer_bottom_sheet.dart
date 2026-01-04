import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../configs/quill_file_helper.dart';

/// File viewer bottom sheet - optimized to prevent unnecessary rebuilds
///
/// This widget is a StatelessWidget with all final fields to ensure
/// it only rebuilds when explicitly shown with new data.
class FileViewerBottomSheet extends StatelessWidget {
  final String filePath;
  final VoidCallback onDelete;

  const FileViewerBottomSheet({
    super.key,
    required this.filePath,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-calculate all file information BEFORE building UI
    // This prevents recalculation on rebuilds
    final fileName = QuillFileHelper.getFileName(filePath);
    final fileExtension = QuillFileHelper.getFileExtension(filePath);
    final fileSize = QuillFileHelper.getFileSize(filePath);
    final fileIcon = QuillFileHelper.getFileIcon(filePath);
    final fileIconColor = QuillFileHelper.getFileIconColor(filePath);

    // Get file date synchronously
    final file = File(filePath);
    final fileDate = file.existsSync()
        ? file.lastModifiedSync()
        : DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy').format(fileDate);

    return Container(
      decoration: BoxDecoration(
        color: Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).currentAppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            _DragHandle(),

            // Content with fixed height to prevent layout shifts
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _Header(onDelete: onDelete),

                    const SizedBox(height: 24),

                    // File preview
                    _FilePreview(
                      fileName: fileName,
                      fileIcon: fileIcon,
                      fileIconColor: fileIconColor,
                    ),

                    const SizedBox(height: 24),

                    // File information
                    _FileInformation(
                      fileExtension: fileExtension,
                      fileSize: fileSize,
                      formattedDate: formattedDate,
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    _ActionButtons(filePath: filePath),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drag handle widget - doesn't rebuild
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Header widget - only rebuilds when theme changes (which it won't in bottom sheet)
class _Header extends StatelessWidget {
  final VoidCallback onDelete;

  const _Header({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'File Viewer',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        IconButton(
          icon: Icon(Iconsax.trash_copy, color: theme.textColor),
          onPressed: onDelete,
          tooltip: 'Delete file',
        ),
      ],
    );
  }
}

/// File preview widget - doesn't rebuild (all data passed as final fields)
class _FilePreview extends StatelessWidget {
  final String fileName;
  final IconData fileIcon;
  final Color fileIconColor;

  const _FilePreview({
    required this.fileName,
    required this.fileIcon,
    required this.fileIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fileIcon, size: 80, color: fileIconColor),
          const SizedBox(height: 16),
          Text(
            fileName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// File information widget - doesn't rebuild (all data passed as final fields)
class _FileInformation extends StatelessWidget {
  final String fileExtension;
  final String fileSize;
  final String formattedDate;

  const _FileInformation({
    required this.fileExtension,
    required this.fileSize,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _InfoRow(
            label: 'Type',
            value: fileExtension.toUpperCase(),
            theme: theme,
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'Size', value: fileSize, theme: theme),
          const SizedBox(height: 16),
          _InfoRow(label: 'Added', value: formattedDate, theme: theme),
        ],
      ),
    );
  }
}

/// Info row widget - doesn't rebuild (all data passed as final fields)
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final dynamic theme;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, color: theme.secondaryTextColor),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: theme.textColor,
          ),
        ),
      ],
    );
  }
}

/// Action buttons widget - doesn't rebuild (stable callback)
class _ActionButtons extends StatelessWidget {
  final String filePath;

  const _ActionButtons({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            onPressed: () => _openFile(context),
            icon: Iconsax.folder_open_copy,
            label: 'Open',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionButton(
            onPressed: () => _shareFile(context),
            icon: Iconsax.share_copy,
            label: 'Share',
          ),
        ),
      ],
    );
  }

  Future<void> _openFile(BuildContext context) async {
    try {
      await QuillFileHelper.openFile(filePath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
      }
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      await QuillFileHelper.shareFile(filePath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share file: $e')));
      }
    }
  }
}

/// Individual action button - doesn't rebuild
class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFB2E0D8),
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
    );
  }
}
