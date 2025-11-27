import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final StopLocation stopLocation;
  final String driver;
  final String contact1;
  final String contact2;

  const StopLocationsDialog(
    this.stopLocation,
    this.driver,
    this.contact1,
    this.contact2, {
    super.key,
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
    _selectedStop = widget.stopLocation;
    _createMarkers();
  }

  void _createMarkers() {
    final latLng = widget.stopLocation.latLng;
    _markers = {
      Marker(
        markerId: MarkerId(widget.stopLocation.stopId),
        position: latLng,
        infoWindow: InfoWindow(
          title: widget.stopLocation.stopName,
          snippet: 'Stop ID: ${widget.stopLocation.stopId}',
        ),
        onTap: () {
          setState(() {
            _selectedStop = widget.stopLocation;
          });
          _mapController.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        },
      ),
    };
  }

  Future<void> _openInGoogleMaps(StopLocation stop) async {
    final latLng = stop.latLng;
    final url =
        'https://www.google.com/maps/search/?api=1&query=${latLng.latitude},${latLng.longitude}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Google Maps for ${stop.stopName}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Stop Location - ${widget.stopLocation.stopName}'),
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
                        target: widget.stopLocation.latLng,
                        zoom: 13,
                      ),
                      markers: _markers,
                      onMapCreated: (controller) {
                        setState(() {
                          _isMapLoading = false;
                        });
                        _mapController = controller;
                        Future.delayed(const Duration(milliseconds: 500), () {
                          _mapController.showMarkerInfoWindow(
                            MarkerId(widget.stopLocation.stopId),
                          );
                        });
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Driver: ${widget.driver}'),
                        const SizedBox(width: 16),
                        Text('Contact 1: ${widget.contact1}'),
                        const SizedBox(width: 16),
                        Text('Contact 2: ${widget.contact2}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openInGoogleMaps(_selectedStop!),
                      icon: const Icon(Icons.map),
                      label: const Text('Open in Google Maps'),
                    ),
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
