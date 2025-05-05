import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onThemeChanged;

  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _themeOptions = [
    'Light Theme',
    'Dark Theme',
    'Gradient Theme 1',
    'Gradient Theme 2',
    'Gradient Theme 3',
  ];

  int _selectedThemeIndex = 0;
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  String _searchText = '';
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date',
    order: 'descending',
  );

  @override
  void dispose() {
    _controller.dispose();
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
                      Container(
                        color: Colors.green[100],
                        padding: const EdgeInsets.all(32.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: const InputDecoration(
                                  labelText: 'Enter Task:',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                if (user != null && _controller.text.isNotEmpty) {
                                  await FirebaseFirestore.instance.collection('todos').add({
                                    'text': _controller.text,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'uid': user.uid,
                                    'category': 'None',
                                    'dueAt': null,
                                    'location': null,
                                    'locationName': null,
                                    'priority': 0,
                                    'completedAt': null,
                                    'subtasks': [],
                                  });
                                  _controller.clear();
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ),
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
