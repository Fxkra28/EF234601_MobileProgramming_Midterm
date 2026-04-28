import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/task_controller.dart';
import 'widgets/task_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isYearView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 10, 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isYearView ? 'Yearly Overview' : 'Calendar View',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _isYearView = !_isYearView),
                    icon: Icon(
                      _isYearView ? Icons.calendar_today : Icons.grid_view,
                      size: 20,
                    ),
                    label: Text(
                      _isYearView ? "Month" : "Year",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4A90E2),
                      backgroundColor:
                          const Color(0xFF4A90E2).withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<TaskController>(
                builder: (context, controller, child) {
                  return _isYearView
                      ? _buildYearGrid(controller)
                      : _buildMonthView(controller);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthView(TaskController controller) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: controller.selectedDate,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) =>
                isSameDay(controller.selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              controller.setSelectedDate(selectedDay);
            },
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            onHeaderTapped: (focusedDay) =>
                setState(() => _isYearView = true),
            eventLoader: (day) {
              final normalizedDay = DateTime(day.year, day.month, day.day);
              return controller.datesWithTasks.contains(normalizedDay)
                  ? [true]
                  : [];
            },
            calendarStyle: CalendarStyle(
              markerDecoration: const BoxDecoration(
                color: Color(0xFF4A90E2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF4A90E2),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: Color(0xFF4A90E2),
                fontWeight: FontWeight.bold,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Divider(height: 1),
        ),
        Expanded(child: _buildTaskList(controller)),
      ],
    );
  }

  Widget _buildYearGrid(TaskController controller) {
    final currentYear = controller.selectedDate.year;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _yearNavButton(Icons.chevron_left, () {
                controller.setSelectedDate(DateTime(currentYear - 1, 1, 1));
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$currentYear',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              _yearNavButton(Icons.chevron_right, () {
                controller.setSelectedDate(DateTime(currentYear + 1, 1, 1));
              }),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final monthDate = DateTime(currentYear, index + 1, 1);
              final isCurrentMonth =
                  controller.selectedDate.month == index + 1;

              final tasksInMonth = controller.datesWithTasks
                  .where((date) =>
                      date.year == currentYear && date.month == index + 1)
                  .length;

              return InkWell(
                onTap: () {
                  controller.setSelectedDate(monthDate);
                  setState(() => _isYearView = false);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrentMonth
                        ? const Color(0xFF4A90E2).withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentMonth
                          ? const Color(0xFF4A90E2)
                          : Colors.grey.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM').format(monthDate).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrentMonth
                              ? const Color(0xFF4A90E2)
                              : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (tasksInMonth > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$tasksInMonth',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Text(
                          '0 tasks',
                          style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _yearNavButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF4A90E2)),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildTaskList(TaskController controller) {
    final tasks = controller.tasks;

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note,
                size: 60, color: Colors.grey.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              "No tasks scheduled",
              style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.6), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return TaskCard(task: tasks[index]);
      },
    );
  }
}
