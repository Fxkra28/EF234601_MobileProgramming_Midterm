import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final int? id;
  final String? remoteId;
  final String userId;
  final String name;
  final int colorHex;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    this.id,
    this.remoteId,
    required this.userId,
    required this.name,
    required this.colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'remoteId': remoteId,
      'userId': userId,
      'name': name,
      'colorHex': colorHex,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Category.fromMap(Map<String, Object?> m) {
    return Category(
      id: m['id'] as int?,
      remoteId: m['remoteId'] as String?,
      userId: m['userId'] as String,
      name: m['name'] as String,
      colorHex: m['colorHex'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'colorHex': colorHex,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Category.fromFirestore(DocumentSnapshot doc, {required String userId}) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: null,
      remoteId: doc.id,
      userId: userId,
      name: data['name'] as String,
      colorHex: data['colorHex'] as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Category copyWith({
    int? id,
    String? remoteId,
    String? userId,
    String? name,
    int? colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
