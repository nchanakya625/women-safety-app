import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends StatelessWidget {
  final MapController mapController;
  final double? latitude;
  final double? longitude;

  // --- CHANGE: Accept the list of safe zones ---
  final List<Map<String, dynamic>> safeZones;

  const MapWidget({
    Key? key,
    required this.mapController,
    this.latitude,
    this.longitude,
    this.safeZones = const [], // Default to an empty list
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- CHANGE: The map will now center on the user's location, not a hardcoded point ---
    final LatLng mapCenter = (latitude != null && longitude != null)
        ? LatLng(latitude!, longitude!)
        : LatLng(28.7041, 77.1025); // Default to Delhi if user location isn't available yet

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: 12.0,
      ),
      // Layers are drawn in order: Tile -> Circle -> User Marker -> Zone Icons
      children: [
        // Base map tiles
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'com.example.safety_app',
        ),

        // --- CHANGE: Layer for the circular radius of each safe zone ---
        CircleLayer(
          circles: safeZones.map((zone) {
            return CircleMarker(
              point: LatLng(zone['latitude'], zone['longitude']),
              radius: 200, // Radius in meters, you can adjust this value
              useRadiusInMeter: true,
              color: Colors.blue.withOpacity(0.2),
              borderColor: Colors.blue,
              borderStrokeWidth: 1.5,
            );
          }).toList(),
        ),

        // Marker for the user's current location pin
        if (latitude != null && longitude != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(latitude!, longitude!),
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blueAccent,
                  size: 30,
                ),
              ),
            ],
          ),

        // --- CHANGE: Layer for the icons of each safe zone ---
        MarkerLayer(
          markers: safeZones.map((zone) {
            // Recreate the IconData from the code and font family stored in the DB
            final iconData = IconData(
              zone['iconCode'],
              fontFamily: zone['iconFont'] ?? 'MaterialIcons',
            );
            return Marker(
              point: LatLng(zone['latitude'], zone['longitude']),
              width: 40,
              height: 40,
              child: CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: Icon(iconData, color: Colors.white, size: 22),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}