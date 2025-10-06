import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class StopLocation {
  final String stopId;
  final String stopName;
  final String location;
  final int stopType;

  StopLocation({
    required this.stopId,
    required this.stopName,
    required this.location,
    required this.stopType,
  });

  factory StopLocation.fromJson(Map<String, dynamic> json) {
    return StopLocation(
      stopId: json['stop_id'] ?? '',
      stopName: json['stop_name'] ?? '',
      location: json['location'] ?? '',
      stopType: json['stop_type'] ?? 0,
    );
  }

  LatLng get latLng {
    final parts = location.split(',');
    if (parts.length >= 2) {
      return LatLng(
        double.tryParse(parts[0]) ?? 0.0,
        double.tryParse(parts[1]) ?? 0.0,
      );
    }
    return const LatLng(0.0, 0.0);
  }
}

class StopLocationsDialog extends StatefulWidget {
  final List<StopLocation> stopLocations;
  final String routeName;

  const StopLocationsDialog({
    super.key,
    required this.stopLocations,
    required this.routeName,
  });

  @override
  State<StopLocationsDialog> createState() => _StopLocationsDialogState();
}

class _StopLocationsDialogState extends State<StopLocationsDialog> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  StopLocation? _selectedStop;
  bool _isMapLoading = true;
  String? _mapError;

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  void _createMarkers() {
    _markers = widget.stopLocations.map((stop) {
      final latLng = stop.latLng;
      return Marker(
        markerId: MarkerId(stop.stopId),
        position: latLng,
        infoWindow: InfoWindow(
          title: stop.stopName,
          snippet: 'Stop ID: ${stop.stopId}',
        ),
        onTap: () {
          setState(() {
            _selectedStop = stop;
          });
          _mapController.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        },
      );
    }).toSet();
  }

  Future<void> _openInGoogleMaps(StopLocation stop) async {
    final latLng = stop.latLng;
    final url = 'https://www.google.com/maps/search/?api=1&query=${latLng.latitude},${latLng.longitude}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Google Maps for ${stop.stopName}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Route Stops - ${widget.routeName}'),
      content: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Google Maps Widget with error handling
            SizedBox(
              height: 300,
              width: double.infinity,
              child: _isMapLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading map...'),
                        ],
                      ),
                    )
                  : _mapError != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Map Error',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _mapError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isMapLoading = true;
                                    _mapError = null;
                                  });
                                },
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: widget.stopLocations.isNotEmpty
                                ? widget.stopLocations.first.latLng
                                : const LatLng(20.272470745, 85.783748278),
                            zoom: 13,
                          ),
                          markers: _markers,
                          onMapCreated: (controller) {
                            setState(() {
                              _isMapLoading = false;
                            });
                            _mapController = controller;
                            if (widget.stopLocations.isNotEmpty) {
                              Future.delayed(const Duration(milliseconds: 500), () {
                                _mapController.showMarkerInfoWindow(
                                  MarkerId(widget.stopLocations.first.stopId),
                                );
                              });
                            }
                          },
                          zoomControlsEnabled: true,
                          myLocationButtonEnabled: false,
                          mapType: MapType.normal,
                        ),
            ),
            const SizedBox(height: 12),

            // Selected Stop Details
            if (_selectedStop != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected: ${_selectedStop!.stopName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Location: ${_selectedStop!.location}'),
                    Text('Stop ID: ${_selectedStop!.stopId}'),
                    Text('Type: ${_selectedStop!.stopType}'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Stops List
            // Expanded(
            //   child: ListView.builder(
            //     itemCount: widget.stopLocations.length,
            //     itemBuilder: (context, index) {
            //       final stop = widget.stopLocations[index];
            //       final isSelected = _selectedStop?.stopId == stop.stopId;

            //       return Card(
            //         color: isSelected ? Colors.blue.shade50 : null,
            //         child: ListTile(
            //           title: Text(
            //             stop.stopName,
            //             style: TextStyle(
            //               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            //             ),
            //           ),
            //           subtitle: Text(
            //             'Location: ${stop.location}\nStop ID: ${stop.stopId} | Type: ${stop.stopType}',
            //           ),
            //           trailing: IconButton(
            //             icon: const Icon(Icons.map),
            //             onPressed: () => _openInGoogleMaps(stop),
            //             tooltip: 'Open in Google Maps',
            //           ),
            //           onTap: () {
            //             setState(() {
            //               _selectedStop = stop;
            //             });
            //             _mapController.animateCamera(
            //               CameraUpdate.newLatLngZoom(stop.latLng, 16),
            // _mapController.showMarkerInfoWindow(MarkerId(stop.stopId));
            //             );
            //           },
            //         ),
            //       );
            //     },
            //   ),
            // ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
