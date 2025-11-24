class RouteInfo {
  final String routeId;
  final String routeName;
  final int routeType;
  final String startTime;
  final String stopArrivalTime;
  final String stopName;
  final String stopLocation;
  final String schoolLocation;
  final String oprId;
  final String vehicleId;
  final String stopId;

  RouteInfo({
    required this.routeId,
    required this.routeName,
    required this.routeType,
    required this.startTime,
    required this.stopArrivalTime,
    required this.stopName,
    required this.stopLocation,
    required this.schoolLocation,
    required this.oprId,
    required this.vehicleId,
    required this.stopId,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      routeId: json['route_id'] ?? '',
      routeName: json['route_name'] ?? '',
      routeType: json['route_type'] ?? 0,
      startTime: json['start_time'] ?? '',
      stopArrivalTime: json['stop_arrival_time'] ?? '',
      stopName: json['stop_name'] ?? '',
      stopLocation: json['location'] ?? '',
      schoolLocation: json['school_location'] ?? '',
      oprId: json['oprid'] ?? '',
      vehicleId: json['vehicle_id'] ?? '',
      stopId: json['stop_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'route_name': routeName,
      'route_type': routeType,
      'oprid': oprId,
      'vehicle_id': vehicleId,
      'stop_id': stopId,
      'stop_name': stopName,
      'start_time': startTime,
      'stop_arrival_time': stopArrivalTime,
      'location': stopLocation,
      'school_location': schoolLocation,
    };
  }
}
