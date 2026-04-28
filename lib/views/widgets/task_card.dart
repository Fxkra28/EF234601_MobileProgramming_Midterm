import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/category_controller.dart';
import '../../controllers/task_controller.dart';
import '../../models/task_model.dart';
import '../task_detail_screen.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<CategoryController>();
    final cat = cats.byId(task.categoryId);
    final categoryColor =
        cat == null ? const Color(0xFF4A90E2) : Color(cat.colorHex);

    final now = DateTime.now();
    final start = task.startTime;
    final overdue = start != null &&
        start.isBefore(now) &&
        !task.isCompleted;
    final soon = !overdue &&
        start != null &&
        start.isAfter(now) &&
        start.isBefore(now.add(const Duration(minutes: 30))) &&
        !task.isCompleted;
    final barColor = overdue
        ? Colors.red.shade400
        : soon
            ? Colors.orange.shade400
            : categoryColor;

    String timeRange = '';
    if (task.startTime != null && task.endTime != null) {
      timeRange =
          '${DateFormat.jm().format(task.startTime!)} - ${DateFormat.jm().format(task.endTime!)}';
    } else if (task.startTime != null) {
      timeRange = DateFormat.jm().format(task.startTime!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('task-${task.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (direction) {
          context.read<TaskController>().deleteTask(task);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${task.title} deleted')),
          );
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TaskDetailScreen(task: task),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Checkbox(
                            value: task.isCompleted,
                            onChanged: (value) {
                              context
                                  .read<TaskController>()
                                  .toggleTaskCompletion(task);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            activeColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: task.isCompleted
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (timeRange.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        timeRange,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    task.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (cat != null ||
                                    task.latitude != null ||
                                    task.reminderEnabled ||
                                    overdue ||
                                    soon) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (overdue)
                                        _chip(
                                          icon: Icons.warning_amber_rounded,
                                          label: 'OVERDUE',
                                          color: Colors.red.shade600,
                                        ),
                                      if (soon)
                                        _chip(
                                          icon: Icons.schedule,
                                          label: 'Starting soon',
                                          color: Colors.orange.shade700,
                                        ),
                                      if (cat != null)
                                        _chip(
                                          icon: Icons.label,
                                          label: cat.name,
                                          color: categoryColor,
                                        ),
                                      if (task.latitude != null &&
                                          task.longitude != null)
                                        _chip(
                                          icon: Icons.place,
                                          label: _locationLabel(task),
                                          color: Colors.teal,
                                        ),
                                      if (task.reminderEnabled)
                                        _chip(
                                          icon: Icons.notifications_active,
                                          label: 'Reminder',
                                          color: Colors.orange,
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (task.localImagePath != null ||
                              task.remoteImageUrl != null) ...[
                            const SizedBox(width: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _thumbnail(),
                            ),
                          ],
                        ],
                      ),
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

  Widget _thumbnail() {
    if (task.localImagePath != null && File(task.localImagePath!).existsSync()) {
      return Image.file(File(task.localImagePath!),
          width: 44, height: 44, fit: BoxFit.cover);
    }
    if (task.remoteImageUrl != null) {
      return Image.network(task.remoteImageUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
                width: 44,
                height: 44,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, size: 20),
              ));
    }
    return const SizedBox.shrink();
  }

  String _locationLabel(Task task) {
    final name = task.locationName;
    if (name != null && name.isNotEmpty) {
      final firstPart = name.split(',').first.trim();
      return firstPart.isEmpty ? name : firstPart;
    }
    return '${task.latitude!.toStringAsFixed(2)}, ${task.longitude!.toStringAsFixed(2)}';
  }

  Widget _chip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
