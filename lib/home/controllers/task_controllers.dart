import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TaskController {
  final ValueNotifier<String> title;
  final ValueNotifier<String> category;
  final ValueNotifier<DateTime?> dueDate;
  final ValueNotifier<int> priority;
  final ValueNotifier<GeoPoint?> location;
  final ValueNotifier<String?> locationName;

  TaskController()
      : title = ValueNotifier(''),
        category = ValueNotifier('None'),
        dueDate = ValueNotifier(null),
        priority = ValueNotifier(0),
        location = ValueNotifier(null),
        locationName = ValueNotifier(null);

  void reset() {
    title.value = '';
    category.value = 'None';
    dueDate.value = null;
    priority.value = 0;
    location.value = null;
    locationName.value = null;
  }

  Map<String, dynamic> toJson() {
    return {
      'text': title.value,
      'category': category.value,
      'dueAt': dueDate.value != null ? Timestamp.fromDate(dueDate.value!) : null,
      'priority': priority.value,
      'location': location.value,
      'locationName': locationName.value,
      'completedAt': null,
      'subtasks': [],
    };
  }

  void dispose() {
    title.dispose();
    category.dispose();
    dueDate.dispose();
    priority.dispose();
    location.dispose();
    locationName.dispose();
  }
}