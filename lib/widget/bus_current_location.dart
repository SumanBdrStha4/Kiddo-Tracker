import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kiddo_tracker/model/route.dart';
import 'dart:developer' as developer;

import 'package:logger/logger.dart';

class BusCurrentLocationDialog extends StatefulWidget {
  final String routeId;
  final List<RouteInfo> routes;
  final double latitude;
  final double longitude;
  final String busName;

  const BusCurrentLocationDialog({
    super.key,
    required this.routeId,
    required this.routes,
    required this.latitude,
    required this.longitude,
    required this.busName,
  });

  @override
  State<BusCurrentLocationDialog> createState() =>
      _BusCurrentLocationDialogState();
}

class _BusCurrentLocationDialogState extends State<BusCurrentLocationDialog> {
  late LatLng _initialPosition;
  final Set<Marker> _markers = {};
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();

    // Validate coordinates
    if (widget.latitude < -90 ||
        widget.latitude > 90 ||
        widget.longitude < -180 ||
        widget.longitude > 180 ||
        (widget.latitude == 0 && widget.longitude == 0)) {
      developer.log(
        'Invalid coordinates: lat=${widget.latitude}, lng=${widget.longitude}. Using default location.',
        name: 'BusCurrentLocationDialog',
      );
      // Use New Delhi as default location when coordinates are invalid
      _initialPosition = const LatLng(
        28.6139,
        77.2090,
      ); // New Delhi coordinates
    } else {
      Logger().i(
        'Valid coordinates received: lat=${widget.latitude}, lng=${widget.longitude}',
      );
      _initialPosition = LatLng(widget.latitude, widget.longitude);
    }

    developer.log(
      'Initializing map with position: ${_initialPosition.latitude}, ${_initialPosition.longitude}',
      name: 'BusCurrentLocationDialog',
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('bus_location'),
        position: _initialPosition,
        infoWindow: InfoWindow(title: widget.busName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.busName} - Current Location'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialPosition,
            zoom: 15,
          ),
          onMapCreated: _onMapCreated,
          mapType: MapType.normal,
          markers: _markers,
          onCameraMove: (CameraPosition position) {
            developer.log(
              'Camera moved to: ${position.target.latitude}, ${position.target.longitude}',
              name: 'BusCurrentLocationDialog',
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    Logger().i('GoogleMap controller created');
    mapController = controller;
    developer.log(
      'GoogleMap controller created successfully',
      name: 'BusCurrentLocationDialog',
    );

    try {
      // Animate camera to the bus location
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _initialPosition, zoom: 15),
        ),
      );
      developer.log(
        'Camera animated to bus location',
        name: 'BusCurrentLocationDialog',
      );
    } catch (e) {
      developer.log(
        'Error animating camera: $e',
        name: 'BusCurrentLocationDialog',
        error: e,
      );
    }
  }
}
