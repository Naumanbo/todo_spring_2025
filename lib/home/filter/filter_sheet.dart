import 'package:flutter/material.dart';

class FilterSheetResult {
  final String sortBy;
  final String order;

  FilterSheetResult({required this.sortBy, required this.order});
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    required this.initialFilters,
    super.key,
  });

  final FilterSheetResult initialFilters;

  @override
  _FilterSheetState createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String _sortBy = 'date';
  String _order = 'ascending';

  @override
  void initState() {
    _sortBy = widget.initialFilters.sortBy;
    _order = widget.initialFilters.order;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 32, right: 32, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'priority', child: Text('Priority')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value ?? _sortBy;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: _order,
                  items: const [
                    DropdownMenuItem(value: 'ascending', child: Text('Ascending')),
                    DropdownMenuItem(value: 'descending', child: Text('Descending')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _order = value ?? _order;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 200),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                FilterSheetResult(sortBy: _sortBy, order: _order),
              );
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
