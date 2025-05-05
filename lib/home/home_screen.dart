import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'details/location_picker_screen.dart';
import 'filter/filter_sheet.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  final Function(int) onThemeChanged;

  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _themeOptions = ['Light Theme', 'Dark Theme', 'Gradient Theme 1', 'Gradient Theme 2', 'Gradient Theme 3'];
  int _selectedThemeIndex = 0;
  final _searchController = TextEditingController();
  String _searchText = '';
  FilterSheetResult _filters = FilterSheetResult(sortBy: 'date', order: 'descending');
  bool _isAddingTask = false;
  final _taskTitleController = TextEditingController();
  String _selectedCategory = 'None';
  DateTime? _selectedDueDate;
  int _selectedPriority = 0;
  GeoPoint? _selectedLocation;
  String? _selectedLocationName;
  List<String> _categories = ['None', 'Home', 'Work', 'School'];
  final List<TextEditingController> _subtaskControllers = [];
  final List<bool> _subtaskCompletionStatus = [];
  final _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    _setupCategoriesListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _taskTitleController.dispose();
    _categoriesSubscription?.cancel();
    for (var controller in _subtaskControllers) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _setupCategoriesListener() {
    _categoriesSubscription = FirebaseFirestore.instance
        .collection('categories')
        .snapshots()
        .listen((snapshot) {
      final customCategories = snapshot.docs.map((doc) => doc['name'] as String).toList();
      if (mounted) {
        setState(() {
          _categories = ['None', 'Home', 'Work', 'School', ...customCategories];
        });
      }
    });
  }

  List<Todo> filterAndSortTodos(List<Todo> todos) {
    List<Todo> filteredTodos = todos.where((todo) {
      return todo.text.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();

    if (_filters.sortBy == 'date') {
      filteredTodos.sort((a, b) =>
          _filters.order == 'ascending' ? a.createdAt.compareTo(b.createdAt) : b.createdAt.compareTo(a.createdAt));
    } else if (_filters.sortBy == 'completed') {
      filteredTodos.sort((a, b) => _filters.order == 'ascending'
          ? (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0))
          : (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
    } else if (_filters.sortBy == 'priority') {
      filteredTodos.sort((a, b) => _filters.order == 'ascending' ? a.priority.compareTo(b.priority) : b.priority.compareTo(a.priority));
    }

    return filteredTodos;
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _selectedLocation != null
              ? LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude)
              : null,
        ),
      ),
    );
    if (result != null && result['location'] != null) {
      final LatLng pickedLocation = result['location'];
      final String? locationName = result['name'];
      setState(() {
        _selectedLocation = GeoPoint(pickedLocation.latitude, pickedLocation.longitude);
        _selectedLocationName = locationName ?? 'Lat: ${pickedLocation.latitude}, Lng: ${pickedLocation.longitude}';
      });
    }
  }

  Future<void> _addTask() async {
    if (_taskTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task title cannot be empty. Please enter a title and try again.')),
      );
      return;
    }
    
    setState(() {
      _isAddingTask = false;
    });

    try {
      // Filter out empty subtasks and create subtasks list
      List<Map<String, dynamic>> subtasks = _subtaskControllers.asMap().entries
          .map((entry) => {
                'text': entry.value.text.trim(),
                'completedAt': _subtaskCompletionStatus[entry.key] ? Timestamp.now() : null,
              })
          .where((subtask) => (subtask['text'] as String).isNotEmpty)
          .toList();

      // Check if all non-empty subtasks are completed
      final allSubtasksCompleted = subtasks.isNotEmpty && 
          subtasks.every((subtask) => subtask['completedAt'] != null);

      await FirebaseFirestore.instance.collection('todos').add({
        'text': _taskTitleController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'category': _selectedCategory,
        'dueAt': _selectedDueDate != null ? Timestamp.fromDate(_selectedDueDate!) : null,
        'location': _selectedLocation,
        'locationName': _selectedLocationName,
        'priority': _selectedPriority,
        'completedAt': allSubtasksCompleted ? Timestamp.now() : null,
        'subtasks': subtasks,
      });

      _resetTaskForm();
    } catch (e) {
      // Show error if task creation fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    }
  }

  // Add helper function for category management
  Future<void> addCategory(String newCategory) async {
    try {
      await FirebaseFirestore.instance.collection('categories').add({
        'name': newCategory,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add category: $e')),
        );
      }
    }
  }

  void _resetTaskForm() {
    setState(() {
      _taskTitleController.clear();
      _selectedCategory = 'None';
      _selectedDueDate = null;
      _selectedPriority = 0;
      _selectedLocation = null;
      _selectedLocationName = null;
      for (var controller in _subtaskControllers) {
        controller.dispose();
      }
      _subtaskControllers.clear();
      _subtaskCompletionStatus.clear();
    });
  }

  void _addSubtask() {
    if (_subtaskControllers.length < 10) {
      setState(() {
        _subtaskControllers.add(TextEditingController());
        _subtaskCompletionStatus.add(false);
      });
    }
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
      _subtaskCompletionStatus.removeAt(index);
    });
  }

  Widget _buildTaskForm() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add New Task',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _isAddingTask = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taskTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Category'),
                      subtitle: Text(_selectedCategory),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showCategoryDialog(),
                      ),
                    ),
                    ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(_selectedDueDate?.toString() ?? 'No due date'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedDueDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _selectedDueDate = null),
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _showDateTimePicker(),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: const Text('Priority'),
                      subtitle: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: _selectedPriority == 0
                                ? Colors.green
                                : _selectedPriority == 1
                                    ? Colors.orange
                                    : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedPriority == 0
                                ? 'Low'
                                : _selectedPriority == 1
                                    ? 'Medium'
                                    : 'High',
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showPriorityDialog(),
                      ),
                    ),
                    ListTile(
                      title: const Text('Location'),
                      subtitle: Text(_selectedLocationName ?? 'No location set'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_location),
                        onPressed: _pickLocation,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtasks',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_subtaskControllers.length < 10)
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: _addSubtask,
                                  ),
                              ],
                            ),
                            ..._subtaskControllers.asMap().entries.map((entry) {
                              int idx = entry.key;
                              var controller = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: controller,
                                        decoration: InputDecoration(
                                          labelText: 'Subtask ${idx + 1}',
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: _subtaskCompletionStatus[idx],
                                      onChanged: (value) {
                                        setState(() {
                                          _subtaskCompletionStatus[idx] = value!;
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => _removeSubtask(idx),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _addTask();
                        if (mounted) {
                          setState(() => _isAddingTask = false);
                        }
                      },
                      child: const Text('Add Task'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDateTimePicker() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? DateTime.now()),
    );

    if (time == null) return;

    setState(() {
      _selectedDueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _showPriorityDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('Low'),
              value: 0,
              groupValue: _selectedPriority,
              onChanged: (value) {
                setState(() => _selectedPriority = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('Medium'),
              value: 1,
              groupValue: _selectedPriority,
              onChanged: (value) {
                setState(() => _selectedPriority = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('High'),
              value: 2,
              groupValue: _selectedPriority,
              onChanged: (value) {
                setState(() => _selectedPriority = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryDialog() async {
    String? selectedCategory = _selectedCategory;
    final textController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: selectedCategory,
              isExpanded: true,
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Add New Category',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newCategory = textController.text.trim();
              if (newCategory.isNotEmpty && !_categories.contains(newCategory)) {
                await addCategory(newCategory);
                setState(() {
                  _selectedCategory = newCategory;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add New'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          DropdownButton<int>(
            value: _selectedThemeIndex,
            icon: Icon(Icons.color_lens, color: _selectedThemeIndex == 1 ? Colors.white : Colors.black),
            items: List.generate(
              _themeOptions.length,
              (index) => DropdownMenuItem(value: index, child: Text(_themeOptions[index])),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedThemeIndex = value);
                widget.onThemeChanged(value);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () async {
                      final result = await showModalBottomSheet<FilterSheetResult>(
                        context: context,
                        builder: (context) => FilterSheet(initialFilters: _filters),
                      );
                      if (result != null) {
                        setState(() => _filters = result);
                      }
                    },
                  ),
                ),
                onChanged: (value) => setState(() => _searchText = value),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('todos')
                        .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final todos = snapshot.data?.docs
                          .map((doc) => Todo.fromSnapshot(doc))
                          .toList() ?? [];
                      final filteredTodos = filterAndSortTodos(todos);

                      return ListView.builder(
                        itemCount: filteredTodos.length,
                        itemBuilder: (context, index) {
                          final todo = filteredTodos[index];
                          return ListTile(
                            leading: Checkbox(
                              value: todo.completedAt != null,
                              onChanged: (value) async {
                                final timestamp = value == true ? Timestamp.now() : null;
                                final todoRef = FirebaseFirestore.instance.collection('todos').doc(todo.id);
                                
                                // Get current subtasks
                                final doc = await todoRef.get();
                                if (doc.exists) {
                                  final data = doc.data();
                                  if (data != null && data['subtasks'] != null) {
                                    final List<dynamic> subtasks = data['subtasks'];
                                    
                                    if (value == true) {
                                      // When marking as complete, mark all subtasks as complete
                                      final updatedSubtasks = subtasks.map((s) {
                                        final Map<String, dynamic> subtask = Map<String, dynamic>.from(s);
                                        subtask['completedAt'] = timestamp;
                                        return subtask;
                                      }).toList();
                                      
                                      await todoRef.update({
                                        'completedAt': timestamp,
                                        'subtasks': updatedSubtasks,
                                      });
                                    } else {
                                      // When unchecking, uncheck all subtasks
                                      final updatedSubtasks = subtasks.map((s) {
                                        final Map<String, dynamic> subtask = Map<String, dynamic>.from(s);
                                        subtask['completedAt'] = null;
                                        return subtask;
                                      }).toList();
                                      
                                      await todoRef.update({
                                        'completedAt': null,
                                        'subtasks': updatedSubtasks,
                                      });
                                    }
                                  } else {
                                    // If no subtasks, just update the main task
                                    await todoRef.update({
                                      'completedAt': timestamp,
                                    });
                                  }
                                }
                              },
                            ),
                            title: Text(
                              todo.text,
                              style: todo.completedAt != null
                                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                                  : null,
                            ),
                            subtitle: Text(todo.category),
                            trailing: Icon(
                              Icons.circle,
                              color: todo.priority == 0
                                  ? Colors.green
                                  : todo.priority == 1
                                      ? Colors.orange
                                      : Colors.red,
                              size: 12,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailScreen(todo: todo),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  if (_isAddingTask)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAddingTask = false),
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: GestureDetector(
                            onTap: () {}, // Prevent tap from propagating
                            child: _buildTaskForm(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _isAddingTask = !_isAddingTask),
        child: Icon(_isAddingTask ? Icons.close : Icons.add),
      ),
    );
  }
}
