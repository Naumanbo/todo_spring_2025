import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'details/location_picker_screen.dart';
import 'controllers/task_controllers.dart';

class TaskCreationScreen extends StatefulWidget {
  final User user;
  final VoidCallback onTaskAdded;
  final bool isExpanded;
  final VoidCallback onExpandToggle;

  const TaskCreationScreen({
    Key? key,
    required this.user,
    required this.onTaskAdded,
    required this.isExpanded,
    required this.onExpandToggle,
  }) : super(key: key);

  @override
  State<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends State<TaskCreationScreen> {
  final TaskController _controller = TaskController();
  final TextEditingController _titleController = TextEditingController();
  final List<String> _defaultCategories = ['None', 'Home', 'Work', 'School'];
  final ValueNotifier<List<String>> _categories = ValueNotifier(['None', 'Home', 'Work', 'School']);

  @override
  void initState() {
    super.initState();
    _setupCategoriesListener();
    _titleController.addListener(() {
      _controller.title.value = _titleController.text;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setupCategoriesListener() {
    FirebaseFirestore.instance
        .collection('categories')
        .snapshots()
        .listen((snapshot) {
      final customCategories = snapshot.docs.map((doc) => doc['name'] as String).toList();
      _categories.value = [..._defaultCategories, ...customCategories];
    });
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _controller.dueDate.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );
    
    if (date != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_controller.dueDate.value ?? DateTime.now()),
      );
      
      if (time != null && mounted) {
        _controller.dueDate.value = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _controller.location.value != null
              ? LatLng(
                  _controller.location.value!.latitude,
                  _controller.location.value!.longitude,
                )
              : null,
        ),
      ),
    );

    if (result != null && result['location'] != null) {
      final LatLng location = result['location'];
      _controller.location.value = GeoPoint(location.latitude, location.longitude);
      _controller.locationName.value = result['name'] ?? 
          'Lat: ${location.latitude}, Lng: ${location.longitude}';
    }
  }

  Future<void> _createTask() async {
    if (_controller.title.value.isEmpty) return;

    await FirebaseFirestore.instance.collection('todos').add({
      ..._controller.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'uid': widget.user.uid,
    });

    _controller.reset();
    _titleController.clear();
    widget.onTaskAdded();
  }

  Future<void> _addCategory(String categoryName) async {
    if (categoryName.isEmpty) return;
    
    try {
      // Check if category already exists
      final existingCategories = await FirebaseFirestore.instance
          .collection('categories')
          .where('name', isEqualTo: categoryName)
          .get();
      
      if (existingCategories.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('categories')
            .add({'name': categoryName});
      }
      
      _controller.category.value = categoryName;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add category: $e')),
        );
      }
    }
  }

  Widget _buildCategorySelector() {
    return ValueListenableBuilder<String>(
      valueListenable: _controller.category,
      builder: (context, category, _) {
        return ValueListenableBuilder<List<String>>(
          valueListenable: _categories,
          builder: (context, categories, _) {
            return Column(
              children: [
                DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  items: categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _controller.category.value = value;
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Add Custom Category',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.add),
                  ),
                  onSubmitted: _addCategory,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPrioritySelector() {
    return ValueListenableBuilder<int>(
      valueListenable: _controller.priority,
      builder: (context, priority, _) {
        return SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Low'),
              icon: Icon(Icons.circle, color: Colors.green),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Medium'),
              icon: Icon(Icons.circle, color: Colors.orange),
            ),
            ButtonSegment(
              value: 2,
              label: Text('High'),
              icon: Icon(Icons.circle, color: Colors.red),
            ),
          ],
          selected: {priority},
          onSelectionChanged: (Set<int> selected) {
            _controller.priority.value = selected.first;
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      color: Colors.green[100],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onExpandToggle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isExpanded ? 'Hide Add Task' : 'Add Task',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Icon(widget.isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (widget.isExpanded)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategorySelector(),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<DateTime?>(
                      valueListenable: _controller.dueDate,
                      builder: (context, dueDate, _) {
                        return ListTile(
                          title: const Text('Due Date'),
                          subtitle: Text(
                            dueDate?.toString() ?? 'No due date set',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _controller.dueDate.value = null,
                                ),
                              IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _pickDateTime,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPrioritySelector(),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<String?>(
                      valueListenable: _controller.locationName,
                      builder: (context, locationName, _) {
                        return ListTile(
                          title: const Text('Location'),
                          subtitle: Text(locationName ?? 'No location set'),
                          trailing: IconButton(
                            icon: const Icon(Icons.location_on),
                            onPressed: _pickLocation,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createTask,
                      child: const Text('Create Task'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}