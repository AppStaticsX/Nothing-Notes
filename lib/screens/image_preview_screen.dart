import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';

/// Full-screen image preview screen with swipe navigation and zoom capabilities
class ImagePreviewScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final Function(String)? onDeleteImage;

  const ImagePreviewScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    this.onDeleteImage,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _images = List.from(widget.images);
    _pageController = PageController(initialPage: widget.initialIndex);

    // Hide status bar for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _shareCurrentImage() async {
    final currentImagePath = _images[_currentIndex];
    final file = File(currentImagePath);

    if (await file.exists()) {
      await SharePlus.instance.share(
        ShareParams(text: 'Share Image', files: [XFile(currentImagePath)]),
      );
    }
  }

  Future<void> _deleteCurrentImage() async {
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

    if (confirmed == true && mounted) {
      final deletedImage = _images[_currentIndex];

      setState(() {
        _images.removeAt(_currentIndex);
      });

      // Call the delete callback
      if (widget.onDeleteImage != null) {
        widget.onDeleteImage!(deletedImage);
      }

      // If no images left, close the preview
      if (_images.isEmpty) {
        if (mounted) {
          Navigator.pop(context, _images);
        }
        return;
      }

      // Adjust current index if needed
      if (_currentIndex >= _images.length) {
        _currentIndex = _images.length - 1;
        _pageController.jumpToPage(_currentIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView for image swiping
          _ImagePageView(
            pageController: _pageController,
            images: _images,
            onPageChanged: _onPageChanged,
          ),

          // Top bar with close, share, and delete buttons
          _TopBar(
            onClose: () => Navigator.pop(context, _images),
            onShare: _shareCurrentImage,
            onDelete: _deleteCurrentImage,
          ),

          // Bottom image counter
          _ImageCounter(
            currentIndex: _currentIndex,
            totalImages: _images.length,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXTRACTED WIDGETS - These prevent unnecessary rebuilds
// ============================================================================

/// PageView widget - only rebuilds when images list changes
class _ImagePageView extends StatelessWidget {
  final PageController pageController;
  final List<String> images;
  final ValueChanged<int> onPageChanged;

  const _ImagePageView({
    required this.pageController,
    required this.images,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pageController,
      onPageChanged: onPageChanged,
      itemCount: images.length,
      itemBuilder: (context, index) {
        return _ZoomableImage(imagePath: images[index]);
      },
    );
  }
}

/// Top bar widget - doesn't rebuild
class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _TopBar({
    required this.onClose,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              IconButton(
                onPressed: onClose,
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
              // Action buttons (share and delete)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Share button
                  IconButton(
                    onPressed: onShare,
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.share,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  // Delete button
                  IconButton(
                    onPressed: onDelete,
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.trash_copy,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Image counter widget - only rebuilds when currentIndex or totalImages changes
class _ImageCounter extends StatelessWidget {
  final int currentIndex;
  final int totalImages;

  const _ImageCounter({required this.currentIndex, required this.totalImages});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentIndex + 1} / $totalImages',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zoomable image widget using InteractiveViewer
class _ZoomableImage extends StatelessWidget {
  final String imagePath;

  const _ZoomableImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
