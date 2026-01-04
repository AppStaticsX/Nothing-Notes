import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/note_template.dart';
import '../services/database_helper.dart';
import '../services/import_service.dart';
import '../services/reminder_service.dart';

class NotesProvider with ChangeNotifier {
  // Core data
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  String _searchQuery = '';
  final _uuid = const Uuid();

  // Loading states
  bool _isLoading = false;
  bool _hasMoreNotes = true;
  int _currentPage = 0;
  static const int PAGE_SIZE = 50; // Increased for better performance

  // Filter states
  bool _showArchived = false;
  bool _showFavoritesOnly = false;
  String? _selectedCategory;
  List<String> _selectedTags = [];

  // Cache for expensive operations
  Map<String, int> _categoryCountsCache = {};
  List<String> _allTagsCache = [];
  List<String> _allCategoriesCache = [];
  DateTime? _lastCacheUpdate;
  static const Duration CACHE_DURATION = Duration(minutes: 5);

  // Search debouncing
  Timer? _searchDebounce;
  static const Duration SEARCH_DEBOUNCE_DURATION = Duration(milliseconds: 300);

  // Getters
  List<Note> get notes {
    var notesList = _searchQuery.isEmpty ? _notes : _filteredNotes;

    // Filter archived
    if (!_showArchived) {
      notesList = notesList.where((n) => !n.isArchived).toList();
    }

    // Filter favorites only
    if (_showFavoritesOnly) {
      notesList = notesList.where((n) => n.isFavorite).toList();
    }

    // Filter by category
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      notesList = notesList
          .where((n) => n.category == _selectedCategory)
          .toList();
    }

    // Filter by tags (notes that have ANY of the selected tags)
    if (_selectedTags.isNotEmpty) {
      notesList = notesList
          .where((n) => _selectedTags.any((tag) => n.tags.contains(tag)))
          .toList();
    }

