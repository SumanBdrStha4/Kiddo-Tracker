class RouteInfo {
  final String routeId;
  final String routeName;
  final int routeType;
  final String startTime;
  final String stopArrivalTime;
  final String stopName;
  final String stopLocation;
  final String schoolLocation;
  final int oprId;
  final String vehicleId;
  final int stopId;

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
      routeType: int.parse(json['type'] ?? '0'),
      startTime: json['start_time'] ?? '',
      stopArrivalTime: json['stop_arrival_time'] ?? '',
      stopName: json['stop_name'] ?? '',
      stopLocation: json['location'] ?? '',
      schoolLocation: json['school_location'] ?? '',
      oprId: int.parse(json['oprid'] ?? '0'),
      vehicleId: json['vehicle_id'] ?? '',
      stopId: int.parse(json['stop_id'] ?? '0'),
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

  @override
  String toString() {
    return toJson().toString();
  }
}
