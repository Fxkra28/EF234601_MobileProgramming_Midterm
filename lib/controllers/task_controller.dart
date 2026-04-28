import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../services/image_service.dart';
import '../services/notification_service.dart';
import '../services/sql_service.dart';
import 'category_controller.dart';

class TaskController extends ChangeNotifier {
  final SqlService _sql = SqlService.instance;
  final FirestoreService _cloud = FirestoreService.instance;
  final NotificationService _notif = NotificationService.instance;
  final ImageService _img = ImageService.instance;

  String? _userId;
  CategoryController? _categories;

  List<Task> _tasks = [];
  Set<DateTime> _datesWithTasks = {};
  DateTime _selectedDate = _today();
  String? _errorMessage;

  /// Periodic tick that nudges all listeners to re-render so overdue/soon
  /// badges on task cards transition correctly as wallclock time passes,
  /// without requiring a manual save or scroll.
  Timer? _ticker;
  bool _disposed = false;

  TaskController() {
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_disposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  List<Task> get tasks => List.unmodifiable(_tasks);
  Set<DateTime> get datesWithTasks => _datesWithTasks;
  DateTime get selectedDate => _selectedDate;
  String? get errorMessage => _errorMessage;
  String? get userId => _userId;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void attachCategoryController(CategoryController c) {
    _categories = c;
  }

  Future<void> bindUser(String? uid) async {
    if (uid == null || uid.isEmpty) {
      _userId = null;
      _tasks = [];
      _datesWithTasks = {};
      notifyListeners();
      return;
    }
    if (_userId == uid && _tasks.isNotEmpty) return;
    _userId = uid;
    await hydrateFromCloud();
    await loadForDate(_selectedDate);
    await _datesWithTasksFromSql();
    await rescheduleAllReminders();
  }

  Future<void> setSelectedDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    await loadForDate(_selectedDate);
  }

  Future<void> _datesWithTasksFromSql() async {
    if (_userId == null) return;
    _datesWithTasks = await _sql.datesWithTasks(_userId!);
    notifyListeners();
  }

  Future<void> loadForDate(DateTime date) async {
    if (_userId == null) {
      _tasks = [];
      notifyListeners();
      return;
    }
    final rows = await _sql.tasksByDate(_userId!, date);
    _tasks = rows.map(Task.fromMap).toList();
    notifyListeners();
  }

  Future<void> hydrateFromCloud() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      if (_categories != null) {
        await _categories!.bindUser(uid);
      }

