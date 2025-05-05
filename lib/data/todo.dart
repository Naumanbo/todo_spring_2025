import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String id;
  final String text;
  final String uid;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final GeoPoint? location;
  final String? locationName;
  final String category;
  final List<Subtask> subtasks;
  final int priority;

  Todo({
    required this.id,
    required this.text,
    required this.uid,
    required this.createdAt,
    required this.completedAt,
    required this.dueAt,
    required this.location,
    required this.locationName,
    required this.category,
    required this.subtasks,
    required this.priority,
  });

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'location': location,
      'locationName': locationName,
      'category': category,
      'subtasks': subtasks.map((subtask) => subtask.toSnapshot()).toList(),
      'priority': priority,
    };
  }

  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Todo(
      id: snapshot.id,
      text: data['text'],
      uid: data['uid'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      dueAt: data['dueAt'] != null ? (data['dueAt'] as Timestamp).toDate() : null,
      location: data['location'] != null ? data['location'] as GeoPoint : null,
      locationName: data['locationName'],
      category: data['category'] ?? 'None',
      subtasks: (data['subtasks'] as List<dynamic>? ?? [])
          .map((subtaskData) => Subtask.fromSnapshot(subtaskData as Map<String, dynamic>))
          .toList(),
      priority: data['priority'] ?? 0,
    );
  }
}

class Subtask {
  final String text;
  final DateTime? completedAt;

  Subtask({
    required this.text,
    required this.completedAt,
  });

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory Subtask.fromSnapshot(Map<String, dynamic> data) {
    return Subtask(
      text: data['text'],
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
    );
  }
}