    return notesList;
  }

  String get searchQuery => _searchQuery;
  bool get showArchived => _showArchived;
  bool get showFavoritesOnly => _showFavoritesOnly;
  String? get selectedCategory => _selectedCategory;
  List<String> get selectedTags => _selectedTags;
  bool get isLoading => _isLoading;
  bool get hasMoreNotes => _hasMoreNotes;

  bool get hasActiveFilters =>
      _showArchived ||
      _showFavoritesOnly ||
      _selectedCategory != null ||
      _selectedTags.isNotEmpty;

  // ============================================================================
  // OPTIMIZED LOADING WITH PAGINATION
  // ============================================================================

  /// Load notes with pagination support
  /// Set [refresh] to true to reload from beginning
  Future<void> loadNotes({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _notes.clear();
      _currentPage = 0;
      _hasMoreNotes = true;
    }

    if (!_hasMoreNotes) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newNotes = await DatabaseHelper.instance.readNotesPage(
        _currentPage,
        PAGE_SIZE,
      );

      if (newNotes.length < PAGE_SIZE) {
        _hasMoreNotes = false;
      }

      _notes.addAll(newNotes);
      _currentPage++;

      // Update cache periodically
      if (_shouldUpdateCache()) {
        await _updateCaches();
      }
    } catch (e) {
      //
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all notes at once (for backward compatibility)
  Future<void> loadAllNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notes = await DatabaseHelper.instance.readAllNotes();
      _hasMoreNotes = false;

      if (_shouldUpdateCache()) {
        await _updateCaches();
      }
    } catch (e) {
      //
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

  bool _shouldUpdateCache() {
    return _lastCacheUpdate == null ||
        DateTime.now().difference(_lastCacheUpdate!) > CACHE_DURATION;
  }

  Future<void> _updateCaches() async {
    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getNotesCountByCategory(),
        DatabaseHelper.instance.getAllTags(),
        DatabaseHelper.instance.getAllCategories(),
      ]);

      _categoryCountsCache = results[0] as Map<String, int>;
      _allTagsCache = results[1] as List<String>;
      _allCategoriesCache = results[2] as List<String>;
      _lastCacheUpdate = DateTime.now();
    } catch (e) {
      //
    }
  }

  void _invalidateCache() {
    _lastCacheUpdate = null;
  }

  // ============================================================================
  // NOTE CRUD OPERATIONS (OPTIMIZED)
  // ============================================================================

  /// Create a new note
  Future<Note> createNote({
    String? title,
    String? content,
    String? templateType,
  }) async {
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      title: title ?? 'Untitled ${_notes.length + 1}',
      content: content ?? '',
      createdAt: now,
      updatedAt: now,
      templateType: templateType,
    );

    await DatabaseHelper.instance.create(note);
    _notes.insert(0, note);
    _invalidateCache();
    notifyListeners();
    return note;
  }

  /// Create note from template
  Future<Note> createNoteFromTemplate(String templateName) async {
    final template = NoteTemplate.getTemplate(templateName);
    if (template == null) {
      return createNote();
    }

    return createNote(
      title: '${template.name} Note',
      content: template.content,
      templateType: templateName,
    );
  }

  /// Update note with optimized notification
  Future<void> updateNote(Note note) async {
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    await DatabaseHelper.instance.update(updatedNote);

    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      final oldNote = _notes[index];
      _notes[index] = updatedNote;

      // Only sort if pinned/favorite status changed
      if (oldNote.isPinned != updatedNote.isPinned ||
          oldNote.isFavorite != updatedNote.isFavorite) {
        _sortNotes();
      }

      // Only invalidate cache if category or tags changed
      if (oldNote.category != updatedNote.category ||
          !_listEquals(oldNote.tags, updatedNote.tags)) {
        _invalidateCache();
      }

      notifyListeners();
    }
  }

  /// Delete note
  Future<void> deleteNote(String id) async {
    await DatabaseHelper.instance.delete(id);
    _notes.removeWhere((note) => note.id == id);
    _filteredNotes.removeWhere((note) => note.id == id);
    _invalidateCache();
    notifyListeners();
  }

  // ============================================================================
  // NOTE ACTIONS (OPTIMIZED)
  // ============================================================================

  /// Toggle pin status
  Future<void> togglePinNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      final updatedNote = note.copyWith(
        isPinned: !note.isPinned,
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      _sortNotes();
      notifyListeners();
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      final updatedNote = note.copyWith(
        isFavorite: !note.isFavorite,
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      _sortNotes();
      notifyListeners();
    }
  }

  /// Toggle archive status
  Future<void> toggleArchive(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      final updatedNote = note.copyWith(
        isArchived: !note.isArchived,
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      notifyListeners();
    }
  }

  // ============================================================================
  // CATEGORY MANAGEMENT
  // ============================================================================

  /// Set note category
  Future<void> setNoteCategory(String id, String? category) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      final updatedNote = note.copyWith(
        category: category,
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      _invalidateCache();
      notifyListeners();
    }
  }

  /// Get all categories with caching
  Future<List<String>> getAllCategories() async {
    if (_allCategoriesCache.isEmpty || _shouldUpdateCache()) {
      _allCategoriesCache = await DatabaseHelper.instance.getAllCategories();
      _lastCacheUpdate = DateTime.now();
    }
    return _allCategoriesCache;
  }

  /// Get notes count by category
  Future<Map<String, int>> getNotesCountByCategory() async {
    if (_categoryCountsCache.isEmpty || _shouldUpdateCache()) {
      _categoryCountsCache = await DatabaseHelper.instance
          .getNotesCountByCategory();
      _lastCacheUpdate = DateTime.now();
    }
    return _categoryCountsCache;
  }

  // ============================================================================
  // TAG MANAGEMENT
  // ============================================================================

  /// Add tag to note
  Future<void> addTagToNote(String noteId, String tag) async {
    if (tag.trim().isEmpty) return;

    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      final tags = List<String>.from(note.tags);

      final trimmedTag = tag.trim();
      if (!tags.contains(trimmedTag)) {
        tags.add(trimmedTag);
        final updatedNote = note.copyWith(
          tags: tags,
          updatedAt: DateTime.now(),
        );
        await DatabaseHelper.instance.update(updatedNote);
        _notes[index] = updatedNote;
        _invalidateCache();
        notifyListeners();
      }
    }
  }

  /// Remove tag from note
  Future<void> removeTagFromNote(String noteId, String tag) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      final tags = List<String>.from(note.tags)..remove(tag);
      final updatedNote = note.copyWith(tags: tags, updatedAt: DateTime.now());
      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      _invalidateCache();
      notifyListeners();
    }
  }

  /// Update note tags
  Future<void> updateNoteTags(String noteId, List<String> tags) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      final updatedNote = note.copyWith(tags: tags, updatedAt: DateTime.now());
      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      _invalidateCache();
      notifyListeners();
    }
  }

  /// Get all tags with caching
  Future<List<String>> getAllTags() async {
    if (_allTagsCache.isEmpty || _shouldUpdateCache()) {
      _allTagsCache = await DatabaseHelper.instance.getAllTags();
      _lastCacheUpdate = DateTime.now();
    }
    return _allTagsCache;
  }

  // ============================================================================
  // SEARCH (OPTIMIZED WITH DEBOUNCING)
  // ============================================================================

  /// Search notes with debouncing
  void searchNotes(String query) {
    // Cancel previous timer
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    // If query is empty, clear immediately without debouncing
    if (query.isEmpty) {
      _performSearch(query);
      return;
    }

    // Debounce for non-empty queries
    _searchDebounce = Timer(SEARCH_DEBOUNCE_DURATION, () {
      _performSearch(query);
    });
  }

  /// Perform actual search
  void _performSearch(String query) {
    _searchQuery = query;

    if (query.isEmpty) {
      _filteredNotes = [];
    } else {
      final lowerQuery = query.toLowerCase();

      // Optimized search with early exit
      _filteredNotes = _notes.where((note) {
        if (note.title.toLowerCase().contains(lowerQuery)) return true;
        if (note.content.toLowerCase().contains(lowerQuery)) return true;
        if (note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))) {
          return true;
        }
        if (note.category?.toLowerCase().contains(lowerQuery) ?? false) {
          return true;
        }
        return false;
      }).toList();
    }

    notifyListeners();
  }

  /// Clear search immediately
  void clearSearch() {
    _searchDebounce?.cancel();
    _searchQuery = '';
    _filteredNotes = [];
    notifyListeners();
  }

  // ============================================================================
  // FILTERS
  // ============================================================================

  void toggleShowArchived() {
    _showArchived = !_showArchived;
    notifyListeners();
  }

  void toggleShowFavoritesOnly() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleTagFilter(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    notifyListeners();
  }

  void clearTagFilters() {
    _selectedTags.clear();
    notifyListeners();
  }

  void clearAllFilters() {
    _showArchived = false;
    _showFavoritesOnly = false;
    _selectedCategory = null;
    _selectedTags.clear();
    notifyListeners();
  }

  // ============================================================================
  // QUERY METHODS
  // ============================================================================

  /// Get note by ID
  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get notes by category
  List<Note> getNotesByCategory(String category) {
    return _notes
        .where((note) => note.category == category && !note.isArchived)
        .toList();
  }

  /// Get notes by tag
  List<Note> getNotesByTag(String tag) {
    return _notes
        .where((note) => note.tags.contains(tag) && !note.isArchived)
        .toList();
  }

  /// Get favorite notes
  List<Note> getFavoriteNotes() {
    return _notes.where((note) => note.isFavorite && !note.isArchived).toList();
  }

  /// Get archived notes
  List<Note> getArchivedNotes() {
    return _notes.where((note) => note.isArchived).toList();
  }

  /// Get pinned notes
  List<Note> getPinnedNotes() {
    return _notes.where((note) => note.isPinned && !note.isArchived).toList();
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get statistics
  Future<Map<String, int>> getStatistics() async {
    return await DatabaseHelper.instance.getStatistics();
  }

  // ============================================================================
  // IMPORT/EXPORT
  // ============================================================================

  /// Import notes from file
  Future<bool> importNotes() async {
    try {
      final importService = ImportService();
      List<Note>? importedNotes = await importService.importNotesFromFile();

      if (importedNotes != null && importedNotes.isNotEmpty) {
        for (final note in importedNotes) {
          await DatabaseHelper.instance.create(note);
        }

        _notes.addAll(importedNotes);
        _sortNotes();
        _invalidateCache();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // BULK OPERATIONS
  // ============================================================================

  /// Delete multiple notes
  Future<void> deleteMultipleNotes(List<String> ids) async {
    for (final id in ids) {
      await DatabaseHelper.instance.delete(id);
    }
    _notes.removeWhere((note) => ids.contains(note.id));
    _filteredNotes.removeWhere((note) => ids.contains(note.id));
    _invalidateCache();
    notifyListeners();
  }

  /// Archive multiple notes
  Future<void> archiveMultipleNotes(List<String> ids) async {
    for (final id in ids) {
      final index = _notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        final note = _notes[index];
        final updatedNote = note.copyWith(
          isArchived: true,
          updatedAt: DateTime.now(),
        );
        await DatabaseHelper.instance.update(updatedNote);
        _notes[index] = updatedNote;
      }
    }
    notifyListeners();
  }

  /// Add tag to multiple notes
  Future<void> addTagToMultipleNotes(List<String> noteIds, String tag) async {
    if (tag.trim().isEmpty) return;

    for (final noteId in noteIds) {
      await addTagToNote(noteId, tag);
    }
  }

  // ============================================================================
  // SORTING
  // ============================================================================

  void _sortNotes() {
    _notes.sort((a, b) {
      // Pinned notes first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // Then favorites
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;

      // Then by updated date
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ============================================================================
  // REMINDER MANAGEMENT
  // ============================================================================

  /// Set reminder for a note
  Future<void> setNoteReminder(
    String noteId,
    DateTime reminderDateTime,
  ) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];

      // Generate unique notification ID
      final notificationId = await DatabaseHelper.instance
          .getNextNotificationId();

      // Schedule notification (always use 'once' since repeat is removed)
      final reminderService = ReminderService.instance;
      await reminderService.initialize();
      await reminderService.scheduleReminder(
        note.copyWith(
          reminderDateTime: reminderDateTime,
          reminderRepeatType: 'once',
        ),
        notificationId,
      );

      // Update note with reminder data
      final updatedNote = note.copyWith(
        reminderDateTime: reminderDateTime,
        hasReminder: true,
        notificationId: notificationId,
        reminderRepeatType: 'once',
        updatedAt: DateTime.now(),
      );

      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      notifyListeners();
    }
  }

  /// Clear reminder from a note
  Future<void> clearNoteReminder(String noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];

      // Cancel notification if exists
      if (note.notificationId != null) {
        final reminderService = ReminderService.instance;
        await reminderService.initialize();
        await reminderService.cancelReminder(note.notificationId!);
      }

      // Update note to remove reminder
      final updatedNote = note.copyWith(
        reminderDateTime: null,
        hasReminder: false,
        notificationId: null,
        updatedAt: DateTime.now(),
      );

      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      notifyListeners();
    }
  }

  /// Update existing reminder
  Future<void> updateNoteReminder(
    String noteId,
    DateTime newReminderDateTime,
  ) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];

      // Reschedule notification
      final reminderService = ReminderService.instance;
      await reminderService.initialize();

      // Cancel old notification if exists
      if (note.notificationId != null) {
        await reminderService.cancelReminder(note.notificationId!);
      }

      // Generate new notification ID (or reuse existing if available)
      final notificationId =
          note.notificationId ??
          await DatabaseHelper.instance.getNextNotificationId();

      // Schedule with the notification ID
      await reminderService.scheduleReminder(
        note.copyWith(reminderDateTime: newReminderDateTime),
        notificationId,
      );

      // Update note
      final updatedNote = note.copyWith(
        reminderDateTime: newReminderDateTime,
        hasReminder: true,
        notificationId: notificationId,
        updatedAt: DateTime.now(),
      );

      await DatabaseHelper.instance.update(updatedNote);
      _notes[index] = updatedNote;
      notifyListeners();
    }
  }

  /// Get notes with active reminders
  Future<List<Note>> getNotesWithReminders() async {
    return await DatabaseHelper.instance.getAllNotesWithReminders();
  }

  /// Clear triggered "once" reminder from a note
  /// This is called automatically when a "once" reminder fires
  /// Unlike clearNoteReminder, this doesn't cancel the notification (already fired)
  Future<void> clearTriggeredOnceReminder(String noteId) async {

    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];

      // Only clear if it's a "once" reminder
      if (note.reminderRepeatType == 'once') {
        // Update note to remove reminder (don't cancel notification - already fired)
        final updatedNote = note.copyWith(
          reminderDateTime: null,
          hasReminder: false,
          notificationId: null,
          reminderRepeatType: null,
          updatedAt: DateTime.now(),
        );

        await DatabaseHelper.instance.update(updatedNote);
        _notes[index] = updatedNote;
        notifyListeners();
      } else {
        //
      }
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    await loadNotes(refresh: true);
  }

  // ============================================================================
  // DISPOSE
  // ============================================================================

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
