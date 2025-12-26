import 'package:flutter/material.dart';
import 'package:kiddo_tracker/widget/sqflitehelper.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:kiddo_tracker/services/children_provider.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // This list will hold all activities from the database
  List<Map<String, dynamic>> activities = [];
  // Grouped activities by date
  Map<String, List<Map<String, dynamic>>> groupedActivities = {};
  bool isLoading = true;

  //also show the topic that MQTT subscribed to
  List<String> topics = [];

  // Fetch activities from the database
  Future<void> _fetchActivities() async {
    try {
      final fetchedActivities = await SqfliteHelper().getActivities();

      // Group activities by date (yyyy-MM-dd)
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var activity in fetchedActivities) {
        String createdAt = activity['created_at'] ?? '';
        String dateKey;
        try {
          DateTime dt = DateTime.parse(createdAt);
          dateKey = DateFormat('yyyy-MM-dd').format(dt);
        } catch (e) {
          dateKey = 'Unknown Date';
        }
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(activity);
      }

      setState(() {
        activities = fetchedActivities;
        groupedActivities = grouped;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Handle error - could show a snackbar or dialog
      print('Error fetching activities: $e');
    }
  }

  // Helper method to get status icon
  Icon _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'onboarded':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'offboarded':
        return const Icon(Icons.home, color: Colors.blue);
      default:
        return const Icon(Icons.access_time, color: Colors.grey);
    }
  }

  // Helper method to get card color
  Color _getCardColor(String status) {
    switch (status.toLowerCase()) {
      case 'picked up':
        return Colors.green.shade50;
      case 'dropped off':
        return Colors.blue.shade50;
      default:
        return Colors.white;
    }
  }

  // Helper method to format time
  String _formatTime(String createdAt) {
    try {
      DateTime dt = DateTime.parse(createdAt);
      return DateFormat('MMM dd, yyyy at hh:mm a').format(dt);
    } catch (e) {
      return createdAt;
    }
  }

  // Helper method to get address from lat,long
  Future<String> _getAddress(
    String onLocation,
    String offLocation,
    String status,
  ) async {
    String location = status == 'onboarded' ? onLocation : offLocation;
    try {
      List<String> parts = location.split(',');
      if (parts.length == 2) {
        double lat = double.parse(parts[0].trim());
        double long = double.parse(parts[1].trim());
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          return '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'
              .trim();
        }
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return location; // fallback to original
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChildrenProvider>(context, listen: false);
      setState(() {
        topics = provider.mqttService?.subscribedTopics ?? [];
      });
    });
    _fetchActivities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activities.isEmpty
          ? const Center(child: Text('No activities found.'))
          : RefreshIndicator(
              onRefresh: _fetchActivities,
              child: ListView(
                children: () {
                  List<Widget> listItems = [];

                  // Add topics section if topics are available
                  if (topics.isNotEmpty) {
                    listItems.add(
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Subscribed MQTT Topics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    );
                    listItems.add(
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                    );
                    listItems.addAll(
                      topics.map(
                        (topic) => Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.message,
                              color: Colors.blue,
                            ),
                            title: Text(topic),
                            subtitle: const Text('MQTT Topic'),
                          ),
                        ),
                      ),
                    );
                    listItems.add(
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                    );
                  }

                  // Add activities
                  List<String> sortedKeys = groupedActivities.keys.toList()
                    ..sort((a, b) => b.compareTo(a)); // descending date order
                  listItems.addAll(
                    sortedKeys.map((dateKey) {
                      DateTime? date;
                      try {
                        date = DateFormat('yyyy-MM-dd').parse(dateKey);
                      } catch (_) {
                        date = null;
                      }
                      String formattedDate = date != null
                          ? DateFormat('MMMM dd, yyyy').format(date)
                          : dateKey;

                      List<Widget> dateSection = [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ];

                      dateSection.addAll(
                        groupedActivities[dateKey]!.map((activity) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: _getStatusIcon(activity['status'] ?? ''),
                              title: Text(
                                '${activity['student_name'] ?? 'Unknown'} - ${activity['status'] ?? 'No status'}',
                              ),
                              subtitle: FutureBuilder<String>(
                                future: _getAddress(
                                  activity['on_location'],
                                  activity['off_location'],
                                  activity['status'],
                                ),
                                builder: (context, snapshot) {
                                  String address = snapshot.data ?? '';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(address)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.route, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Route: ${activity['route_id'] ?? 'N/A'}',
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.person, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Operator: ${activity['oprid'] ?? 'N/A'}',
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Created: ${_formatTime(activity['created_at'] ?? '')}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                              isThreeLine: true,
                              tileColor: _getCardColor(
                                activity['status'] ?? '',
                              ),
                            ),
                          );
                        }),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: dateSection,
                      );
                    }).toList(),
                  );
                  return listItems;
                }(),
              ),
            ),
    );
  }
}
