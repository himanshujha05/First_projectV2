import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  // Default center (NYC). We’ll replace this with the user’s location when we can.
  static const LatLng _initialCenter = LatLng(40.7138, -74.0060);
  LatLng _currentCenter = _initialCenter;

  @override
  void initState() {
    super.initState();
    _initLocation(); // try to move map to the user's current location
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Try to get current location and move map there.
  Future<void> _initLocation() async {
    try {
      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // User said no – just keep default center, no error spam.
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services off – keep default.
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentCenter = userLatLng;
      });

      // If map is already created, animate to the user
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: userLatLng, zoom: 14),
          ),
        );
      }
    } catch (e) {
      // Just log it; we don't want to annoy the user
      debugPrint('Error getting current location: $e');
    }
  }

  /// Open Google Maps (web / app) with the given search query.
  /// If query is empty, use "healthy restaurants near me".
  Future<void> _openGoogleMapsSearch([String? query]) async {
    final effectiveQuery =
        (query != null && query.trim().isNotEmpty)
            ? query.trim()
            : 'healthy restaurants near me';

    final uri = Uri.parse(
      'https://www.google.com/maps/search/${Uri.encodeComponent(effectiveQuery)}/',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Healthy Restaurants'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Embedded Google Map (for visual context)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;

              // If we already got the user's location before the map was created,
              // move the camera there.
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _currentCenter, zoom: 14),
                ),
              );
            },
            myLocationEnabled: true,           // show blue dot when permission granted
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            // 👉 tapping anywhere on the map opens Google Maps search
            onTap: (_) => _openGoogleMapsSearch(_searchController.text),
          ),

          // Search bar overlay at the top
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (value) => _openGoogleMapsSearch(value),
                  decoration: InputDecoration(
                    hintText: 'Search (e.g. healthy restaurants near me)',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () =>
                          _openGoogleMapsSearch(_searchController.text),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGoogleMapsSearch(_searchController.text),
        label: const Text('Open in Google Maps'),
        icon: const Icon(Icons.map),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }
}
