import 'package:flutter/foundation.dart' hide Category;

import '../models/category_model.dart';
import '../services/firestore_service.dart';
import '../services/sql_service.dart';

class CategoryController extends ChangeNotifier {
  final SqlService _sql = SqlService.instance;
  final FirestoreService _cloud = FirestoreService.instance;

  String? _userId;
  List<Category> _categories = [];
  String? _errorMessage;

  List<Category> get categories => List.unmodifiable(_categories);
  String? get errorMessage => _errorMessage;
  bool get hasUser => _userId != null && _userId!.isNotEmpty;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> bindUser(String? uid) async {
    if (uid == null || uid.isEmpty) {
      _userId = null;
      _categories = [];
      notifyListeners();
      return;
    }
    if (_userId == uid && _categories.isNotEmpty) return;
    _userId = uid;
    await _hydrate();
  }

  Future<void> _hydrate() async {
    final uid = _userId;
    if (uid == null) return;

    var local = await _sql.categoriesForUser(uid);
    if (local.isEmpty) {
      try {
        final remote = await _cloud.fetchCategories(uid);
        if (remote.isEmpty) {
          await _sql.seedCategoriesIfEmpty(uid);
        } else {
          for (final c in remote) {
            await _sql.insertCategory(c);
          }
        }
      } catch (_) {
        await _sql.seedCategoriesIfEmpty(uid);
      }
      local = await _sql.categoriesForUser(uid);
    }
    _categories = local;
    notifyListeners();
  }

  Future<void> reload() => _hydrate();

  Category? byId(int id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> addCategory(String name, int colorHex) async {
    final uid = _userId;
    if (uid == null) return;
    final draft = Category(userId: uid, name: name, colorHex: colorHex);
    final localId = await _sql.insertCategory(draft);
    final inserted = draft.copyWith(id: localId);
    try {
      final remoteId = await _cloud.upsertCategory(uid, inserted);
      final synced = inserted.copyWith(remoteId: remoteId);
      await _sql.updateCategory(synced);
    } catch (e) {
      _errorMessage = 'Saved locally — will sync when online.';
    }
    await _hydrate();
  }

  Future<void> updateCategory(Category c, {String? name, int? colorHex}) async {
    final uid = _userId;
    if (uid == null) return;
    final updated = c.copyWith(
      name: name ?? c.name,
      colorHex: colorHex ?? c.colorHex,
    );
    await _sql.updateCategory(updated);
    try {
      final remoteId = await _cloud.upsertCategory(uid, updated);
      if (updated.remoteId == null) {
        await _sql.updateCategory(updated.copyWith(remoteId: remoteId));
      }
    } catch (_) {
      _errorMessage = 'Saved locally — will sync when online.';
    }
    await _hydrate();
  }

  Future<bool> deleteCategory(Category c) async {
    final uid = _userId;
    if (uid == null || c.id == null) return false;
    try {
      await _sql.deleteCategory(c.id!);
    } on StateError catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
    if (c.remoteId != null) {
      try {
        await _cloud.deleteCategory(uid, c.remoteId!);
      } catch (_) {}
    }
    await _hydrate();
    return true;
  }
}
