import 'package:flutter/material.dart';
import '../../models/item.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Item>> _itemsFuture;
  List<Item> _items = [];
  String _filterStatus = 'all'; // all, pending, in-progress, completed

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _itemsFuture = ApiService.getItems().then((data) {
        final items = (data)
            .map((item) => Item.fromJson(item as Map<String, dynamic>))
            .toList();
        // Sort by due date, upcoming first
        items.sort((a, b) {
          if (a.dueDate != null && b.dueDate != null) {
            return a.dueDate!.compareTo(b.dueDate!);
          }
          return 0;
        });
        _items = items;
        return items;
      });
    });
  }

  void _logout() async {
    await ApiService.clearToken();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _deleteItem(String itemId) async {
    try {
      await ApiService.deleteItem(itemId);
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Critical Action Point deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<Item> _getFilteredItems() {
    if (_filterStatus == 'all') {
      return _items;
    }
    return _items.where((item) => item.status == _filterStatus).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[100]!;
      case 'in-progress':
        return Colors.blue[100]!;
      case 'completed':
        return Colors.green[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[900]!;
      case 'in-progress':
        return Colors.blue[900]!;
      case 'completed':
        return Colors.green[900]!;
      default:
        return Colors.grey[900]!;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    if (difference < 0) {
      return 'Overdue by ${-difference} days';
    } else if (difference == 0) {
      return 'Due today';
    } else if (difference == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in $difference days';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Action Plans'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterStatus == 'all',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'all');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending'),
                  selected: _filterStatus == 'pending',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'pending');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('In Progress'),
                  selected: _filterStatus == 'in-progress',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'in-progress');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed'),
                  selected: _filterStatus == 'completed',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'completed');
                  },
                ),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadItems(),
              child: FutureBuilder<List<Item>>(
                future: _itemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Error loading Critical Action Points'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadItems,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredItems = _getFilteredItems();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _filterStatus == 'all'
                                ? 'No Critical Action Points yet'
                                : 'No $_filterStatus CAPs',
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => const AddItemScreen(),
                                    ),
                                  )
                                  .then((_) => _loadItems());
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Critical Action Point'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isOverdue = item.isOverdue;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: _getStatusColor(item.status),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getStatusTextColor(item.status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.status[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (item.assignee != null)
                                Text(
                                  'Assigned to: ${item.assignee}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              Text(
                                _formatDate(item.dueDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOverdue ? Colors.red : Colors.grey[700],
                                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                onTap: () {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) => ItemDetailScreen(itemId: item.id),
                                        ),
                                      )
                                      .then((_) => _loadItems());
                                },
                                child: const Text('View/Edit'),
                              ),
                              PopupMenuItem(
                                onTap: () => _deleteItem(item.id),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => ItemDetailScreen(itemId: item.id),
                                  ),
                                )
                                .then((_) => _loadItems());
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (_) => const AddItemScreen()),
              )
              .then((_) => _loadItems());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
