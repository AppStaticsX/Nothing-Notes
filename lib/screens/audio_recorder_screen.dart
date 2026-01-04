import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

/// Show audio recorder as a modal bottom sheet
Future<String?> showAudioRecorderBottomSheet({
  required BuildContext context,
  required String noteId,
  String? existingAudioPath,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => AudioRecorderBottomSheet(
      noteId: noteId,
      existingAudioPath: existingAudioPath,
    ),
  );
}

/// Professional audio recording bottom sheet with advanced features
class AudioRecorderBottomSheet extends StatefulWidget {
  final String noteId;
  final String? existingAudioPath;

  const AudioRecorderBottomSheet({
    super.key,
    required this.noteId,
    this.existingAudioPath,
  });

  @override
  State<AudioRecorderBottomSheet> createState() => _AudioRecorderBottomSheetState();
}

class _AudioRecorderBottomSheetState extends State<AudioRecorderBottomSheet>
    with TickerProviderStateMixin {
  // Recorder
  final AudioRecorder _recorder = AudioRecorder();

  // Audio Player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State variables
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  bool _isPlaying = false;
  bool _isInitialized = false;

  String? _recordedFilePath;
  Duration _recordedDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  // Timer for recording duration
  Timer? _recordingTimer;

  // Stream subscriptions
  StreamSubscription? _playerPositionSubscription;
  StreamSubscription? _playerStateSubscription;

  // Animation controllers
  late AnimationController _recordingAnimationController;
  late Animation<double> _recordingAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeControllers();
  }

  void _initializeAnimations() {
    _recordingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _recordingAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _recordingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initializeControllers() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          _showErrorSnackBar(
            'Microphone permission is required to record audio',
          );
          Navigator.pop(context);
        }
        return;
      }

      // Check if recorder is available
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          _showErrorSnackBar('Microphone permission denied');
          Navigator.pop(context);
        }
        return;
      }

      // If there's an existing audio file, initialize player
      if (widget.existingAudioPath != null &&
          File(widget.existingAudioPath!).existsSync()) {
        _recordedFilePath = widget.existingAudioPath;
        await _initializePlayer();
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to initialize: $e');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _initializePlayer() async {
    if (_recordedFilePath == null) return;

    try {
      // Cancel existing subscriptions before reinitializing
      await _playerPositionSubscription?.cancel();
      await _playerStateSubscription?.cancel();

      // Set audio source
      await _audioPlayer.setSourceDeviceFile(_recordedFilePath!);

      // Get duration
      final duration = await _audioPlayer.getDuration();
      if (duration != null) {
        setState(() {
          _recordedDuration = duration;
        });
      }

      // Listen to player position changes
      _playerPositionSubscription = _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });

      // Listen to player state changes
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });

          // Reset position when completed - don't call stop() to keep source intact
          if (state == PlayerState.completed) {
            setState(() {
              _isPlaying = false;
              _currentPosition = Duration.zero;
            });
          }
        }
      });
    } catch (e) {
      _showErrorSnackBar('Failed to initialize player: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordedFilePath = filePath;
        _recordedDuration = Duration.zero;
      });

      // Start timer to track recording duration
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted && _isRecording && !_isRecordingPaused) {
          setState(() {
            _recordedDuration = Duration(
              milliseconds: _recordedDuration.inMilliseconds + 100
            );
          });
        }
      });
    } catch (e) {
      _showErrorSnackBar('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      // Stop the recording
      final path = await _recorder.stop();

      // Cancel the recording timer
      _recordingTimer?.cancel();
      _recordingTimer = null;

      setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
        if (path != null) {
          _recordedFilePath = path;
        }
      });

      // Initialize player for playback
      await _initializePlayer();
    } catch (e) {
      _showErrorSnackBar('Failed to stop recording: $e');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _recorder.pause();
      _recordingTimer?.cancel();

      setState(() {
        _isRecordingPaused = true;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to pause recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _recorder.resume();

      // Resume the recording timer
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted && _isRecording && !_isRecordingPaused) {
          setState(() {
            _recordedDuration = Duration(
              milliseconds: _recordedDuration.inMilliseconds + 100
            );
          });
        }
      });

      setState(() {
        _isRecordingPaused = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to resume recording: $e');
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordedFilePath == null) return;

    try {
      if (_isPlaying) {
        // Pause playback
        await _audioPlayer.pause();
      } else {
        // Start/resume playback
        if (_currentPosition == Duration.zero) {
          // Restart from beginning - set source again to ensure it's properly initialized
          await _audioPlayer.stop();
          await _audioPlayer.setSourceDeviceFile(_recordedFilePath!);
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.resume();
        } else {
          // Resume from current position
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Playback error: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }


  Future<void> _deleteRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _recordedFilePath != null) {
      try {
        // Stop playback if playing
        if (_isPlaying) {
          await _audioPlayer.stop();
        }

        // Delete the file
        final file = File(_recordedFilePath!);
        if (file.existsSync()) {
          await file.delete();
        }

        setState(() {
          _recordedFilePath = null;
          _recordedDuration = Duration.zero;
          _currentPosition = Duration.zero;
        });

        _showSuccessSnackBar('Recording deleted');
      } catch (e) {
        _showErrorSnackBar('Failed to delete recording: $e');
      }
    }
  }

  Future<void> _saveRecording() async {
    if (_recordedFilePath == null) {
      _showErrorSnackBar('No recording to save');
      return;
    }

    try {
      // Show rename dialog
      final fileName = await _showRenameDialog();
      if (fileName == null) return; // User cancelled

      // Copy audio file to note's directory
      final appDir = await getApplicationDocumentsDirectory();
      final notesFilesDir = Directory('${appDir.path}/note_files/${widget.noteId}');

      // Create directory if it doesn't exist
      if (!await notesFilesDir.exists()) {
        await notesFilesDir.create(recursive: true);
      }

      // Generate unique filename with custom name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _recordedFilePath!.split('.').last;
      final newPath = '${notesFilesDir.path}/${timestamp}_$fileName.$extension';

      // Copy file to note's directory
      final File savedFile = await File(_recordedFilePath!).copy(newPath);

      if (mounted) {
        Navigator.pop(context, savedFile.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save recording: $e');
    }
  }

  Future<String?> _showRenameDialog() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentAppTheme;
    final controller = TextEditingController(
      text: 'audio_recording_${DateTime.now().millisecondsSinceEpoch}',
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'Name Your Recording',
          style: TextStyle(color: theme.textColor),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'Enter recording name',
            hintStyle: TextStyle(color: theme.secondaryTextColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.primaryColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.secondaryTextColor),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                Navigator.pop(context, 'audio_recording');
              } else {
                Navigator.pop(context, name);
              }
            },
            child: Text(
              'Save',
              style: TextStyle(color: theme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordingAnimationController.dispose();
    _playerPositionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).currentAppTheme;

    if (!_isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: theme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Initializing...',
                  style: TextStyle(color: theme.secondaryTextColor),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.secondaryTextColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(
                    'Audio Recorder',
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  IconButton(
                    icon: Icon(Iconsax.close_circle_copy, color: theme.textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Recording duration or playback position
                    _buildDurationDisplay(theme),

                    const SizedBox(height: 24),

                    // Waveform visualization
                    _buildWaveform(theme),

                    const SizedBox(height: 32),

                    // Control buttons
                    _buildControlButtons(theme),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationDisplay(dynamic theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          if (_isRecording)
            ScaleTransition(
              scale: _recordingAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isRecordingPaused
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isRecordingPaused
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _isRecordingPaused ? Colors.orange : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRecordingPaused ? 'Paused' : 'Recording',
                      style: TextStyle(
                        color: _isRecordingPaused ? Colors.orange : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_isRecording || _isPlaying
                ? (_isRecording ? _recordedDuration : _currentPosition)
                : _recordedDuration),
            style: TextStyle(
              color: theme.textColor,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_recordedDuration > Duration.zero && !_isRecording)
            Text(
              '/ ${_formatDuration(_recordedDuration)}',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaveform(dynamic theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 120,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.secondaryTextColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _isRecording
            ? _buildRecordingAnimation(theme)
            : (_recordedFilePath != null
                ? _buildPlaybackIndicator(theme)
                : Center(
                    child: Text(
                      'No audio recorded',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  )),
      ),
    );
  }

  Widget _buildRecordingAnimation(dynamic theme) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (index) {
          return AnimatedBuilder(
            animation: _recordingAnimationController,
            builder: (context, child) {
              final delay = index * 0.2;
              final value = (_recordingAnimationController.value + delay) % 1.0;
              final height = 20 + (40 * (0.5 + 0.5 * (value < 0.5 ? value * 2 : (1 - value) * 2)));

              return Container(
                width: 8,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildPlaybackIndicator(dynamic theme) {
    final progress = _recordedDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _recordedDuration.inMilliseconds
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPlaying ? Iconsax.pause_circle_copy : Iconsax.play_circle_copy,
              color: theme.primaryColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'Ready to play',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButtons(dynamic theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Record/Stop button
          _ControlButton(
            icon: _isRecording
                ? Iconsax.stop_copy
                : Iconsax.microphone_copy,
            backgroundColor: _isRecording
                ? Colors.grey[800]!
                : theme.primaryColor,
            iconColor: Colors.white,
            size: 72,
            onPressed: () {
              if (_isRecording) {
                _stopRecording();
              } else {
                _startRecording();
              }
            },
            label: _isRecording ? 'Stop' : 'Record',
          ),

          // Pause/Resume button (only when recording)
          if (_isRecording) ...[
            const SizedBox(width: 16),
            _ControlButton(
              icon: _isRecordingPaused ? Iconsax.play_copy : Iconsax.pause_copy,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.8),
              iconColor: Colors.white,
              size: 64,
              onPressed: () {
                if (_isRecordingPaused) {
                  _resumeRecording();
                } else {
                  _pauseRecording();
                }
              },
              label: _isRecordingPaused ? 'Resume' : 'Pause',
            ),
          ],

          // Play/Pause button (only when not recording and has recording)
          if (_recordedFilePath != null && !_isRecording) ...[
            const SizedBox(width: 16),
            _ControlButton(
              icon: _isPlaying ? Iconsax.pause_copy : Iconsax.play_copy,
              backgroundColor: theme.primaryColor,
              iconColor: Colors.white,
              size: 64,
              onPressed: _togglePlayback,
              label: _isPlaying ? 'Pause' : 'Play',
            ),

            // Delete button - moved from header
            const SizedBox(width: 16),
            _ControlButton(
              icon: Iconsax.trash_copy,
              backgroundColor: Colors.red[400]!,
              iconColor: Colors.white,
              size: 56,
              onPressed: _deleteRecording,
              label: 'Delete',
            ),

            // Save button - moved from header
            const SizedBox(width: 16),
            _ControlButton(
              icon: Iconsax.tick_circle_copy,
              backgroundColor: theme.primaryColor,
              iconColor: Colors.white,
              size: 56,
              onPressed: _saveRecording,
              label: 'Save',
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Professional control button widget
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final VoidCallback onPressed;
  final String? label;

  const _ControlButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.size,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.4),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: TextStyle(
              color: backgroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
