import 'dart:convert';

class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  String? category;
  List<String> tags;
  bool isArchived;
  bool isFavorite;
  String? templateType;
  Map<String, dynamic>? formatting;

  // Reminder fields
  DateTime? reminderDateTime;
  bool hasReminder;
  int? notificationId;
  String? reminderRepeatType; // 'once', 'daily', 'weekly', 'monthly'

  // Cache for expensive computed properties
  String? _cachedPreview;
  int? _cachedWordCount;
  int? _cachedCharCount;
  String? _cachedPlainText;
  String? _lastProcessedContent;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.category,
    this.tags = const [],
    this.isArchived = false,
    this.isFavorite = false,
    this.templateType,
    this.formatting,
    this.reminderDateTime,
    this.hasReminder = false,
    this.notificationId,
    this.reminderRepeatType,
  });

  // ============================================================================
  // OPTIMIZED COMPUTED PROPERTIES WITH CACHING
  // ============================================================================

  /// Get word count with caching
  int get wordCount {
    if (_cachedWordCount != null && _lastProcessedContent == content) {
      return _cachedWordCount!;
    }

    final plainText = _getPlainText();
    if (plainText.trim().isEmpty) {
      _cachedWordCount = 0;
    } else {
      _cachedWordCount = plainText
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
    }

    return _cachedWordCount!;
  }

  /// Get character count with caching
  int get characterCount {
    if (_cachedCharCount != null && _lastProcessedContent == content) {
      return _cachedCharCount!;
    }

    final plainText = _getPlainText();
    _cachedCharCount = plainText.replaceAll(RegExp(r'\s'), '').length;
    return _cachedCharCount!;
  }

  /// Get preview with caching
  String get preview {
    if (_cachedPreview != null && _lastProcessedContent == content) {
      return _cachedPreview!;
    }

    _cachedPreview = _computePreview();
    _lastProcessedContent = content;
    return _cachedPreview!;
  }

  // ============================================================================
  // REMINDER HELPER METHODS
  // ============================================================================

  /// Check if reminder is set and in the future
  bool get isReminderActive {
    if (!hasReminder || reminderDateTime == null) return false;
    return reminderDateTime!.isAfter(DateTime.now());
  }

  /// Check if reminder time has passed
  bool get isReminderPast {
    if (!hasReminder || reminderDateTime == null) return false;
    return reminderDateTime!.isBefore(DateTime.now());
  }

  /// Get formatted reminder time string
  String get reminderFormatted {
    if (reminderDateTime == null) return '';

    final now = DateTime.now();
    final difference = reminderDateTime!.difference(now);

    if (difference.isNegative) {
      return 'Reminder passed';
    } else if (difference.inMinutes < 60) {
      return 'in ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'in ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Tomorrow ${reminderDateTime!.hour}:${reminderDateTime!.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'in ${difference.inDays}d';
    } else {
      return '${reminderDateTime!.day}/${reminderDateTime!.month}/${reminderDateTime!.year}';
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Get plain text with caching
  String _getPlainText() {
    if (_cachedPlainText != null && _lastProcessedContent == content) {
      return _cachedPlainText!;
    }

    String plainText = content;
    if (content.trim().startsWith('[')) {
      try {
        plainText = _extractPlainTextFromQuill(content);
      } catch (e) {
        plainText = content;
      }
    }

    _cachedPlainText = plainText;
    _lastProcessedContent = content;
    return plainText;
  }

  /// Compute preview text
  String _computePreview() {
    final plainText = _getPlainText();
    if (plainText.isEmpty) return '';
    return plainText.length > 100
        ? '${plainText.substring(0, 100)}...'
        : plainText;
  }

  /// Extract plain text from Quill JSON format
  String _extractPlainTextFromQuill(String jsonContent) {
    try {
      final List<dynamic> delta = jsonDecode(jsonContent);
      final StringBuffer buffer = StringBuffer();

      for (var op in delta) {
        if (op is Map && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      return jsonContent;
    }
  }

  /// Clear all cached values
  void _clearCache() {
    _cachedPreview = null;
    _cachedWordCount = null;
    _cachedCharCount = null;
    _cachedPlainText = null;
    _lastProcessedContent = null;
  }

  // ============================================================================
  // SERIALIZATION
  // ============================================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned ? 1 : 0,
      'category': category,
      'tags': tags.join(','),
      'isArchived': isArchived ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'templateType': templateType,
      'formatting': formatting?.toString(),
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'hasReminder': hasReminder ? 1 : 0,
      'notificationId': notificationId,
      'reminderRepeatType': reminderRepeatType,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'category': category,
      'tags': tags,
      'isArchived': isArchived,
      'isFavorite': isFavorite,
      'templateType': templateType,
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'hasReminder': hasReminder,
      'notificationId': notificationId,
      'reminderRepeatType': reminderRepeatType,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      isPinned: map['isPinned'] == 1,
      category: map['category'],
      tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
          ? (map['tags'] as String).split(',')
          : [],
      isArchived: (map['isArchived'] ?? 0) == 1,
      isFavorite: (map['isFavorite'] ?? 0) == 1,
      templateType: map['templateType'],
      reminderDateTime: map['reminderDateTime'] != null
          ? DateTime.parse(map['reminderDateTime'])
          : null,
      hasReminder: (map['hasReminder'] ?? 0) == 1,
      notificationId: map['notificationId'],
      reminderRepeatType: map['reminderRepeatType'],
    );
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPinned: json['isPinned'] as bool? ?? false,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isArchived: json['isArchived'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      templateType: json['templateType'] as String?,
      reminderDateTime: json['reminderDateTime'] != null
          ? DateTime.parse(json['reminderDateTime'] as String)
          : null,
      hasReminder: json['hasReminder'] as bool? ?? false,
      notificationId: json['notificationId'] as int?,
      reminderRepeatType: json['reminderRepeatType'] as String?,
    );
  }

  // ============================================================================
  // COPY WITH (OPTIMIZED)
  // ============================================================================

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    String? category,
    List<String>? tags,
    bool? isArchived,
    bool? isFavorite,
    String? templateType,
    Map<String, dynamic>? formatting,
    // Use Object? to allow explicit null values
    Object? reminderDateTime = _undefined,
    bool? hasReminder,
    Object? notificationId = _undefined,
    Object? reminderRepeatType = _undefined,
  }) {
    final newNote = Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isArchived: isArchived ?? this.isArchived,
      isFavorite: isFavorite ?? this.isFavorite,
      templateType: templateType ?? this.templateType,
      formatting: formatting ?? this.formatting,
      // Handle nullable fields explicitly
      reminderDateTime: reminderDateTime == _undefined
          ? this.reminderDateTime
          : reminderDateTime as DateTime?,
      hasReminder: hasReminder ?? this.hasReminder,
      notificationId: notificationId == _undefined
          ? this.notificationId
          : notificationId as int?,
      reminderRepeatType: reminderRepeatType == _undefined
          ? this.reminderRepeatType
          : reminderRepeatType as String?,
    );

    // Only clear cache if content actually changed
    if (content != null && content != this.content) {
      newNote._clearCache();
    } else {
      // Preserve cache for better performance
      newNote._cachedPreview = _cachedPreview;
      newNote._cachedWordCount = _cachedWordCount;
      newNote._cachedCharCount = _cachedCharCount;
      newNote._cachedPlainText = _cachedPlainText;
      newNote._lastProcessedContent = _lastProcessedContent;
    }

    return newNote;
  }

  // Sentinel value to distinguish between null and undefined
  static const _undefined = Object();

  // ============================================================================
  // EQUALITY AND HASH
  // ============================================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^ title.hashCode ^ content.hashCode ^ updatedAt.hashCode;
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if note is empty
  bool get isEmpty {
    return title.trim().isEmpty && content.trim().isEmpty;
  }

  /// Check if note has content
  bool get hasContent {
    return content.trim().isNotEmpty;
  }

  /// Get age of note in days
  int get ageInDays {
    return DateTime.now().difference(createdAt).inDays;
  }

  /// Get last modified time in hours
  int get lastModifiedHours {
    return DateTime.now().difference(updatedAt).inHours;
  }

  /// Check if note was modified today
  bool get isModifiedToday {
    final now = DateTime.now();
    return updatedAt.year == now.year &&
        updatedAt.month == now.month &&
        updatedAt.day == now.day;
  }

  /// Check if note was created today
  bool get isCreatedToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  /// Get formatted date string
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  /// Get reading time in minutes
  int get readingTimeMinutes {
    final words = wordCount;
    // Average reading speed: 200-250 words per minute
    // Using 200 for conservative estimate
    return (words / 200).ceil();
  }

  /// Get note size in bytes
  int get sizeInBytes {
    return content.length + title.length;
  }

  /// Get note size in KB
  double get sizeInKB {
    return sizeInBytes / 1024;
  }

  // ============================================================================
  // DEBUG
  // ============================================================================

  @override
  String toString() {
    return 'Note(id: $id, title: $title, isPinned: $isPinned, isFavorite: $isFavorite, category: $category, tags: $tags)';
  }

  /// Get debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'id': id,
      'title': title,
      'wordCount': wordCount,
      'characterCount': characterCount,
      'sizeInKB': sizeInKB.toStringAsFixed(2),
      'readingTime': '$readingTimeMinutes min',
      'ageInDays': ageInDays,
      'lastModifiedHours': lastModifiedHours,
      'isPinned': isPinned,
      'isFavorite': isFavorite,
      'isArchived': isArchived,
      'category': category,
      'tagsCount': tags.length,
      'hasCache': _cachedPlainText != null,
      'hasReminder': hasReminder,
      'reminderActive': isReminderActive,
    };
  }
}
