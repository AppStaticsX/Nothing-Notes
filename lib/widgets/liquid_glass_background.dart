import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final double borderRadius;
  final VoidCallback onTap;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.size = 80,
    this.iconSize = 40,
    this.borderRadius = 25,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(
      context,
      listen: false,
    );

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeProvider.currentAppTheme.cardColor.withValues(alpha: 0.5),
                  themeProvider.currentAppTheme.cardColor.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: themeProvider.currentAppTheme.primaryColor.withValues(alpha: 0.3),
                width: 4,
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: themeProvider.currentAppTheme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}