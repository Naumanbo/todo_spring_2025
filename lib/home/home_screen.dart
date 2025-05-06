// home_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'details/location_picker_screen.dart';
import 'filter/filter_sheet.dart';
import 'calendar/calendar_screen.dart';
import 'widgets/expandable_fab.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// Built‑in categories that can’t be removed.
const List<String> _defaultCategories = ['None', 'Home', 'Work', 'School'];

class HomeScreen extends StatefulWidget {
  final Function(int) onThemeChanged;
  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ────────────────────────────  THEME  ────────────────────────────
  final List<String> _themeOptions = [
    'Light Theme',
    'Dark Theme',
    'Gradient Theme 1',
    'Gradient Theme 2',
    'Gradient Theme 3'
  ];
  int _selectedThemeIndex = 0;
  Color? get _accentColor => switch (_selectedThemeIndex) {
        2 => Colors.blue,
        3 => Colors.orange,
        4 => Colors.green,
        _ => null,
      };
  Color? get _surfaceColor => switch (_selectedThemeIndex) {
        2 => Colors.blue[100],
        3 => Colors.orange[100],
        4 => Colors.green[100],
        1 =>
          // Dark theme uses Material surface so it adapts automatically.
          Theme.of(context).colorScheme.surface,
        _ => Colors.white,
      };

  // ────────────────────────────  STATE  ────────────────────────────
  final _searchController = TextEditingController();
  String _searchText = '';
  FilterSheetResult _filters =
      FilterSheetResult(sortBy: 'date', order: 'descending');

  bool _isAddingTask = false;
  final _taskTitleController = TextEditingController();

  // Task properties
  String _selectedCategory = 'None';
  DateTime? _selectedDueDate;
  int _selectedPriority = 0;
  GeoPoint? _selectedLocation;
  String? _selectedLocationName;

  // Category list (default + any custom)
  List<String> _categories = List.from(_defaultCategories);

  // Subtasks
  final List<TextEditingController> _subtaskControllers = [];
  final List<bool> _subtaskCompletionStatus = [];

  final _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _categoriesSubscription;

  // ────────────────────────────  INIT / DISPOSE  ───────────────────
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
    for (final c in _subtaskControllers) c.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ────────────────────────────  CATEGORY HELPERS  ─────────────────
  void _setupCategoriesListener() {
    _categoriesSubscription = FirebaseFirestore.instance
        .collection('categories')
        .snapshots()
        .listen((snapshot) {
      final custom =
          snapshot.docs.map((d) => d['name'] as String).where((e) => e.trim().isNotEmpty);
      if (mounted) {
        setState(() {
          _categories = [..._defaultCategories, ...custom];
        });
      }
    });
  }

  Future<List<String>> _fetchCategories() async {
    final snap = await FirebaseFirestore.instance.collection('categories').get();
    final custom =
        snap.docs.map((d) => d['name'] as String).where((e) => e.trim().isNotEmpty);
    return [..._defaultCategories, ...custom];
  }

