import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:notes_app/screens/local_auth_setup_screen.dart';
import 'package:notes_app/screens/lock_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typethis/typethis.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_theme.dart';
import '../models/editor_style.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/editor_style_painter.dart';
import '../widgets/liquid_glass_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _marginLineOffset = 0.0;
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadMarginLineOffset();
    _loadAppLockStatus();
  }

  Future<void> _loadAppLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool isAppLocked = prefs.getBool('app_lock_enabled') ?? false;

    if (!mounted) return;

    setState(() {
      _appLockEnabled = isAppLocked;
    });
  }

  void _handleAppLockToggle(bool enable) {
    if (enable) {
      // Enable: Go to setup logic
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LocalAuthSetupScreen()),
      ).then((_) => _loadAppLockStatus());
    } else {
      // Disable: Verify PIN first
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LockScreen(
            onSuccess: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('app_lock_enabled', false);

              if (context.mounted) {
                // Determine theme color for snackbar
                final themeProvider = Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                );

                Navigator.pop(context); // Close LockScreen

                setState(() {
                  _appLockEnabled = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('App lock disabled'),
                    backgroundColor: themeProvider.currentAppTheme.primaryColor,
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _loadMarginLineOffset() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _marginLineOffset = prefs.getDouble('marginLineOffset') ?? 0.0;
    });
  }

  Future<void> _saveMarginLineOffset(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('marginLineOffset', value);
    setState(() {
      _marginLineOffset = value;
    });
  }

  Future<void> _pickCustomFont(
    BuildContext context,
    ThemeProvider themeProvider,
    SettingsProvider settingsProvider,
  ) async {
    try {
      // Use file_picker to select a font file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );

      if (result != null && result.files.single.path != null) {
        final fontPath = result.files.single.path!;
        final fontName = result.files.single.name.replaceAll(
          RegExp(r'\.(ttf|otf)$'),
          '',
        );

        // Load the custom font
        await settingsProvider.loadCustomFont(fontPath, fontName);
        themeProvider.setAppFontFamily(fontName);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom font "$fontName" loaded successfully'),
              backgroundColor: themeProvider.currentAppTheme.primaryColor,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load custom font: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickEditorCustomFont(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
      );

      if (result != null && result.files.single.path != null) {
        final fontPath = result.files.single.path!;
        final fontName = result.files.single.name.replaceAll(
          RegExp(r'\.(ttf|otf)$'),
          '',
        );

        await settingsProvider.loadCustomFont(fontPath, fontName);
        await settingsProvider.setFontFamily(fontName);

        if (context.mounted) {
          final themeProvider = Provider.of<ThemeProvider>(
            context,
            listen: false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Editor font "$fontName" loaded successfully'),
              backgroundColor: themeProvider.currentAppTheme.primaryColor,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load custom font: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = themeProvider.currentAppTheme;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
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
        ),
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Customize your writing experience',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Icon(
              CupertinoIcons.settings,
              color: theme.primaryColor,
              size: 32,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(16.0),
          child: const SizedBox(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Appearance Section
                _buildSection(
                  theme: theme,
                  icon: Iconsax.color_swatch,
                  iconColor: theme.primaryColor,
                  title: 'Appearance',
                  subtitle: 'Choose your preferred theme and color scheme',
                  child: _buildThemeGrid(theme, themeProvider),
                ),
                const SizedBox(height: 24),

                // Typography Section
                _buildSection(
                  theme: theme,
                  icon: Icons.text_fields,
                  iconColor: theme.primaryColor,
                  title: 'Typography',
                  subtitle:
                      'Customize fonts and text sizes for better readability',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'App Font Family',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAppFontFamilyOptions(
                        theme,
                        themeProvider,
                        settingsProvider,
                        context,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Editor Text Size',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFontSizeOptions(theme, settingsProvider),
                      const SizedBox(height: 24),
                      Text(
                        'Editor Font Family',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFontFamilyOptions(theme, settingsProvider),
                      const SizedBox(height: 24),
                      _buildPreviewBox(theme, settingsProvider),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Editor Face Section
                _buildSection(
                  theme: theme,
                  icon: Iconsax.code_copy,
                  iconColor: theme.primaryColor,
                  title: 'Editor Face',
                  subtitle: 'Select the visual style for your editor surface',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Visual Style',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildEditorStyleOptions(theme, settingsProvider),
                      const SizedBox(height: 24),
                      _buildEditorStylePreview(theme, settingsProvider),
                      // Only show line opacity if editor style is not plain
                      if (settingsProvider.editorStyle !=
                          EditorStyle.plain) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Line Opacity - ${(settingsProvider.lineOpacity * 100).toInt()}%',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildLineOpacityOptions(theme, settingsProvider),
                      ],
                      const SizedBox(height: 30),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Margin Line Offset: ${_marginLineOffset.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Iconsax.minus_copy),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    // Thumb customization
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 12.0,
                                    ),
                                    thumbColor: theme.primaryColor,

                                    // Track customization
                                    trackShape: RoundedRectSliderTrackShape(),
                                    trackHeight: 4.0,
                                    activeTrackColor: theme.primaryColor,
                                    inactiveTrackColor: theme.secondaryTextColor
                                        .withValues(alpha: 0.5),

                                    // Overlay (the ripple when pressed)
                                    overlayShape: RoundSliderOverlayShape(
                                      overlayRadius: 24.0,
                                    ),
                                    overlayColor: theme.primaryColor.withValues(
                                      alpha: 0.2,
                                    ),

                                    // Value indicator (the label)
                                    valueIndicatorShape:
                                        PaddleSliderValueIndicatorShape(),
                                    valueIndicatorColor: theme.primaryColor,
                                    valueIndicatorTextStyle: TextStyle(
                                      color: theme.textColor,
                                    ),
                                  ),
                                  child: Slider(
                                    value: _marginLineOffset,
                                    min: 0,
                                    max: 100,
                                    divisions: 100,
                                    label: _marginLineOffset.toStringAsFixed(0),
                                    onChanged: (value) {
                                      _saveMarginLineOffset(value);
                                    },
                                  ),
                                ),
                              ),
                              Icon(Iconsax.add_copy),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  theme: theme,
                  icon: Iconsax.lock,
                  iconColor: theme.primaryColor,
                  title: 'Security & Privacy',
                  subtitle: 'Protect your personal notes',
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          _handleAppLockToggle(!_appLockEnabled);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Enable App Lock',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch(
                              value: _appLockEnabled,
                              onChanged: (bool value) {
                                _handleAppLockToggle(value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // App Info
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Nothing Notes v1.0.1',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Made with ',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          SvgPicture.asset(
                            'assets/icons/flutter-svgrepo-com.svg',
                            width: 16,
                            height: 16,
                          ),
                          Text(
                            ' for thoughtful writing',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required AppTheme theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildThemeGrid(AppTheme currentTheme, ThemeProvider themeProvider) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: AppTheme.allThemes.length,
      itemBuilder: (context, index) {
        final theme = AppTheme.allThemes[index];
        final isSelected = theme.name == currentTheme.name;

        return InkWell(
          onTap: () => themeProvider.setTheme(theme),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : theme.secondaryTextColor.withValues(alpha: 0.3),
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  theme.name,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: theme.colorPalette.take(6).map((color) {
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.secondaryTextColor.withValues(
                            alpha: 0.2,
                          ),
                          width: 1,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppFontFamilyOptions(
    AppTheme theme,
    ThemeProvider themeProvider,
    SettingsProvider settingsProvider,
    BuildContext context,
  ) {
    final customFontName = settingsProvider.customFontName;
    final isCustomFontSelected =
        customFontName != null && customFontName == themeProvider.appFontFamily;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...settingsProvider.fontFamilies.map((family) {
              final isSelected = family == themeProvider.appFontFamily;
              return InkWell(
                onTap: () => themeProvider.setAppFontFamily(family),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.backgroundColor,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isSelected
                          ? theme.primaryColor
                          : theme.secondaryTextColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    family,
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: family,
                    ),
                  ),
                ),
              );
            }),
            InkWell(
              onTap: () =>
                  _pickCustomFont(context, themeProvider, settingsProvider),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isCustomFontSelected
                      ? theme.primaryColor
                      : theme.backgroundColor,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isCustomFontSelected
                        ? theme.primaryColor
                        : theme.primaryColor.withValues(alpha: 0.5),
                    width: isCustomFontSelected ? 1 : 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCustomFontSelected
                          ? Iconsax.tick_circle
                          : Iconsax.add_copy,
                      color: isCustomFontSelected
                          ? Colors.white
                          : theme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCustomFontSelected ? customFontName : 'Custom Font',
                      style: TextStyle(
                        color: isCustomFontSelected
                            ? Colors.white
                            : theme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFontSizeOptions(
    AppTheme theme,
    SettingsProvider settingsProvider,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: settingsProvider.fontSizes.map((size) {
        final isSelected = size == settingsProvider.fontSize;
        return InkWell(
          onTap: () => settingsProvider.setFontSize(size),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? theme.primaryColor : theme.backgroundColor,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : theme.secondaryTextColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${size.toInt()}px',
              style: TextStyle(
                color: isSelected ? Colors.white : theme.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontFamilyOptions(
    AppTheme theme,
    SettingsProvider settingsProvider,
  ) {
    final customFontName = settingsProvider.customFontName;
    final isCustomFontSelected =
        customFontName != null && customFontName == settingsProvider.fontFamily;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...settingsProvider.fontFamilies.map((family) {
          final isSelected = family == settingsProvider.fontFamily;
          return InkWell(
            onTap: () => settingsProvider.setFontFamily(family),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? theme.primaryColor : theme.backgroundColor,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected
                      ? theme.primaryColor
                      : theme.secondaryTextColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                family,
                style: TextStyle(
                  color: isSelected ? Colors.white : theme.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: family,
                ),
              ),
            ),
          );
        }),
        Builder(
          builder: (context) => InkWell(
            onTap: () => _pickEditorCustomFont(context, settingsProvider),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isCustomFontSelected
                    ? theme.primaryColor
                    : theme.backgroundColor,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isCustomFontSelected
                      ? theme.primaryColor
                      : theme.primaryColor.withValues(alpha: 0.5),
                  width: isCustomFontSelected ? 1 : 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCustomFontSelected
                        ? Iconsax.tick_circle
                        : Iconsax.add_copy,
                    color: isCustomFontSelected
                        ? Colors.white
                        : theme.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCustomFontSelected ? customFontName : 'Custom Font',
                    style: TextStyle(
                      color: isCustomFontSelected
                          ? Colors.white
                          : theme.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBox(AppTheme theme, SettingsProvider settingsProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TypeThis(
            key: ValueKey(
              '${settingsProvider.fontFamily}_${settingsProvider.fontSize}_${theme.textColor}',
            ),
            string: 'The quick brown fox jumps over the lazy dog.',
            speed: 150,
            style: TextStyle(
              color: theme.textColor,
              fontSize: settingsProvider.fontSize,
              fontFamily: settingsProvider.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorStyleOptions(
    AppTheme theme,
    SettingsProvider settingsProvider,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EditorStyle.values.map((style) {
        final isSelected = style == settingsProvider.editorStyle;
        return InkWell(
          onTap: () => settingsProvider.setEditorStyle(style),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? theme.primaryColor : theme.backgroundColor,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : theme.secondaryTextColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              style.displayName,
              style: TextStyle(
                color: isSelected ? Colors.white : theme.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditorStylePreview(
    AppTheme theme,
    SettingsProvider settingsProvider,
  ) {
    return Container(
      width: double.infinity,
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVE SAMPLE',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: CustomPaint(
                painter: EditorStylePainter(
                  style: settingsProvider.editorStyle,
                  lineColor: theme.secondaryTextColor.withValues(
                    alpha: settingsProvider.lineOpacity,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: Text(
                      '${settingsProvider.editorStyle.displayName} grid',
                      style: TextStyle(color: theme.textColor, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineOpacityOptions(
    AppTheme theme,
    SettingsProvider settingsProvider,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: settingsProvider.lineOpacities.map((opacity) {
        final isSelected =
            (opacity - settingsProvider.lineOpacity).abs() < 0.01;
        return InkWell(
          onTap: () => settingsProvider.setLineOpacity(opacity),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? theme.primaryColor : theme.backgroundColor,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : theme.secondaryTextColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${(opacity * 100).toInt()}%',
              style: TextStyle(
                color: isSelected ? Colors.white : theme.textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
