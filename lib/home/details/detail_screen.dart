import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../../data/todo.dart';
import 'location_picker_screen.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const List<String> defaultCategories = ['None', 'Home', 'Work', 'School'];

class DetailScreen extends StatefulWidget {
  final Todo todo;

  const DetailScreen({super.key, required this.todo});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _textController;
  late int _priority;
  DateTime? _selectedDueDate;
  GeoPoint? _selectedLocation;
  String? _selectedLocationName;
  StreamSubscription<DocumentSnapshot>? _todoSubscription;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo.text);
    _selectedDueDate = widget.todo.dueAt;
    _priority = widget.todo.priority;
    _selectedLocation = widget.todo.location;
    _selectedLocationName = widget.todo.locationName;
    
    // Add real-time listener
    _todoSubscription = FirebaseFirestore.instance
        .collection('todos')
        .doc(widget.todo.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _textController.text = data['text'] ?? '';
          _selectedDueDate = (data['dueAt'] as Timestamp?)?.toDate();
          _priority = data['priority'] ?? 0;
          _selectedLocation = data['location'] as GeoPoint?;
          _selectedLocationName = data['locationName'];
        });
      }
    });
  }

  @override
  void dispose() {
    _todoSubscription?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _updateLocation(GeoPoint? newLocation, String? locationName) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({
        'location': newLocation != null
            ? GeoPoint(newLocation.latitude, newLocation.longitude)
            : null,
        'locationName': locationName, // Update locationName
      });
      setState(() {
        _selectedLocation = newLocation;
        _selectedLocationName = locationName;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update location: $e')),
        );
      }
    }
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

      final newLocation = GeoPoint(pickedLocation.latitude, pickedLocation.longitude);
      await _updateLocation(newLocation, locationName);

      setState(() {
        _selectedLocation = newLocation;
        _selectedLocationName = locationName ?? 'Lat: ${pickedLocation.latitude}, Lng: ${pickedLocation.longitude}';
      });
    }
  }

  Future<void> _updatePriority(int newPriority) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'priority': newPriority});
      setState(() {
        _priority = newPriority; // Update local state
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update priority: $e')),
        );
      }
    }
  }

  Future<List<String>> fetchCategories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('categories').get();
    final customCategories =
        snapshot.docs.map((doc) => doc['name'] as String).toList();
    return [...defaultCategories, ...customCategories];
  }

  Future<void> addCategory(String categoryName) async {
    await FirebaseFirestore.instance
        .collection('categories')
        .add({'name': categoryName});
  }

  Future<void> deleteCategory(String categoryName) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('name', isEqualTo: categoryName)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _removeCategory(String categoryName) async {
    await deleteCategory(categoryName);

    // Update all todos using the removed category to "None"
    final todosSnapshot = await FirebaseFirestore.instance
        .collection('todos')
        .where('category', isEqualTo: categoryName)
        .get();

    for (final doc in todosSnapshot.docs) {
      await doc.reference.update({'category': 'None'});
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "$categoryName" removed!')),
      );
    }
  }

  Future<void> _delete() async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Todo deleted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete todo: $e')),
        );
      }
    }
  }

  Future<void> _updateText(String newText) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'text': newText});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<void> _updateDueDate(DateTime? newDueDate) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({
        'dueAt': newDueDate == null ? null : Timestamp.fromDate(newDueDate)
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<void> _updateCategory(String newCategory) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'category': newCategory});
      setState(() {
        widget.todo.category = newCategory;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<bool> _requestNotificationPermission() async {
    final isGranted = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false;
    return isGranted;
  }

  void _showPermissionDeniedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You need to enable notifications to set due date.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Open Settings',
          textColor: Colors.white,
          onPressed: () {
            AppSettings.openAppSettings(
              type: AppSettingsType.notification,
            );
          },
        ),
      ),
    );
  }

  Future<void> _initializeNotifications() async {
    final initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> _scheduleNotification(
    String todoId,
    DateTime dueDate,
    String text,
  ) async {
    final tzDateTime = tz.TZDateTime.from(dueDate, tz.local);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      todoId.hashCode,
      'Task due',
      text,
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Widget _buildSubtasksList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox();

        final subtasks = (data['subtasks'] as List<dynamic>? ?? [])
            .map((s) => Subtask.fromSnapshot(s as Map<String, dynamic>))
            .toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddSubtaskDialog(subtasks),
                ),
              ],
            ),
            Column(
              children: List.generate(
                subtasks.length,
                (index) {
                  final subtask = subtasks[index];
                  final completedAt = subtask.completedAt;
                  return Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: completedAt != null,
                          onChanged: (bool? value) {
                            final updatedSubtasks = List<Subtask>.from(subtasks);
                            updatedSubtasks[index] = Subtask(
                              text: subtask.text,
                              completedAt: value == true ? DateTime.now() : null,
                            );
                            FirebaseFirestore.instance
                                .collection('todos')
                                .doc(widget.todo.id)
                                .update({'subtasks': updatedSubtasks.map((s) => s.toSnapshot()).toList()});
                          },
                          title: Text(
                            subtask.text,
                            style: completedAt != null
                                ? const TextStyle(decoration: TextDecoration.lineThrough)
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          final updatedSubtasks = List<Subtask>.from(subtasks)..removeAt(index);
                          FirebaseFirestore.instance
                              .collection('todos')
                              .doc(widget.todo.id)
                              .update({'subtasks': updatedSubtasks.map((s) => s.toSnapshot()).toList()});
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddSubtaskDialog(List<Subtask> currentSubtasks) async {
    if (currentSubtasks.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot add more than 10 subtasks to a task.'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final TextEditingController controller = TextEditingController();
    
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Subtask',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Subtask',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        if (controller.text.isNotEmpty) {
                          final updatedSubtasks = List<Subtask>.from(currentSubtasks)
                            ..add(Subtask(text: controller.text.trim(), completedAt: null));
                          
                          await FirebaseFirestore.instance
                              .collection('todos')
                              .doc(widget.todo.id)
                              .update({'subtasks': updatedSubtasks.map((s) => s.toSnapshot()).toList()});
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Todo'),
                  content:
                      const Text('Are you sure you want to delete this todo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _delete();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                ),
                onSubmitted: (newText) async {
                  if (newText.isNotEmpty && newText != widget.todo.text) {
                    await _updateText(newText);
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Due Date'),
                subtitle: Text(
                    _selectedDueDate?.toLocal().toString().split('.')[0] ??
                        'No due date'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedDueDate != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          _updateDueDate(null);
                          setState(() {
                            _selectedDueDate = null;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final isGranted = await _requestNotificationPermission();
                        if (!context.mounted) return;

                        if (!isGranted) {
                          _showPermissionDeniedSnackbar(context);
                          return;
                        }

                        await _initializeNotifications();
                        if (!context.mounted) return;

                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDueDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2050),
                        );
                        if (!context.mounted) return;
                        if (selectedDate == null) return;

                        final selectedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedDueDate != null
                              ? TimeOfDay.fromDateTime(_selectedDueDate!)
                              : TimeOfDay.now(),
                        );
                        if (selectedTime == null) return;

                        final DateTime dueDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        setState(() {
                          _selectedDueDate = dueDate;
                        });

                        await _updateDueDate(dueDate);
                        await _scheduleNotification(
                          widget.todo.id,
                          dueDate,
                          widget.todo.text,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Category'),
                subtitle: Text(widget.todo.category),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final categories = await fetchCategories();
                    String? selectedCategory = widget.todo.category;
                    await showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (context, setState) {
                            final TextEditingController newCategoryController =
                                TextEditingController();
                            return AlertDialog(
                              title: const Text('Edit Category'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButton<String>(
                                          value: selectedCategory,
                                          isExpanded: true,
                                          items: categories.map((category) {
                                            return DropdownMenuItem(
                                              value: category,
                                              child: Text(category),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setState(() {
                                              selectedCategory = value;
                                            });
                                          },
                                        ),
                                      ),
                                      if (selectedCategory != null &&
                                          !defaultCategories
                                              .contains(selectedCategory))
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title:
                                                    const Text('Delete Category'),
                                                content: Text(
                                                    'Are you sure you want to delete "$selectedCategory"?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true &&
                                                selectedCategory != null) {
                                              await _removeCategory(
                                                  selectedCategory!);
                                              setState(() {
                                                categories
                                                    .remove(selectedCategory);
                                                selectedCategory =
                                                    categories.isNotEmpty
                                                        ? categories.first
                                                        : null;
                                              });
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: newCategoryController,
                                          decoration: const InputDecoration(
                                            labelText: 'New Custom Category',
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () async {
                                          final newCat =
                                              newCategoryController.text.trim();
                                          if (newCat.isNotEmpty &&
                                              !categories.contains(newCat)) {
                                            await addCategory(newCat);
                                            setState(() {
                                              categories.add(newCat);
                                              selectedCategory = newCat;
                                              newCategoryController.clear();
                                            });
                                          }
                                        },
                                      ),
                                    ],
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
                                    if (selectedCategory != null) {
                                      await _updateCategory(selectedCategory!);
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              ListTile(
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
                  onPressed: () async {
                    int? selectedPriority = _priority;
                    await showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return AlertDialog(
                              title: const Text('Edit Priority'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RadioListTile<int>(
                                    value: 0,
                                    groupValue: selectedPriority,
                                    title: const Text('Low'),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedPriority = value;
                                      });
                                    },
                                  ),
                                  RadioListTile<int>(
                                    value: 1,
                                    groupValue: selectedPriority,
                                    title: const Text('Medium'),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedPriority = value;
                                      });
                                    },
                                  ),
                                  RadioListTile<int>(
                                    value: 2,
                                    groupValue: selectedPriority,
                                    title: const Text('High'),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedPriority = value;
                                      });
                                    },
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
                                    if (selectedPriority != null) {
                                      await _updatePriority(selectedPriority!);
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              ListTile(
                title: const Text('Location'),
                subtitle: Text(_selectedLocationName ??
                    (_selectedLocation != null
                        ? 'Lat: ${_selectedLocation!.latitude}, Lng: ${_selectedLocation!.longitude}'
                        : 'No location')),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _pickLocation,
                ),
              ),
              const SizedBox(height: 16),
              _buildSubtasksList(),
            ],
          ),
        ),
      ),
    );
  }
}
