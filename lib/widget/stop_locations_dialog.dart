import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';

class StopLocation {
  final String stopId;
  final String stopName;
  final String location;

  StopLocation({
    required this.stopId,
    required this.stopName,
    required this.location,
  });

  factory StopLocation.fromJson(Map<String, dynamic> json) {
    return StopLocation(
      stopId: json['stop_id'] ?? '',
      stopName: json['stop_name'] ?? '',
      location: json['location'] ?? '',
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
  final String driver;
  final String contact1;
  final String contact2;

  const StopLocationsDialog(
    this.stopLocations,
    this.driver,
    this.contact1,
    this.contact2, {
    super.key,
  });

  @override
  State<StopLocationsDialog> createState() => _StopLocationsDialogState();
}

class _StopLocationsDialogState extends State<StopLocationsDialog> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  StopLocation? _selectedStop;
  bool _isMapLoading = true;
  Timer? _mapLoadTimer;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _selectedStop = widget.stopLocations.isNotEmpty
        ? widget.stopLocations[0]
        : null;
    _createMarkers();
    _startMapLoadTimer();
    _getCurrentPosition();
  }

  @override
  void dispose() {
    _mapLoadTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startMapLoadTimer() {
    _mapLoadTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isMapLoading) {
        setState(() {
          _isMapLoading = false;
        });
      }
    });
  }

  void _createMarkers() {
    _markers.clear();
    for (var stop in widget.stopLocations) {
      _markers.add(
        Marker(
          markerId: MarkerId(stop.stopId),
          position: stop.latLng,
          infoWindow: InfoWindow(
            title: stop.stopName,
            snippet: 'Stop ID: ${stop.stopId}',
          ),
          onTap: () {
            setState(() {
              _selectedStop = stop;
            });
          },
        ),
      );
    }
    Logger().d('Created ${_markers.length} markers for stops');
  }

  Future<void> _getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Logger().w('Location permission denied');
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      Logger().d('Current position fetched: $_currentPosition');
    } catch (e) {
      Logger().e('Error fetching current position: $e');
    }
  }

  // Future<void> _openInGoogleMaps(StopLocation stop) async {
  //   final latLng = stop.latLng;
  //   final url =
  //       'https://www.google.com/maps/search/?api=1&query=${latLng.latitude},${latLng.longitude}';

  //   if (await canLaunchUrl(Uri.parse(url))) {
  //     await launchUrl(Uri.parse(url));
  //   } else {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Could not open Google Maps for ${stop.stopName}'),
  //         ),
  //       );
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final firstStop = widget.stopLocations.isNotEmpty
        ? widget.stopLocations[0]
        : null;
    return AlertDialog(
      title: Text('Stop Locations - ${firstStop?.stopName ?? 'No Stops'}'),
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
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            _selectedStop?.latLng ??
                            _currentPosition ??
                            const LatLng(0.0, 0.0),
                        zoom: 13,
                      ),
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapLoadTimer?.cancel();
                        setState(() {
                          _isMapLoading = false;
                        });
                        _mapController = controller;
                      },
                      zoomControlsEnabled: true,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
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
                    const SizedBox(height: 8),
                    Wrap(
                      children: [
                        Text('Driver: ${widget.driver}'),
                        const SizedBox(width: 16),
                        Text('Contact 1: ${widget.contact1}'),
                        const SizedBox(width: 16),
                        Text('Contact 2: ${widget.contact2}'),
                      ],
                    ),
                    // const SizedBox(height: 8),
                    // ElevatedButton.icon(
                    //   onPressed: () => _openInGoogleMaps(_selectedStop!),
                    //   icon: const Icon(Icons.map),
                    //   label: const Text('Open in Google Maps'),
                    // ),
                  ],
                ),
              ),
            ],
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
