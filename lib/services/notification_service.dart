import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';

/// Hybrid notification service.
///
/// Fires reminders TWO ways at once so they're visible regardless of app
/// state:
///   1. **System tray notification** via `flutter_local_notifications` —
///      survives the app being closed (OS-scheduled).
///   2. **In-app pop-up overlay** via a `Timer` + `OverlayEntry` — slides
///      down from the top of the screen when the app is foregrounded.
///
/// The two redundantly cover each other so that the user always sees the
/// reminder, regardless of foreground/background and regardless of OS-level
/// permission quirks.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const String _channelId = 'task_reminders';
  static const String _channelName = 'Task Reminders';
  static const String _channelDesc = 'Reminds you about scheduled tasks';

  /// Pre-warning notification id offset (so it never collides with the
  /// at-time id).
  static const int _preWarningOffset = 1000000;
  static const Duration _preWarningWindow = Duration(minutes: 5);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Map<int, Timer> _timers = {};
  final StreamController<int> _tapController =
      StreamController<int>.broadcast();

  GlobalKey<NavigatorState>? _navKey;
  bool _initialized = false;

  /// Emits the task id (sqflite PK) whenever a system notification or in-app
  /// banner is tapped.
  Stream<int> get taskTaps => _tapController.stream;

  void attachNavigatorKey(GlobalKey<NavigatorState> key) {
    _navKey = key;
  }

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
      debugPrint('[notif] timezone resolved to $localTz');
    } catch (e) {
      debugPrint(
          '[notif] timezone init failed: $e — system notifications will use UTC');
    }

    // iOS permission is requested lazily before the first scheduled fire,
    // not at boot — boot-time prompts can stall the splash screen.
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onTap,
      );
    } catch (e) {
      debugPrint('[notif] plugin.initialize failed: $e');
    }

    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.requestNotificationsPermission();
        await androidImpl.requestExactAlarmsPermission();
        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        );
        await androidImpl.createNotificationChannel(channel);
      }
    } catch (e) {
      debugPrint('[notif] android channel setup failed: $e');
    }

    _initialized = true;
  }

  void _onTap(NotificationResponse r) {
    final payload = r.payload;
    if (payload == null || !payload.startsWith('task:')) return;
    final id = int.tryParse(payload.substring(5));
    if (id != null) _tapController.add(id);
  }

  Future<bool> _ensureIosPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios == null) return true;
    try {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted == false) {
        debugPrint(
            '[notif] iOS notification permission DENIED — system tray '
            'notifications will be silent. In-app overlay will still work.');
      }
      return granted ?? false;
    } catch (e) {
      debugPrint('[notif] iOS permission request threw: $e');
      return false;
    }
  }

  NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    // presentAlert/Badge/Sound = true ensures the iOS banner shows even
    // when the app is foregrounded.
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.startTime == null || task.id == null) {
      debugPrint(
          '[notif] skip schedule: task.id=${task.id} startTime=${task.startTime}');
      return;
    }

    await _ensureIosPermission();

    final now = DateTime.now();
    final when = task.startTime!;
    final atTimeId = task.id!;
    final preWarningId = atTimeId + _preWarningOffset;
    final preWarningWhen = when.subtract(_preWarningWindow);

    debugPrint(
        '[notif] schedule task=${task.id} title="${task.title}" when=$when now=$now');

    // Always cancel any prior schedule for this task before re-scheduling.
    await cancelTaskReminder(atTimeId);

    final atTimeBody =
        task.description.isEmpty ? "It's time." : task.description;
    final preWarningBody =
        'Starts in ${_preWarningWindow.inMinutes} minutes.';

    // ── System notification (works even when app is closed) ──────────
    final details = _details();

    if (when.isAfter(now.add(const Duration(seconds: 5)))) {
      try {
        await _plugin.zonedSchedule(
          atTimeId,
          'Reminder: ${task.title}',
          atTimeBody,
          tz.TZDateTime.from(when, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task:${task.id}',
        );
        debugPrint('[notif] system at-time scheduled at $when (id=$atTimeId)');
      } catch (e) {
        debugPrint('[notif] system at-time schedule failed: $e');
      }
    }

    if (preWarningWhen.isAfter(now.add(const Duration(seconds: 5)))) {
      try {
        await _plugin.zonedSchedule(
          preWarningId,
          'Heads up: ${task.title}',
          preWarningBody,
          tz.TZDateTime.from(preWarningWhen, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task:${task.id}',
        );
        debugPrint(
            '[notif] system pre-warning scheduled at $preWarningWhen (id=$preWarningId)');
      } catch (e) {
        debugPrint('[notif] system pre-warning schedule failed: $e');
      }
    }

    // ── In-app overlay timer (works only when app is open) ──────────
    final atTimeDelay = when.difference(now);
    final preWarningDelay = atTimeDelay - _preWarningWindow;

    if (preWarningDelay > Duration.zero) {
      _timers[preWarningId] = Timer(preWarningDelay, () {
        debugPrint('[notif] firing pre-warning popup for task $atTimeId');
        _showOverlay(
          taskId: atTimeId,
          title: 'Heads up: ${task.title}',
          body: preWarningBody,
        );
      });
      debugPrint(
          '[notif] in-app pre-warning timer set for $preWarningDelay (atTimeId=$atTimeId)');
    } else {
      debugPrint('[notif] pre-warning skipped (in past): delay=$preWarningDelay');
    }
    if (atTimeDelay > Duration.zero) {
      _timers[atTimeId] = Timer(atTimeDelay, () {
        debugPrint('[notif] firing at-time popup for task $atTimeId');
        _showOverlay(
          taskId: atTimeId,
          title: 'Reminder: ${task.title}',
          body: atTimeBody,
        );
      });
      debugPrint(
          '[notif] in-app at-time timer set for $atTimeDelay (atTimeId=$atTimeId)');
    } else {
      debugPrint('[notif] at-time skipped (in past): delay=$atTimeDelay');
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    _timers.remove(taskId)?.cancel();
    _timers.remove(taskId + _preWarningOffset)?.cancel();
    try {
      await _plugin.cancel(taskId);
      await _plugin.cancel(taskId + _preWarningOffset);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> showTestReminder({
    Duration delay = const Duration(seconds: 10),
  }) async {
    await _ensureIosPermission();
    final fireAt = DateTime.now().add(delay);
    final id = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;

    try {
      await _plugin.zonedSchedule(
        id,
        'Test reminder',
        'This is a test notification scheduled ${delay.inSeconds}s ago.',
        tz.TZDateTime.from(fireAt, tz.local),
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}

    _timers[id] = Timer(delay, () {
      _showOverlay(
        taskId: 0,
        title: 'Test reminder',
        body: 'In-app pop-up — tap × to dismiss.',
      );
    });
  }

  void _showOverlay({
    required int taskId,
    required String title,
    required String body,
  }) {
    // The Navigator owns its Overlay (it's a child, not an ancestor),
    // so we grab it via NavigatorState.overlay instead of Overlay.of.
    final overlay = _navKey?.currentState?.overlay;
    if (overlay == null) {
      debugPrint(
          '[notif] overlay unavailable when firing for task=$taskId — '
          'navigator state currentState=${_navKey?.currentState}');
      return;
    }

    OverlayEntry? entry;
    void close() {
      try {
        entry?.remove();
      } catch (_) {}
      entry = null;
    }

    entry = OverlayEntry(
      builder: (_) => _ReminderBanner(
        title: title,
        body: body,
        onTap: taskId == 0
            ? null
            : () {
                close();
                _tapController.add(taskId);
              },
        onDismiss: close,
      ),
    );
    overlay.insert(entry!);
    Timer(const Duration(seconds: 6), close);
  }
}

class _ReminderBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _ReminderBanner({
    required this.title,
    required this.body,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<_ReminderBanner> createState() => _ReminderBannerState();
}

class _ReminderBannerState extends State<_ReminderBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Positioned(
      top: padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4A90E2), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1F2A44),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: widget.onDismiss,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close,
                          size: 18, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
