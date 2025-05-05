import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'details/location_picker_screen.dart';
import 'filter/filter_sheet.dart';
import 'task_creation_screen.dart';  // Add this import

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  final Function(int) onThemeChanged;

  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final List<String> _themeOptions = [
    'Light Theme',
    'Dark Theme',
    'Gradient Theme 1',
    'Gradient Theme 2',
    'Gradient Theme 3',
  ];

  int _selectedThemeIndex = 0;
  final _searchController = TextEditingController();
  String _searchText = '';
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date',
    order: 'descending',
  );
  bool _isTaskFormExpanded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Widget _buildAddTaskSection(BuildContext context, User user) {
    return TaskCreationScreen(
      user: user,
      onTaskAdded: () {
        // No need to do anything as StreamBuilder will handle updates
      },
      isExpanded: _isTaskFormExpanded,
      onExpandToggle: () {
        setState(() {
          _isTaskFormExpanded = !_isTaskFormExpanded;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          DropdownButton<int>(
            value: _selectedThemeIndex,
            icon: Icon(
              Icons.color_lens,
              color: _selectedThemeIndex == 1 ? Colors.white : Colors.black,
            ),
            dropdownColor: _selectedThemeIndex == 1 ? Colors.grey[800] : Colors.white,
            items: List.generate(
              _themeOptions.length,
              (index) => DropdownMenuItem(
                value: index,
                child: Text(
                  _themeOptions[index],
                  style: TextStyle(
                    // All text items will be white when dark theme is selected,
                    // black for all other themes
                    color: _selectedThemeIndex == 1 ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
            onChanged: (int? newIndex) {
              if (newIndex != null) {
                setState(() {
                  _selectedThemeIndex = newIndex;
                });
                widget.onThemeChanged(newIndex);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('todos')
            .orderBy('createdAt', descending: true)
            .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final todos = snapshot.data?.docs.map((doc) => Todo.fromSnapshot(doc)).toList() ?? [];
          final filteredTodos = filterAndSortTodos(todos);

          return LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 600;
              return Center(
                child: SizedBox(
                  width: isDesktop ? 600 : double.infinity,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            labelText: 'Search TODOs',
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
                          onChanged: (value) {
                            setState(() => _searchText = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredTodos.isEmpty
                            ? const Center(child: Text('No TODOs found'))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                itemCount: filteredTodos.length,
                                itemBuilder: (context, index) {
                                  final todo = filteredTodos[index];
                                  return ListTile(
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: todo.priority == 0
                                              ? Colors.green
                                              : todo.priority == 1
                                              ? Colors.orange
                                              : Colors.red,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 8),
                                        Checkbox(
                                          value: todo.completedAt != null,
                                          onChanged: (bool? value) {
                                            final updateData = {
                                              'completedAt': value == true ? FieldValue.serverTimestamp() : null
                                            };
                                            FirebaseFirestore.instance.collection('todos').doc(todo.id).update(updateData);
                                          },
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(Icons.arrow_forward_ios),
                                    title: Text(
                                      todo.text,
                                      style: todo.completedAt != null
                                          ? const TextStyle(decoration: TextDecoration.lineThrough)
                                          : null,
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
                              ),
                      ),
                      _buildAddTaskSection(context, user!),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AddTaskForm extends StatefulWidget {
  final User user;
  final VoidCallback onTaskAdded;

  const AddTaskForm({
    Key? key,
    required this.user,
    required this.onTaskAdded,
  }) : super(key: key);

  @override
  State<AddTaskForm> createState() => _AddTaskFormState();
}

class _AddTaskFormState extends State<AddTaskForm> with RouteAware {
  final _controller = TextEditingController();
  bool _isExpanded = false;
  String _category = 'None';
  DateTime? _dueDate;
  int _priority = 0;
  GeoPoint? _location;
  String? _locationName;
  List<String> _categories = ['None', 'Home', 'Work', 'School'];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    _setupCategoriesListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller.dispose();
    _scrollController.dispose();
    _categoriesSubscription?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Reset form when returning from detail screen
    _resetForm();
  }

  void _resetForm() {
    _controller.clear();
    setState(() {
      _category = 'None';
      _dueDate = null;
      _priority = 0;
      _location = null;
      _locationName = null;
    });
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

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _location != null
              ? LatLng(_location!.latitude, _location!.longitude)
              : null,
        ),
      ),
    );
    if (result != null && result['location'] != null) {
      final LatLng pickedLocation = result['location'];
      final String? locationName = result['name'];
      setState(() {
        _location = GeoPoint(pickedLocation.latitude, pickedLocation.longitude);
        _locationName = locationName ?? 'Lat: ${pickedLocation.latitude}, Lng: ${pickedLocation.longitude}';
      });
    }
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );
    
    if (selectedDate != null && mounted) {
      final TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: _dueDate != null
            ? TimeOfDay.fromDateTime(_dueDate!)
            : TimeOfDay.now(),
      );
      
      if (selectedTime != null && mounted) {
        setState(() {
          _dueDate = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _addCategory(String categoryName) async {
    try {
      // First check if category already exists
      final existingCategories = await FirebaseFirestore.instance
          .collection('categories')
          .where('name', isEqualTo: categoryName)
          .get();
      
      if (existingCategories.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('categories')
            .add({'name': categoryName});
      }
      
      setState(() {
        if (!_categories.contains(categoryName)) {
          _categories.add(categoryName);
        }
        _category = categoryName;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add category: $e')),
        );
      }
    }
  }

  Future<void> _addTask() async {
    if (widget.user != null && _controller.text.isNotEmpty) {
      await FirebaseFirestore.instance.collection('todos').add({
        'text': _controller.text,
        'createdAt': FieldValue.serverTimestamp(),
        'uid': widget.user.uid,
        'category': _category,  // Use the selected category
        'dueAt': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
        'location': _location,
        'locationName': _locationName,
        'priority': _priority,
        'completedAt': null,
        'subtasks': [],
      });
      _resetForm();
      widget.onTaskAdded();
    }
  }

  Future<void> _cleanupUnusedCategories() async {
    const defaultCategories = ['None', 'Home', 'Work', 'School'];
    final categoriesSnapshot = await FirebaseFirestore.instance.collection('categories').get();
    
    for (var categoryDoc in categoriesSnapshot.docs) {
      final categoryName = categoryDoc['name'] as String;
      if (!defaultCategories.contains(categoryName)) {
        // Check if any todos use this category
        final todosWithCategory = await FirebaseFirestore.instance
            .collection('todos')
            .where('category', isEqualTo: categoryName)
            .get();
            
        if (todosWithCategory.docs.isEmpty) {
          // If no todos use this category, delete it
          await categoryDoc.reference.delete();
        }
      }
    }
    await _fetchCategories(); // Refresh categories list
  }

  Future<void> _fetchCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    final customCategories = snapshot.docs.map((doc) => doc['name'] as String).toList();
    if (mounted) {
      setState(() {
        _categories = ['None', 'Home', 'Work', 'School', ...customCategories];
      });
    }
  }

  Future<void> _showCategoryDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: _category,
                isExpanded: true,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    key: ValueKey(category),
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(),
                      decoration: const InputDecoration(
                        labelText: 'New Custom Category',
                      ),
                      onSubmitted: (newCat) async {
                        if (newCat.isNotEmpty && !_categories.contains(newCat)) {
                          await _addCategory(newCat);
                          setState(() {
                            _category = newCat;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPriorityDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Priority'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                key: const ValueKey('priority-low'),
                value: 0,
                groupValue: _priority,
                title: const Text('Low'),
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
              ),
              RadioListTile<int>(
                key: const ValueKey('priority-medium'),
                value: 1,
                groupValue: _priority,
                title: const Text('Medium'),
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
              ),
              RadioListTile<int>(
                key: const ValueKey('priority-high'),
                value: 2,
                groupValue: _priority,
                title: const Text('High'),
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
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
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isExpanded ? 'Hide Add Task' : 'Add Task',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          // ...existing code...
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: SizedBox(
              height: 320,
              child: Scrollbar(
                controller: _scrollController,
                child: ListView(
                  key: const ValueKey('add-task-form'),
                  controller: _scrollController,
                  children: [
                    TextField(
                      key: const ValueKey('task-title'),
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      key: const ValueKey('category-tile'),
                      title: const Text('Category'),
                      subtitle: Text(_category),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showCategoryDialog(context),
                      ),
                    ),
                    ListTile(
                      key: const ValueKey('due-date-tile'),
                      title: const Text('Due Date'),
                      subtitle: Text(_dueDate != null 
                        ? _dueDate!.toLocal().toString().split('.')[0] 
                        : 'No due date'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_dueDate != null)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _dueDate = null;
                                });
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _pickDateTime(context),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      key: const ValueKey('priority-tile'),
                      title: const Text('Priority'),
                      subtitle: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: _priority == 0
                                ? Colors.green
                                : _priority == 1
                                    ? Colors.orange
                                    : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _priority == 0
                                ? 'Low'
                                : _priority == 1
                                    ? 'Medium'
                                    : 'High',
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showPriorityDialog(context),
                      ),
                    ),
                    ListTile(
                      key: const ValueKey('location-tile'),
                      title: const Text('Location'),
                      subtitle: Text(_locationName ??
                          (_location != null
                              ? 'Lat: ${_location!.latitude}, Lng: ${_location!.longitude}'
                              : 'No location')),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _pickLocation,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      key: const ValueKey('add-task-button'),
                      onPressed: () async {
                        await _addTask();
                        await _cleanupUnusedCategories();
                      },
                      child: const Text('Add Task'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
