import 'package:flutter/material.dart';

class ExpandableFab extends StatefulWidget {
  final VoidCallback onCalendarPressed;
  final VoidCallback onTaskPressed;

  const ExpandableFab({
    super.key,
    required this.onCalendarPressed,
    required this.onTaskPressed,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isOnRight = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      left: 0,
      bottom: 0,
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        alignment: _isOnRight ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: _isOnRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _isExpanded ? 240 : 0,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: _isOnRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (_isExpanded) ...[
                        FloatingActionButton(
                          heroTag: "moveBtn",
                          onPressed: () => setState(() => _isOnRight = !_isOnRight),
                          child: Icon(_isOnRight ? Icons.arrow_back : Icons.arrow_forward),
                        ),
                        const SizedBox(height: 16),
                        FloatingActionButton(
                          heroTag: "taskBtn",
                          onPressed: () {
                            setState(() => _isExpanded = false);
                            widget.onTaskPressed();
                          },
                          child: const Icon(Icons.edit_note),
                        ),
                        const SizedBox(height: 16),
                        FloatingActionButton(
                          heroTag: "calendarBtn",
                          onPressed: () {
                            setState(() => _isExpanded = false);
                            widget.onCalendarPressed();
                          },
                          child: const Icon(Icons.calendar_month),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              FloatingActionButton(
                heroTag: "mainBtn",
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                    if (_isExpanded) {
                      _animationController.forward();
                    } else {
                      _animationController.reverse();
                    }
                  });
                },
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _isExpanded ? 0.125 : 0,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}