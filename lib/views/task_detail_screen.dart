import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../controllers/category_controller.dart';
import '../controllers/task_controller.dart';
import '../models/category_model.dart';
import '../models/task_model.dart';
import 'task_form_sheet.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _refresh() async {
    if (_task.id == null) return;
    final fresh = await context.read<TaskController>().findById(_task.id!);
    if (!mounted) return;
    if (fresh == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _task = fresh);
    }
  }

  Future<void> _edit() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskFormSheet(task: _task),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${_task.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<TaskController>().deleteTask(_task);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _toggleComplete() async {
    final ctrl = context.read<TaskController>();
    await ctrl.toggleTaskCompletion(_task);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<CategoryController>();
    final cat = cats.byId(_task.categoryId);
    final categoryColor =
        cat == null ? const Color(0xFF4A90E2) : Color(cat.colorHex);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF4A90E2),
        title: const Text(
          'Task Detail',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A90E2),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _titleCard(categoryColor, cat),
          const SizedBox(height: 12),
          _dateTimeCard(),
          if (_task.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            _section(
              'Description',
              child: Text(_task.description,
                  style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
          ],
          if (_task.localImagePath != null &&
              File(_task.localImagePath!).existsSync()) ...[
            const SizedBox(height: 12),
            _photoCard(),
          ],
          if (_task.latitude != null && _task.longitude != null) ...[
            const SizedBox(height: 12),
            _locationCard(),
          ],
          const SizedBox(height: 12),
          _reminderCard(),
          const SizedBox(height: 24),
          _metadataFooter(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        onPressed: _edit,
        icon: const Icon(Icons.edit),
        label: const Text('Edit'),
      ),
    );
  }

  Widget _titleCard(Color categoryColor, Category? cat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _task.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      decoration: _task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (cat != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label, size: 13, color: categoryColor),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: TextStyle(
                              color: categoryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: _task.isCompleted
                  ? 'Mark as incomplete'
                  : 'Mark as completed',
              child: InkWell(
                onTap: _toggleComplete,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _task.isCompleted
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: _task.isCompleted ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeCard() {
    final date = DateFormat('EEEE, MMMM d, y').format(_task.date);
    String time = '—';
    if (_task.startTime != null && _task.endTime != null) {
      time =
          '${DateFormat.jm().format(_task.startTime!)} – ${DateFormat.jm().format(_task.endTime!)}';
    } else if (_task.startTime != null) {
      time = DateFormat.jm().format(_task.startTime!);
    }
    return _section(
      'When',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 16, color: Color(0xFF4A90E2)),
              const SizedBox(width: 8),
              Expanded(child: Text(date, style: const TextStyle(fontSize: 14))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 16, color: Color(0xFF4A90E2)),
              const SizedBox(width: 8),
              Expanded(child: Text(time, style: const TextStyle(fontSize: 14))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(
                File(_task.localImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    final ll = LatLng(_task.latitude!, _task.longitude!);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (_task.locationName != null && _task.locationName!.isNotEmpty)
            Text(
              _task.locationName!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 4),
          Text(
            '${_task.latitude!.toStringAsFixed(5)}, ${_task.longitude!.toStringAsFixed(5)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: ll,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ets1',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: ll,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF4A90E2),
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderCard() {
    final hasStart = _task.startTime != null;
    return _section(
      'Reminder',
      child: Row(
        children: [
          Icon(
            _task.reminderEnabled
                ? Icons.notifications_active
                : Icons.notifications_off,
            size: 18,
            color: _task.reminderEnabled
                ? const Color(0xFF4A90E2)
                : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _task.reminderEnabled && hasStart
                  ? 'Will fire at ${DateFormat('MMM d, h:mm a').format(_task.startTime!)}'
                  : _task.reminderEnabled
                      ? 'Reminder enabled (no start time set)'
                      : 'Reminder disabled',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadataFooter() {
    final created = DateFormat('MMM d, y · h:mm a').format(_task.createdAt);
    final updated = DateFormat('MMM d, y · h:mm a').format(_task.updatedAt);
    return Center(
      child: Column(
        children: [
          Text('Created $created',
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          const SizedBox(height: 2),
          Text('Last updated $updated',
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _section(String title, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
