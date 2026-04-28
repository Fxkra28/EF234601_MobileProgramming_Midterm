import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final int? id;
  final String? remoteId;
  final String userId;
  final int categoryId;
  final String title;
  final String description;
  final DateTime date;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isCompleted;
  final String? localImagePath;
  final String? remoteImageUrl;
  final String? imageStoragePath;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final bool reminderEnabled;
  final int? notificationId;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    this.id,
    this.remoteId,
    required this.userId,
    required this.categoryId,
    required this.title,
    this.description = '',
    required this.date,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.localImagePath,
    this.remoteImageUrl,
    this.imageStoragePath,
    this.latitude,
    this.longitude,
    this.locationName,
    this.reminderEnabled = false,
    this.notificationId,
    this.syncStatus = 'pending',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'remoteId': remoteId,
      'userId': userId,
      'categoryId': categoryId,
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'startTime': startTime?.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
      'localImagePath': localImagePath,
      'remoteImageUrl': remoteImageUrl,
      'imageStoragePath': imageStoragePath,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'notificationId': notificationId,
      'syncStatus': syncStatus,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Task.fromMap(Map<String, Object?> m) {
    return Task(
      id: m['id'] as int?,
      remoteId: m['remoteId'] as String?,
      userId: m['userId'] as String,
      categoryId: m['categoryId'] as int,
      title: m['title'] as String,
      description: (m['description'] as String?) ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
      startTime: m['startTime'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['startTime'] as int),
      endTime: m['endTime'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['endTime'] as int),
      isCompleted: (m['isCompleted'] as int? ?? 0) == 1,
      localImagePath: m['localImagePath'] as String?,
      remoteImageUrl: m['remoteImageUrl'] as String?,
      imageStoragePath: m['imageStoragePath'] as String?,
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      locationName: m['locationName'] as String?,
      reminderEnabled: (m['reminderEnabled'] as int? ?? 0) == 1,
      notificationId: m['notificationId'] as int?,
      syncStatus: (m['syncStatus'] as String?) ?? 'pending',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> toFirestore({required String? categoryRemoteId}) {
    return {
      'categoryRemoteId': categoryRemoteId,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'startTime': startTime == null ? null : Timestamp.fromDate(startTime!),
      'endTime': endTime == null ? null : Timestamp.fromDate(endTime!),
      'isCompleted': isCompleted,
      'remoteImageUrl': remoteImageUrl,
      'imageStoragePath': imageStoragePath,
      'location': (latitude == null || longitude == null)
          ? null
          : {
              'latitude': latitude,
              'longitude': longitude,
              'name': locationName,
            },
      'reminderEnabled': reminderEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Task.fromFirestore(
    DocumentSnapshot doc, {
    required String userId,
    required int localCategoryId,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final loc = data['location'] as Map<String, dynamic>?;
    return Task(
      id: null,
      remoteId: doc.id,
      userId: userId,
      categoryId: localCategoryId,
      title: data['title'] as String,
      description: (data['description'] as String?) ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      isCompleted: (data['isCompleted'] as bool?) ?? false,
      remoteImageUrl: data['remoteImageUrl'] as String?,
      imageStoragePath: data['imageStoragePath'] as String?,
      latitude: (loc?['latitude'] as num?)?.toDouble(),
      longitude: (loc?['longitude'] as num?)?.toDouble(),
      locationName: loc?['name'] as String?,
      reminderEnabled: (data['reminderEnabled'] as bool?) ?? false,
      syncStatus: 'synced',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Task copyWith({
    int? id,
    String? remoteId,
    String? userId,
    int? categoryId,
    String? title,
    String? description,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    bool? isCompleted,
    String? localImagePath,
    String? remoteImageUrl,
    String? imageStoragePath,
    double? latitude,
    double? longitude,
    String? locationName,
    bool? reminderEnabled,
    int? notificationId,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearStartTime = false,
    bool clearEndTime = false,
    bool clearLocalImage = false,
    bool clearRemoteImage = false,
    bool clearLocation = false,
  }) {
    return Task(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      isCompleted: isCompleted ?? this.isCompleted,
      localImagePath:
          clearLocalImage ? null : (localImagePath ?? this.localImagePath),
      remoteImageUrl:
          clearRemoteImage ? null : (remoteImageUrl ?? this.remoteImageUrl),
      imageStoragePath:
          clearRemoteImage ? null : (imageStoragePath ?? this.imageStoragePath),
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      locationName:
          clearLocation ? null : (locationName ?? this.locationName),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      notificationId: notificationId ?? this.notificationId,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
