import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map> _mergedLogs = [];
  bool _isLoading = true;
  DateTime? _selectedDate;
  String _selectedAction = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logBox = Hive.box('inventory_changes');
    final local = logBox.values.cast<Map>().toList();
    final api = await ApiService.getInventoryChanges();
    final seenIds = <String>{};
    final merged = <Map>[];
    for (final log in [...api, ...local]) {
      final id = (log['id'] ?? log['itemId'] ?? '').toString();
      final key = id.isEmpty ? '${log['date']}_${log['time']}_${log['itemName']}' : id;
      if (seenIds.contains(key)) continue;
      seenIds.add(key);
      merged.add(Map.from(log));
    }
    // Sort by date then time ascending (oldest first) so e.g. ADD then DELETE
    merged.sort((a, b) {
      final dateA = (a['date'] ?? a['date_str'] ?? '').toString();
      final dateB = (b['date'] ?? b['date_str'] ?? '').toString();
      final timeA = (a['time'] ?? a['time_str'] ?? '').toString();
      final timeB = (b['time'] ?? b['time_str'] ?? '').toString();
      final createdA = (a['created_at'] ?? '$dateA $timeA').toString();
      final createdB = (b['created_at'] ?? '$dateB $timeB').toString();
      final cmp = createdA.compareTo(createdB);
      if (cmp != 0) return cmp;
      if (dateA != dateB) return dateA.compareTo(dateB);
      return timeA.compareTo(timeB);
    });
    if (mounted) {
      setState(() {
        _mergedLogs = merged;
        _isLoading = false;
      });
    }
  }

  // Helper to determine the icon color based on the action
  Color _getActionColor(String action) {
    switch (action) {
      case 'ADD':
        return Colors.green;
      case 'EDIT':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper to determine the icon based on the action
  IconData _getActionIcon(String action) {
    switch (action) {
      case 'ADD':
        return Icons.add_circle;
      case 'EDIT':
        return Icons.edit;
      case 'DELETE':
        return Icons.remove_circle;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Change History'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadLogs();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                // Apply filters
                List<Map> filteredLogs = _mergedLogs;
                
                // Date filter
                if (_selectedDate != null) {
                  final selectedDateStr = DateFormat('dd MMM yyyy').format(_selectedDate!);
                  filteredLogs = filteredLogs.where((log) {
                    final logDate = (log['date'] ?? '').toString();
                    return logDate == selectedDateStr;
                  }).toList();
                }
                
                // Action filter
                if (_selectedAction != 'ALL') {
                  filteredLogs = filteredLogs.where((log) {
                    final action = (log['action'] ?? '').toString().toUpperCase();
                    return action == _selectedAction.toUpperCase();
                  }).toList();
                }

                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Text(
                      _mergedLogs.isEmpty
                          ? 'No inventory changes recorded yet.'
                          : 'No changes match the selected filters.',
                    ),
                  );
                }

                // Group logs by date for display
                final Map<String, List<Map>> groupedLogs = {};
                for (var log in filteredLogs) {
                  final date = (log['date'] ?? '').toString();
                  if (!groupedLogs.containsKey(date)) {
                    groupedLogs[date] = [];
                  }
                  groupedLogs[date]!.add(log);
                }

                final sortedDates = groupedLogs.keys.toList();

                return Column(
                  children: [
                    // Filter bar
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: [
                          // Date filter
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedDate == null
                                            ? 'All Dates'
                                            : DateFormat('dd MMM yyyy').format(_selectedDate!),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    if (_selectedDate != null)
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setState(() => _selectedDate = null),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Action filter
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedAction,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'ALL', child: Text('All Actions')),
                                DropdownMenuItem(value: 'ADD', child: Text('Adds')),
                                DropdownMenuItem(value: 'EDIT', child: Text('Edits')),
                                DropdownMenuItem(value: 'DELETE', child: Text('Deletes')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedAction = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Logs list
                    Expanded(
                      child: ListView.builder(
                  itemCount: sortedDates.length,
                  itemBuilder: (context, dateIndex) {
                    final date = sortedDates[dateIndex];
                    final logsForDate = groupedLogs[date]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...logsForDate.map((log) {
                          final action = (log['action'] ?? '').toString();
                          final itemName = (log['itemName'] ?? '').toString();
                          final details = (log['details'] ?? '').toString();
                          final time = (log['time'] ?? '').toString();

                          return ListTile(
                            leading: Icon(
                              _getActionIcon(action),
                              color: _getActionColor(action),
                            ),
                            title: Text(
                              '$action: $itemName',
                              style: TextStyle(fontWeight: FontWeight.bold, color: _getActionColor(action)),
                            ),
                            subtitle: Text(details),
                            trailing: Text(
                              time,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        const Divider(indent: 16, endIndent: 16),
                      ],
                    );
                      },
                    ),
                  ),
                ],
              );
              },
            ),
    );
  }
}