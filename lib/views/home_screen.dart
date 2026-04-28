import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/auth_controller.dart';
import '../controllers/task_controller.dart';
import '../services/notification_service.dart';
import 'calendar_screen.dart';
import 'category_screen.dart';
import 'profile_screen.dart';
import 'task_detail_screen.dart';
import 'task_form_sheet.dart';
import 'widgets/task_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<int>? _tapSub;

  final List<Widget> _pages = const [
    DailyDashboard(),
    CalendarScreen(),
    CategoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tapSub = NotificationService.instance.taskTaps.listen(_handleTaskTap);
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    super.dispose();
  }

  Future<void> _handleTaskTap(int taskId) async {
    final controller = context.read<TaskController>();
    final task = await controller.findById(taskId);
    if (task == null || !mounted) return;
    setState(() => _selectedIndex = 0);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(task: task),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Daily'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: 'Calendar'),
            BottomNavigationBarItem(
                icon: Icon(Icons.label_outline),
                activeIcon: Icon(Icons.label),
                label: 'Labels'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile'),
          ],
          selectedItemColor: const Color(0xFF4A90E2),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      floatingActionButton: _selectedIndex <= 1
          ? FloatingActionButton(
              onPressed: () => _showTaskFormSheet(context),
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add, size: 30),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showTaskFormSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TaskFormSheet(),
    );
  }
}

class DailyDashboard extends StatelessWidget {
  const DailyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Fata's Doze Task",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              email,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Consumer<TaskController>(
        builder: (context, controller, child) {
          final tasks = controller.tasks;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  DateFormat('EEEE, MMMM d').format(controller.selectedDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isSameDay(controller.selectedDate, DateTime.now())
                          ? "Today's Focus"
                          : DateFormat('MMM d, y')
                              .format(controller.selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "${tasks.length} Tasks",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? _buildEmptyState(context, controller)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          return TaskCard(task: tasks[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TaskController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Nothing planned for this day",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap + to add your first task",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
