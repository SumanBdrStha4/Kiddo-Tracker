import 'package:kiddo_tracker/model/routelist.dart';

class RouteSearchCallback {
  List<RouteList> routeList;
  Set<String> uniqueRouteIds;
  Map<String, List<String>> routeTimingsMap;
  int reqStatus;
  List<Map<String, String?>> stops = [];

  RouteSearchCallback()
    : routeList = [],
      uniqueRouteIds = {},
      routeTimingsMap = {},
      reqStatus = 0;

  Future<void> call(dynamic response) async {
    if (response == null || response is! List || response.length < 2) {
      reqStatus = -1;
      return;
    }

    try {
      if (response[0]['result'] != 'ok') {
        reqStatus = -1;
        return;
      }

      var data = response[1]['data'];
      if (data is! List) {
        reqStatus = -1;
        return;
      }

      routeList.clear();
      uniqueRouteIds.clear();
      routeTimingsMap.clear();

      for (var item in data) {
        RouteList route = RouteList.fromJson(item);
        routeList.add(route);
        uniqueRouteIds.add(route.routeId);
        routeTimingsMap.putIfAbsent(route.routeId, () => []).add(route.timing);
      }

      reqStatus = 1;
    } catch (e) {
      reqStatus = -1;
      print('Error parsing route list response: $e');
    }
  }

  int getStatus() {
    return reqStatus;
  }

  List<String> getUniqueRouteNames() {
    return uniqueRouteIds.toList();
  }

  // Return a list of route names
  List<String> getRouteNames() {
    List<String> routeNames = [];
    for (RouteList route in routeList) {
      //check the exits routeName and type in routeNames list
      if (routeNames.contains(
        "${route.routeName ?? route.routeId} ${route.type == 1 ? "OnWard" : "Return"}",
      )) {
        continue;
      }
      String type = route.type == 1 ? "OnWard" : "Return";
      routeNames.add("${route.routeName ?? route.routeId} $type");
    }
    return routeNames;
  }

  Map<String, List<String>> getRouteTimingsMap() {
    return routeTimingsMap;
  }

  // Return the oprId for a given timing
  int getOprIdbyTiming(String timing, String routeId) {
    for (RouteList route in routeList) {
      if (route.timing == timing && route.routeId == routeId) {
        return route.oprid;
      }
    }
    return 0;
  }

  // Return a list of timings for a given route
  List<String> getRouteTimings(String? routeId, int? type) {
    // Filter timings based on routeId and type
    List<String> timings = [];
    for (RouteList route in routeList) {
      if (route.routeId == routeId && route.type == type) {
        timings.add(route.timing);
      }
    }
    return timings;
  }

  //Return a list of stop_details for a given route
  // List<Map<String, String?>> getStopList(List<StopListItem>? stopList) {
  //   List<Map<String, String?>> stops = [];
  //   if (stopList != null) {
  //     for (var stop in stopList) {
  //       stops.add({
  //         'key': stop.stopId,
  //         'value': stop.stopName,
  //         'location': stop.location,
  //       });

  //     }
  //   }
  //   return stops;
  // }

  // Return the vehicleId for a given timing and routeId
  getVehicleIdbyTiming(String timing, String routeId) {
    for (RouteList route in routeList) {
      if (route.timing == timing && route.routeId == routeId) {
        return route.vehicleId;
      }
    }
    return 0;
  }

  List<Map<String, String?>> getStopList(String s) {
    stops = [];
    for (RouteList route in routeList) {
      if (route.routeId == s) {
        for (var stop in route.stopList ?? []) {
          stops.add({
            'key': stop.stopId,
            'value': stop.stopName,
            'location': stop.location,
          });
        }
        break;
      }
    }
    return stops;
  }

  // get time based on oprid and return timing information for all stops in the route
  List<String> getRouteTimesbyOprId(int oprid) {
    List<String> times = [];
    // Find the route with the matching oprid
    for (RouteList route in routeList) {
      if (route.oprid == oprid) {
        if (route.stopDetails != null && route.stopDetails!.isNotEmpty) {
          // Get the stop list for this route to check against
          getStopList(route.routeId);
          List<String> stopNames = stops.map((e) => e['value']!).toList();
          for (var stopDetail in route.stopDetails!) {
            if (stopDetail.arrival.isNotEmpty &&
                stopDetail.departure.isNotEmpty) {
              // Check if stopDetail.stopName matches with getStopList stops['value']
              if (stopNames.contains(stopDetail.stopName)) {
                times.add(
                  '${stopDetail.stopName}, Arrival: ${stopDetail.arrival}, Departure: ${stopDetail.departure}',
                );
              }
            }
          }
        }
      }
    }
    return times;
  }
}
