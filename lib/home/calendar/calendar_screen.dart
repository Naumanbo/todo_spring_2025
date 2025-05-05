import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../details/detail_screen.dart';
import '../../data/todo.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentWeek = DateTime.now();

  List<DateTime> _getDaysInWeek() {
    final DateTime startOfWeek = _currentWeek.subtract(
      Duration(days: _currentWeek.weekday - 1),
    );
    return List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );
  }

  Widget _buildDayColumn(DateTime date) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('todos')
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Expanded(
            child: Column(
              children: [
                _buildDateHeader(date),
                const Expanded(
                  child: Center(child: Text('Error loading tasks')),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return Expanded(
            child: Column(
              children: [
                _buildDateHeader(date),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          );
        }

        // Filter tasks for this day
        final todos = snapshot.data!.docs
            .map((doc) => Todo.fromSnapshot(doc))
            .where((todo) {
              if (todo.dueAt == null) return false;
              final todoDate = DateTime(
                todo.dueAt!.year,
                todo.dueAt!.month,
                todo.dueAt!.day,
              );
              final compareDate = DateTime(
                date.year,
                date.month,
                date.day,
              );
              return todoDate.isAtSameMomentAs(compareDate);
            })
            .toList();

        return Expanded(
          child: Column(
            children: [
              _buildDateHeader(date),
              Expanded(
                child: todos.isEmpty
                    ? const Center(
                        child: Text(
                          'No tasks',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: todos.length,
                        itemBuilder: (context, index) {
                          final todo = todos[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    todo.text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      decoration: todo.completedAt != null
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (todo.dueAt != null)
                                    Text(
                                      todo.dueAt!.hour.toString().padLeft(2, '0') + 
                                      ':' + 
                                      todo.dueAt!.minute.toString().padLeft(2, '0'),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isToday ? Theme.of(context).primaryColor.withOpacity(0.2) : null,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(date.day.toString()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInWeek = _getDaysInWeek();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar View'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _currentWeek = _currentWeek.subtract(const Duration(days: 7));
                    });
                  },
                ),
                Text(
                  '${daysInWeek.first.day} - ${daysInWeek.last.day} ${daysInWeek.first.month}/${daysInWeek.first.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    setState(() {
                      _currentWeek = _currentWeek.add(const Duration(days: 7));
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: daysInWeek.map((date) => _buildDayColumn(date)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}