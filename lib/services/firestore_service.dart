import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_model.dart';
import '../models/task_model.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasksCol(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  CollectionReference<Map<String, dynamic>> _categoriesCol(String uid) =>
      _db.collection('users').doc(uid).collection('categories');

  // ─── Profile doc ──────────────────────────────────────────────

  Future<void> ensureProfile({
    required String uid,
    required String email,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();
    if (!snap.exists) {
      await ref.set({
        'email': email,
        'createdAt': now,
        'lastSeenAt': now,
      });
    } else {
      await ref.update({'lastSeenAt': now});
    }
  }

  // ─── Categories ───────────────────────────────────────────────

  Future<String> upsertCategory(String uid, Category c) async {
    final col = _categoriesCol(uid);
    final data = c.toFirestore();
    if (c.remoteId == null || c.remoteId!.isEmpty) {
      final ref = await col.add(data);
      return ref.id;
    } else {
      await col.doc(c.remoteId).set(data, SetOptions(merge: true));
      return c.remoteId!;
    }
  }

  Future<void> deleteCategory(String uid, String remoteId) async {
    await _categoriesCol(uid).doc(remoteId).delete();
  }

  Future<List<Category>> fetchCategories(String uid) async {
    final snap = await _categoriesCol(uid).get();
    return snap.docs
        .map((d) => Category.fromFirestore(d, userId: uid))
        .toList();
  }

  // ─── Tasks ────────────────────────────────────────────────────

  Future<String> upsertTask(
    String uid,
    Task t, {
    required String? categoryRemoteId,
  }) async {
    final col = _tasksCol(uid);
    final data = t.toFirestore(categoryRemoteId: categoryRemoteId);
    if (t.remoteId == null || t.remoteId!.isEmpty) {
      final ref = await col.add(data);
      return ref.id;
    } else {
      await col.doc(t.remoteId).set(data, SetOptions(merge: true));
      return t.remoteId!;
    }
  }

  Future<void> deleteTask(String uid, String remoteId) async {
    await _tasksCol(uid).doc(remoteId).delete();
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> fetchTaskDocs(
      String uid) async {
    final snap = await _tasksCol(uid).get();
    return snap.docs;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTasks(String uid) {
    return _tasksCol(uid).orderBy('date').snapshots();
  }

  // ─── Lifecycle ────────────────────────────────────────────────

  Future<void> wipeUser(String uid) async {
    final tasks = await _tasksCol(uid).get();
    for (final d in tasks.docs) {
      await d.reference.delete();
    }
    final cats = await _categoriesCol(uid).get();
    for (final d in cats.docs) {
      await d.reference.delete();
    }
    await _db.collection('users').doc(uid).delete();
  }
}
