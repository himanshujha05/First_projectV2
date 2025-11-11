import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;

  final List<Marker> _markers = [
    Marker(
      markerId: MarkerId("green_leaf"),
      position: LatLng(40.7128, -74.0060), // Replace with real coords
      infoWindow: InfoWindow(
        title: "Green Leaf Cafe",
        snippet: "456 Wellness Ave, Midtown",
      ),
    ),
    Marker(
      markerId: MarkerId("ocean_fresh"),
      position: LatLng(40.7158, -74.0030),
      infoWindow: InfoWindow(
        title: "Ocean Fresh",
        snippet: "789 Marine Dr, Harbor",
      ),
    ),
    Marker(
      markerId: MarkerId("fresh_bistro"),
      position: LatLng(40.7138, -74.0080),
      infoWindow: InfoWindow(
        title: "Fresh Garden Bistro",
        snippet: "123 Health St, Downtown",
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nearby Healthy Restaurants')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(40.7138, -74.0060), // Manhattan-ish center
          zoom: 14,
        ),
        markers: Set.from(_markers),
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
