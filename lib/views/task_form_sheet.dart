import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/category_controller.dart';
import '../controllers/task_controller.dart';
import '../models/task_model.dart';
import '../services/image_service.dart';
import 'location_picker_screen.dart';

class TaskFormSheet extends StatefulWidget {
  final Task? task;

  const TaskFormSheet({super.key, this.task});

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _categoryId;
  String? _imagePath;
  bool _imageChanged = false;
  bool _imageCleared = false;
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _locationCleared = false;
  late bool _reminderEnabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _selectedDate = t?.date ?? context.read<TaskController>().selectedDate;
    if (t?.startTime != null) {
      _startTime = TimeOfDay.fromDateTime(t!.startTime!);
    }
    if (t?.endTime != null) {
      _endTime = TimeOfDay.fromDateTime(t!.endTime!);
    }
    _categoryId = t?.categoryId;
    _imagePath = t?.localImagePath ?? t?.remoteImageUrl;
    _latitude = t?.latitude;
    _longitude = t?.longitude;
    _locationName = t?.locationName;
    _reminderEnabled = t?.reminderEnabled ?? (t?.startTime != null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _presentDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) setState(() => _selectedDate = pickedDate);
  }

  Future<void> _presentTimePicker(bool isStart) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        if (isStart) {
          _startTime = pickedTime;
          if (_reminderEnabled == false) _reminderEnabled = true;
        } else {
          _endTime = pickedTime;
        }
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final path = await ImageService.instance.pickFromCamera();
    if (path != null) {
      setState(() {
        _imagePath = path;
        _imageChanged = true;
        _imageCleared = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final path = await ImageService.instance.pickFromGallery();
    if (path != null) {
      setState(() {
        _imagePath = path;
        _imageChanged = true;
        _imageCleared = false;
      });
    }
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _locationCleared ? null : _latitude,
          initialLongitude: _locationCleared ? null : _longitude,
          initialName: _locationCleared ? null : _locationName,
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
      _locationName = picked.name;
      _locationCleared = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a category.')),
      );
      return;
    }
    if (_startTime != null && _endTime != null) {
      final start = _startTime!.hour * 60 + _startTime!.minute;
      final end = _endTime!.hour * 60 + _endTime!.minute;
      if (end <= start) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
        return;
      }
    }

    setState(() => _busy = true);
    final controller = context.read<TaskController>();

    DateTime? startDateTime;
    if (_startTime != null) {
      startDateTime = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _startTime!.hour, _startTime!.minute);
    }
    DateTime? endDateTime;
    if (_endTime != null) {
      endDateTime = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _endTime!.hour, _endTime!.minute);
    }

    if (widget.task == null) {
      await controller.addTask(
        categoryId: _categoryId!,
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        startTime: startDateTime,
        endTime: endDateTime,
        localImagePath: _imageChanged ? _imagePath : null,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        reminderEnabled: _reminderEnabled,
      );
    } else {
      await controller.updateTask(
        widget.task!,
        categoryId: _categoryId!,
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        startTime: startDateTime,
        endTime: endDateTime,
        newLocalImagePath: _imageChanged ? _imagePath : null,
        clearImage: _imageCleared,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        clearLocation: _locationCleared,
        reminderEnabled: _reminderEnabled,
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryController>().categories;
    if (_categoryId == null && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.task == null ? 'Create New Task' : 'Update Task',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A90E2),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: _decoration('Task Title', Icons.title),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: _decoration('Description', Icons.description),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              const Text("Category",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                items: categories
                    .map((c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Color(c.colorHex),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(c.name),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                decoration: _decoration('Pick category', Icons.label_outline),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              const Text("Date & Time",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              InkWell(
                onTap: _presentDatePicker,
                child: _tile(
                  icon: Icons.calendar_today,
                  child: Text(
                    DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 15),
                  ),
                  trailing:
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _presentTimePicker(true),
                      child: _tile(
                        icon: Icons.access_time,
                        child: Text(_startTime?.format(context) ?? 'Start',
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _presentTimePicker(false),
                      child: _tile(
                        icon: Icons.access_time,
                        child: Text(_endTime?.format(context) ?? 'End',
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Photo",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _tile(icon: Icons.image_outlined, child: _photoControl()),
              const SizedBox(height: 20),
              const Text("Location",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _tile(icon: Icons.location_on_outlined, child: _locationControl()),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Remind me',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(_startTime == null
                    ? 'Pick a start time to enable reminders'
                    : 'Notify when this task starts'),
                value: _reminderEnabled && _startTime != null,
                onChanged: _startTime == null
                    ? null
                    : (v) => setState(() => _reminderEnabled = v),
                activeThumbColor: const Color(0xFF4A90E2),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          widget.task == null ? 'Create Task' : 'Save Changes',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoControl() {
    final hasPath = _imagePath != null && !_imageCleared;
    return Row(
      children: [
        if (hasPath)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _imagePath!.startsWith('http')
                ? Image.network(_imagePath!,
                    width: 56, height: 56, fit: BoxFit.cover)
                : Image.file(File(_imagePath!),
                    width: 56, height: 56, fit: BoxFit.cover),
          )
        else
          Text('No photo',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const Spacer(),
        IconButton(
          tooltip: 'Camera',
          icon: const Icon(Icons.camera_alt, color: Color(0xFF4A90E2)),
          onPressed: _pickFromCamera,
        ),
        IconButton(
          tooltip: 'Gallery',
          icon: const Icon(Icons.photo_library, color: Color(0xFF4A90E2)),
          onPressed: _pickFromGallery,
        ),
        if (hasPath)
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, color: Colors.redAccent),
            onPressed: () => setState(() {
              _imagePath = null;
              _imageChanged = false;
              _imageCleared = true;
            }),
          ),
      ],
    );
  }

  Widget _locationControl() {
    final hasLoc = _latitude != null && _longitude != null && !_locationCleared;
    return Row(
      children: [
        Expanded(
          child: hasLoc
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_locationName != null && _locationName!.isNotEmpty)
                      Text(
                        _locationName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    Text(
                      '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                )
              : Text('No location set',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ),
        IconButton(
          tooltip: 'Pick on map',
          icon: const Icon(Icons.map_outlined, color: Color(0xFF4A90E2)),
          onPressed: _busy ? null : _pickLocation,
        ),
        if (hasLoc)
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, color: Colors.redAccent),
            onPressed: () => setState(() {
              _latitude = null;
              _longitude = null;
              _locationName = null;
              _locationCleared = true;
            }),
          ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4A90E2)),
          const SizedBox(width: 12),
          Expanded(child: child),
          ?trailing,
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