      final localTasks = await _sql.allTasksForUser(uid);
      if (localTasks.isEmpty) {
        final docs = await _cloud.fetchTaskDocs(uid);
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final categoryRemoteId = data['categoryRemoteId'] as String?;
          int? localCategoryId;
          if (categoryRemoteId != null) {
            final cat = await _sql.categoryByRemoteId(categoryRemoteId);
            localCategoryId = cat?.id;
          }
          if (localCategoryId == null) {
            final cats = await _sql.categoriesForUser(uid);
            if (cats.isNotEmpty) localCategoryId = cats.first.id;
          }
          if (localCategoryId == null) continue;
          final t = Task.fromFirestore(d,
              userId: uid, localCategoryId: localCategoryId);
          await _sql.insertTask(t);
        }
      }
      await _datesWithTasksFromSql();
    } catch (e) {
      _errorMessage = 'Could not sync from cloud: $e';
      notifyListeners();
    }
  }

  Future<Task?> addTask({
    required int categoryId,
    required String title,
    required String description,
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    String? localImagePath,
    double? latitude,
    double? longitude,
    String? locationName,
    bool reminderEnabled = false,
  }) async {
    final uid = _userId;
    if (uid == null) return null;

    var draft = Task(
      userId: uid,
      categoryId: categoryId,
      title: title,
      description: description,
      date: DateTime(date.year, date.month, date.day),
      startTime: startTime,
      endTime: endTime,
      localImagePath: localImagePath,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      reminderEnabled: reminderEnabled,
    );

    final localId = await _sql.insertTask(draft);
    var saved = draft.copyWith(id: localId, notificationId: localId);
    await _sql.updateTask(saved);

    final categoryRemoteId = _categories?.byId(categoryId)?.remoteId;
    try {
      final remoteId = await _cloud.upsertTask(uid, saved,
          categoryRemoteId: categoryRemoteId);
      saved = saved.copyWith(remoteId: remoteId, syncStatus: 'synced');
      await _sql.updateTask(saved);
    } catch (e) {
      _errorMessage = 'Saved locally — will sync when online.';
    }

    if (saved.reminderEnabled) {
      try {
        await _notif.scheduleTaskReminder(saved);
      } catch (e, st) {
        debugPrint('[task] schedule reminder failed (add): $e\n$st');
      }
    }

    await loadForDate(_selectedDate);
    await _datesWithTasksFromSql();
    return saved;
  }

  Future<void> updateTask(
    Task original, {
    required int categoryId,
    required String title,
    required String description,
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    String? newLocalImagePath,
    bool clearImage = false,
    double? latitude,
    double? longitude,
    String? locationName,
    bool clearLocation = false,
    required bool reminderEnabled,
  }) async {
    final uid = _userId;
    if (uid == null || original.id == null) return;

    var updated = original.copyWith(
      categoryId: categoryId,
      title: title,
      description: description,
      date: DateTime(date.year, date.month, date.day),
      startTime: startTime,
      endTime: endTime,
      clearStartTime: startTime == null,
      clearEndTime: endTime == null,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      clearLocation: clearLocation,
      reminderEnabled: reminderEnabled,
      localImagePath: newLocalImagePath ?? original.localImagePath,
      clearLocalImage: clearImage,
      clearRemoteImage: clearImage,
    );
    await _sql.updateTask(updated);

    final categoryRemoteId = _categories?.byId(categoryId)?.remoteId;

    if (clearImage) {
      await _img.deleteLocalIfExists(original.localImagePath);
    }

    try {
      final remoteId = await _cloud.upsertTask(uid, updated,
          categoryRemoteId: categoryRemoteId);
      updated = updated.copyWith(remoteId: remoteId, syncStatus: 'synced');
      await _sql.updateTask(updated);
    } catch (e) {
      _errorMessage = 'Saved locally — will sync when online.';
    }

    if (original.id != null) {
      await _notif.cancelTaskReminder(original.id!);
    }
    if (updated.reminderEnabled && updated.startTime != null) {
      try {
        await _notif.scheduleTaskReminder(updated);
      } catch (e, st) {
        debugPrint('[task] schedule reminder failed (update): $e\n$st');
      }
    }

    await loadForDate(_selectedDate);
    await _datesWithTasksFromSql();
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final uid = _userId;
    if (uid == null || task.id == null) return;
    final flipped = task.copyWith(isCompleted: !task.isCompleted);
    await _sql.updateTask(flipped);
    final categoryRemoteId = _categories?.byId(task.categoryId)?.remoteId;
    try {
      await _cloud.upsertTask(uid, flipped, categoryRemoteId: categoryRemoteId);
    } catch (_) {}
    await loadForDate(_selectedDate);
  }

  Future<void> deleteTask(Task task) async {
    final uid = _userId;
    if (uid == null || task.id == null) return;
    await _sql.deleteTask(task.id!);
    if (task.remoteId != null) {
      try {
        await _cloud.deleteTask(uid, task.remoteId!);
      } catch (_) {}
    }
    await _img.deleteLocalIfExists(task.localImagePath);
    await _notif.cancelTaskReminder(task.id!);
    await loadForDate(_selectedDate);
    await _datesWithTasksFromSql();
  }

  Future<Task?> findById(int id) => _sql.taskById(id);

  Future<void> rescheduleAllReminders() async {
    final uid = _userId;
    if (uid == null) return;
    await _notif.cancelAll();
    final reminders = await _sql.tasksWithReminders(uid);
    debugPrint(
        '[task] rescheduleAllReminders found ${reminders.length} task(s) with reminders for uid=$uid');
    for (final t in reminders) {
      try {
        await _notif.scheduleTaskReminder(t);
      } catch (e, st) {
        debugPrint('[task] reschedule reminder failed for task=${t.id}: $e\n$st');
      }
    }
  }

  Future<void> wipeForLogout() async {
    final uid = _userId;
    if (uid == null) return;
    await _notif.cancelAll();
    await _sql.wipeUser(uid);
    _tasks = [];
    _datesWithTasks = {};
    notifyListeners();
  }
}
