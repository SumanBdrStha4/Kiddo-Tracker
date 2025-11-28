import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../widget/sqflitehelper.dart';

class ChangedActivity extends StatefulWidget {
  final Function(int)? onNewMessage;

  const ChangedActivity({super.key, this.onNewMessage});

  @override
  State<ChangedActivity> createState() => _ChangedActivityState();
}

class _ChangedActivityState extends State<ChangedActivity> {
  late List<ActivityItem> activities = [];
  bool _isLoading = true;
  final SqfliteHelper _sqfliteHelper = SqfliteHelper();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    //fetch from _sqfliteHelper getNotifications
    setState(() {
      _isLoading = true;
    });
    final data = await _sqfliteHelper.getNotifications();
    setState(() {
      activities = data
          .where((item) => item['id'] != null)
          .map(
            (item) => ActivityItem(
              id: item['id'] as int,
              title: item['title'] as String? ?? '',
              description: item['description'] as String? ?? '',
              isRead: item['is_read'] as int? ?? -1,
              timestamp: item['timestamp'] != null
                  ? DateTime.parse(item['timestamp'] as String)
                  : DateTime.now(),
            ),
          )
          .toList();
      _isLoading = false;
    });
  }

  void _markAsRead(ActivityItem item) async {
    setState(() {
      item.isRead = 1;
    });
    await _sqfliteHelper.updateNotificationIsRead(item.id, 1);
    // also update the count from total notifications by read ones
    final int totalNotifications =
        await _sqfliteHelper.getUnreadNotificationCount();
    widget.onNewMessage?.call(totalNotifications);
  }

  void _showDetails(ActivityItem item) {
    _markAsRead(item);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              item.isRead == 1 ? Icons.check_circle : Icons.circle_outlined,
              color: item.isRead == 1 ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(item.timestamp),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(useMaterial3: true),
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _fetchData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : activities.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final item = activities[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child:
                          Card(
                                elevation: item.isRead == 1 ? 1 : 3,
                                shadowColor: item.isRead == 1
                                    ? Colors.transparent
                                    : Theme.of(context).colorScheme.shadow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _showDetails(item),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: item.isRead == 1
                                                ? Colors.green.shade50
                                                : Colors.blue.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            item.isRead == 1
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            color: item.isRead == 1
                                                ? Colors.green
                                                : Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          item.isRead != 1
                                                          ? FontWeight.bold
                                                          : FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.description,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'MMM dd, hh:mm a',
                                          ).format(item.timestamp),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .animate()
                              .fade(duration: 300.ms)
                              .slide(
                                begin: const Offset(0, 0.1),
                                duration: 300.ms,
                              ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No activities yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Activities will appear here when available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ActivityItem {
  final int id;
  final String title;
  final String description;
  int isRead;
  final DateTime timestamp;

  ActivityItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isRead,
    required this.timestamp,
  });
}
