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
  String category;
  final int priority;
  final List<Subtask> subtasks;

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
    required this.priority,
    required this.subtasks,
  });

  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Todo(
      id: snapshot.id,
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] != null && data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: (data['completedAt'] != null && data['completedAt'] is Timestamp)
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      dueAt: (data['dueAt'] != null && data['dueAt'] is Timestamp)
          ? (data['dueAt'] as Timestamp).toDate()
          : null,
      uid: data['uid'] ?? '',
      category: data['category'] ?? 'None',
      location: data['location'],
      locationName: data['locationName'],
      priority: data['priority'] ?? 0,
      subtasks: (data['subtasks'] as List<dynamic>? ?? [])
          .map((subtask) => Subtask.fromSnapshot(subtask as Map<String, dynamic>))
          .toList(),
    );
  }

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
      'priority': priority,
      'subtasks': subtasks.map((s) => s.toSnapshot()).toList(),
    };
  }
}

class Subtask {
  final String text;
  final DateTime? completedAt;

  Subtask({required this.text, this.completedAt});

  factory Subtask.fromSnapshot(Map<String, dynamic> data) {
    return Subtask(
      text: data['text'],
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }
}