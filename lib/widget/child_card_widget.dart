import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiddo_tracker/model/child.dart';
import 'package:kiddo_tracker/model/subscribe.dart';
import 'package:kiddo_tracker/widget/route_card_widget.dart';
import 'package:kiddo_tracker/model/route.dart';

class ChildCardWidget extends StatefulWidget {
  final Child child;
  final SubscriptionPlan? subscription;
  final VoidCallback? onSubscribeTap;
  final VoidCallback? onAddRouteTap;
  final Function(String routeId, List<RouteInfo> routes)? onBusTap;
  final Function(String routeId, List<RouteInfo> routes)? onLocationTap;
  final Function(String routeId, List<RouteInfo> routes)? onDeleteTap;
  final Function(String routeId, List<RouteInfo> routes)? onOnboardTap;
  final Function(String routeId, List<RouteInfo> routes)? onOffboardTap;
  final Map<String, bool> activeRoutes;
  final int boardRefreshKey;

  const ChildCardWidget({
    super.key,
    required this.child,
    this.subscription,
    this.onSubscribeTap,
    this.onAddRouteTap,
    required this.onBusTap,
    required this.onLocationTap,
    required this.onDeleteTap,
    this.onOnboardTap,
    this.onOffboardTap,
    required this.activeRoutes,
    required this.boardRefreshKey,
  });

  @override
  State<ChildCardWidget> createState() => _ChildCardWidgetState();
}

class _ChildCardWidgetState extends State<ChildCardWidget> {
  String _statusText(int status) {
    switch (status) {
      case 1:
        return 'Onboard';
      case 2:
        return 'Offboard';
      default:
        return 'Offboard';
    }
  }

  Map<String, List<RouteInfo>> _groupRoutesByRouteId(List<RouteInfo> routes) {
    Map<String, List<RouteInfo>> grouped = {};
    for (var route in routes) {
      if (!grouped.containsKey(route.routeId)) {
        grouped[route.routeId] = [];
      }
      grouped[route.routeId]!.add(route);
    }
    return grouped;
  }

  String _getInitials(String name) {
    List<String> names = name.split(' ');
    String initials = '';
    for (var part in names) {
      if (part.isNotEmpty) {
        initials += part[0].toUpperCase();
      }
    }
    return initials;
  }

  Widget _buildStatusWidget() {
    Icon statusIcon;
    Color statusColor;
    if (widget.child.onboard_status == 1) {
      statusIcon = const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 20,
      );
      statusColor = Colors.green;
    } else {
      statusIcon = const Icon(Icons.cancel, color: Colors.red, size: 20);
      statusColor = Colors.red;
    }
    return Row(
      children: [
        statusIcon,
        const SizedBox(width: 6),
        Text(
          _statusText(widget.child.onboard_status),
          style: TextStyle(
            color: statusColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionWidget() {
    if (widget.subscription == null) {
      return GestureDetector(
        onTap: widget.onSubscribeTap,
        child: const Text(
          "Subscribe",
          style: TextStyle(
            color: Colors.blue,
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    } else {
      bool isExpired = DateTime.parse(
        widget.subscription!.enddate,
      ).isBefore(DateTime.now());
      if (widget.subscription!.student_id != widget.child.studentId) {
        return GestureDetector(
          onTap: widget.onSubscribeTap,
          child: const Text(
            "Subscribe",
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else if (isExpired) {
        return GestureDetector(
          onTap: widget.onSubscribeTap,
          child: const Text(
            "Add New Plan",
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else {
        // For active subscription, just show a green check icon without text
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedRoutes = _groupRoutesByRouteId(widget.child.routeInfo);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Avatar, Name, School
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade300,
                  child: Text(
                    _getInitials(widget.child.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.child.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.child.school,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.child.status == 1 ||
                    widget.subscription != null &&
                        widget.subscription!.student_id ==
                            widget.child.studentId)
                  _buildStatusWidget()
                else
                  _buildSubscriptionWidget(),
              ],
            ),
            const SizedBox(height: 12),
            // Route cards
            Column(
              children: groupedRoutes.entries.map((entry) {
                final routeId = entry.key;
                final routes = entry.value;
                //print the routeId and routes for debugging
                return RouteCardWidget(
                  childId: widget.child.studentId,
                  routeId: routeId,
                  routes: routes,
                  onBusTap: widget.onBusTap,
                  onLocationTap: widget.onLocationTap,
                  onDeleteTap: widget.onDeleteTap,
                  onOnboardTap: widget.onOnboardTap,
                  onOffboardTap: widget.onOffboardTap,
                  boardRefreshKey: widget.boardRefreshKey,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Add Route button
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: widget.onAddRouteTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Add Route',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 600.ms).slide(begin: const Offset(0, 0.1));
  }
}