  Future<void> _addCategory(String name) async {
    await FirebaseFirestore.instance
        .collection('categories')
        .add({'name': name, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> _deleteCategory(String name) async {
    final snap = await FirebaseFirestore.instance
        .collection('categories')
        .where('name', isEqualTo: name)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _removeCategory(String name) async {
    await _deleteCategory(name);

    // Re‑assign todos that use this category.
    final todosSnap = await FirebaseFirestore.instance
        .collection('todos')
        .where('category', isEqualTo: name)
        .get();
    for (final doc in todosSnap.docs) {
      await doc.reference.update({'category': 'None'});
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "$name" removed!')),
      );
    }
  }

  // ────────────────────────────  FILTER / SORT  ────────────────────
  List<Todo> _filterAndSort(List<Todo> todos) {
    final filtered = todos
        .where((t) => t.text.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();

    int compareDate(DateTime? a, DateTime? b) =>
        (a ?? DateTime(0)).compareTo(b ?? DateTime(0));

    switch (_filters.sortBy) {
      case 'completed':
        filtered.sort((a, b) => _filters.order == 'ascending'
            ? compareDate(a.completedAt, b.completedAt)
            : compareDate(b.completedAt, a.completedAt));
        break;
      case 'priority':
        filtered.sort((a, b) => _filters.order == 'ascending'
            ? a.priority.compareTo(b.priority)
            : b.priority.compareTo(a.priority));
        break;
      default:
        filtered.sort((a, b) => _filters.order == 'ascending'
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt));
    }
    return filtered;
  }

  // ────────────────────────────  LOCATION PICKER  ──────────────────
  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _selectedLocation != null
              ? LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude)
              : null,
        ),
      ),
    );

    if (result != null && result['location'] != null) {
      final LatLng loc = result['location'];
      setState(() {
        _selectedLocation = GeoPoint(loc.latitude, loc.longitude);
        _selectedLocationName =
            result['name'] ?? 'Lat: ${loc.latitude}, Lng: ${loc.longitude}';
      });
    }
  }

  // ────────────────────────────  ADD TASK  ─────────────────────────
  Future<void> _addTask() async {
    if (_taskTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Task title cannot be empty.'),
          behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => _isAddingTask = false);

    final subtasks = _subtaskControllers.asMap().entries.map((e) {
      final txt = e.value.text.trim();
      if (txt.isEmpty) return null;
      return {
        'text': txt,
        'completedAt': _subtaskCompletionStatus[e.key] ? Timestamp.now() : null,
      };
    }).where((e) => e != null).cast<Map<String, dynamic>>().toList();

    final allDone =
        subtasks.isNotEmpty && subtasks.every((s) => s['completedAt'] != null);

    await FirebaseFirestore.instance.collection('todos').add({
      'text': _taskTitleController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'uid': FirebaseAuth.instance.currentUser!.uid,
      'category': _selectedCategory,
      'dueAt': _selectedDueDate != null
          ? Timestamp.fromDate(_selectedDueDate!)
          : null,
      'location': _selectedLocation,
      'locationName': _selectedLocationName,
      'priority': _selectedPriority,
      'completedAt': allDone ? Timestamp.now() : null,
      'subtasks': subtasks,
    });

    _resetTaskForm();
  }

  void _resetTaskForm() {
    _taskTitleController.clear();
    _selectedCategory = 'None';
    _selectedDueDate = null;
    _selectedPriority = 0;
    _selectedLocation = null;
    _selectedLocationName = null;
    for (final c in _subtaskControllers) c.dispose();
    _subtaskControllers.clear();
    _subtaskCompletionStatus.clear();
  }

  // ────────────────────────────  SUBTASKS  ─────────────────────────
  void _addSubtask() {
    if (_subtaskControllers.length >= 10) return;
    setState(() {
      _subtaskControllers.add(TextEditingController());
      _subtaskCompletionStatus.add(false);
    });
  }

  void _removeSubtask(int i) {
    _subtaskControllers[i].dispose();
    setState(() {
      _subtaskControllers.removeAt(i);
      _subtaskCompletionStatus.removeAt(i);
    });
  }

  // ────────────────────────────  PICKERS  ──────────────────────────
  Future<void> _showDateTimePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedDueDate != null
          ? TimeOfDay.fromDateTime(_selectedDueDate!)
          : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDueDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _showPriorityDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in [0, 1, 2])
              RadioListTile<int>(
                title: Text(['Low', 'Medium', 'High'][p]),
                value: p,
                groupValue: _selectedPriority,
                onChanged: (v) => setState(() => _selectedPriority = v!),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryDialog() async {
    List<String> cats = await _fetchCategories();
    String? selected = _selectedCategory;
    final newController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setStateSB) => AlertDialog(
            title: const Text('Edit Category'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown + (optional) delete icon
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selected,
                        items: cats
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setStateSB(() => selected = v),
                      ),
                    ),
                    if (selected != null &&
                        !_defaultCategories.contains(selected))
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete Category'),
                              content: Text(
                                  'Are you sure you want to delete "$selected"?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true && selected != null) {
                            await _removeCategory(selected!);
                            cats.remove(selected);
                            setStateSB(() {
                              selected =
                                  cats.isNotEmpty ? cats.first : 'None';
                            });
                          }
                        },
                      ),
                  ],
                ),
                // Add new
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newController,
                        decoration: const InputDecoration(
                            labelText: 'New Custom Category'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final name = newController.text.trim();
                        if (name.isEmpty || cats.contains(name)) return;
                        await _addCategory(name);
                        setStateSB(() {
                          cats.add(name);
                          selected = name;
                        });
                        newController.clear();
                      },
                    ),
                  ],
                )
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () {
                    if (selected != null) {
                      setState(() => _selectedCategory = selected!);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save')),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────  TASK FORM  ────────────────────────
  Widget _buildTaskForm() {
    final buttonStyle = _accentColor != null
        ? ElevatedButton.styleFrom(backgroundColor: _accentColor)
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16),
          child: Column(
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add New Task',
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _isAddingTask = false)),
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
                    onPressed: _showCategoryDialog),
              ),
              ListTile(
                title: const Text('Due Date'),
                subtitle:
                    Text(_selectedDueDate?.toString() ?? 'No due date'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedDueDate != null)
                      IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _selectedDueDate = null)),
                    IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _showDateTimePicker),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Priority'),
                subtitle: Row(
                  children: [
                    Icon(Icons.circle,
                        size: 16,
                        color: [Colors.green, Colors.orange, Colors.red]
                            [_selectedPriority]),
                    const SizedBox(width: 6),
                    Text(['Low', 'Medium', 'High'][_selectedPriority]),
                  ],
                ),
                trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showPriorityDialog),
              ),
              ListTile(
                title: const Text('Location'),
                subtitle:
                    Text(_selectedLocationName ?? 'No location set'),
                trailing: IconButton(
                    icon: const Icon(Icons.edit_location),
                    onPressed: _pickLocation),
              ),
              const SizedBox(height: 8),
              // SUBTASKS
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtasks',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                          if (_subtaskControllers.length < 10)
                            IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _addSubtask),
                        ],
                      ),
                      ..._subtaskControllers.asMap().entries.map((e) {
                        final i = e.key;
                        final ctrl = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ctrl,
                                  decoration: InputDecoration(
                                      labelText: 'Subtask ${i + 1}',
                                      isDense: true),
                                ),
                              ),
                              Checkbox(
                                  value: _subtaskCompletionStatus[i],
                                  onChanged: (v) => setState(() =>
                                      _subtaskCompletionStatus[i] =
                                          v ?? false)),
                              IconButton(
                                  icon:
                                      const Icon(Icons.remove_circle_outline),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeSubtask(i)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: buttonStyle,
                onPressed: () async {
                  await _addTask();
                  if (mounted) setState(() => _isAddingTask = false);
                },
                child: const Text('Add Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────  BUILD  ────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        title: const Text('Home'),
        actions: [
          DropdownButton<int>(
            value: _selectedThemeIndex,
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.color_lens,
                color: _selectedThemeIndex == 1 ? Colors.white : Colors.black),
            items: List.generate(
              _themeOptions.length,
              (i) => DropdownMenuItem<int>(
                  value: i, child: Text(_themeOptions[i])),
            ),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedThemeIndex = v);
              widget.onThemeChanged(v);
            },
          ),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                // SEARCH
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () async {
                          final res = await showModalBottomSheet<
                              FilterSheetResult>(
                            context: context,
                            builder: (_) =>
                                FilterSheet(initialFilters: _filters),
                          );
                          if (res != null) {
                            setState(() => _filters = res);
                          }
                        },
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchText = v),
                  ),
                ),
                // TASK LIST
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('todos')
                        .where('uid',
                            isEqualTo: FirebaseAuth
                                .instance.currentUser
                                ?.uid)
                        .snapshots(),
                    builder: (_, snap) {
                      if (snap.hasError) {
                        return Center(child: Text('Error: ${snap.error}'));
                      }
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final todos = snap.data?.docs
                              .map((d) => Todo.fromSnapshot(d))
                              .toList() ??
                          [];
                      final items = _filterAndSort(todos);

                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final t = items[i];
                          return ListTile(
                            leading: Checkbox(
                              value: t.completedAt != null,
                              onChanged: (v) async {
                                final ref = FirebaseFirestore.instance
                                    .collection('todos')
                                    .doc(t.id);
                                final ts = v == true ? Timestamp.now() : null;
                                final doc = await ref.get();
                                final data = doc.data();
                                if (data != null &&
                                    data['subtasks'] != null) {
                                  final subs = (data['subtasks'] as List)
                                      .map((s) =>
                                          Map<String, dynamic>.from(s))
                                      .toList();
                                  final updated = subs
                                      .map((s) =>
                                          {...s, 'completedAt': ts}.cast<String, dynamic>())
                                      .toList();
                                  await ref.update({
                                    'completedAt': ts,
                                    'subtasks': updated,
                                  });
                                } else {
                                  await ref.update({'completedAt': ts});
                                }
                              },
                            ),
                            title: Text(t.text,
                                style: t.completedAt != null
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough)
                                    : null),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.category),
                                Text(
                                  t.dueAt != null
                                      ? 'Due: ${t.dueAt!.toLocal().toString().split('.')[0]}'
                                      : 'Due: N/A',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: Icon(Icons.circle,
                                size: 12,
                                color: [Colors.green, Colors.orange, Colors.red]
                                    [t.priority]),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => DetailScreen(todo: t)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // FAB
          ExpandableFab(
            onCalendarPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
            onTaskPressed: () =>
                setState(() => _isAddingTask = !_isAddingTask),
          ),
          // Task form overlay
          if (_isAddingTask)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: _buildTaskForm(),
            ),
        ],
      ),
    );
  }
}
