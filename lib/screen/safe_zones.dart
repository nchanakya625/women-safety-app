import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class SafeZonesScreen extends StatefulWidget {
  // --- FIX: This is the required change ---
  // It is now set up to receive the pre-loaded data from HomeScreen
  final List<Map<String, dynamic>> initialSafeZones;

  const SafeZonesScreen({
    Key? key,
    required this.initialSafeZones,
  }) : super(key: key);

  @override
  State<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends State<SafeZonesScreen> {
  List<Map<String, dynamic>> safeZones = [];

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  IconData selectedIcon = Icons.home;
  double? selectedLat;
  double? selectedLng;

  final Map<String, IconData> iconOptions = {
    'Home': Icons.home,
    'Work': Icons.work,
    'School': Icons.school,
    'Park': Icons.park,
    'Hospital': Icons.local_hospital,
  };

  @override
  void initState() {
    super.initState();
    // --- FIX: This now uses the data passed from HomeScreen ---
    // This makes the screen load instantly.
    safeZones = widget.initialSafeZones;
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // This function is now only used to REFRESH the list after adding/deleting
  Future<void> _loadSafeZones() async {
    final data = await DBHelper.getSafeZones();
    if (mounted) {
      setState(() => safeZones = data);
    }
  }

  Future<void> _addSafeZone() async {
    final Map<String, dynamic> safeZoneData = {
      'name': nameController.text,
      'description': descriptionController.text,
      'iconCode': selectedIcon.codePoint,
      'iconFont': selectedIcon.fontFamily ?? 'MaterialIcons',
      'latitude': selectedLat!,
      'longitude': selectedLng!,
    };

    await DBHelper.insertSafeZone(safeZoneData);

    Navigator.pop(context); // Close the bottom sheet
    _loadSafeZones(); // Refresh the list
  }

  Future<void> _deleteSafeZone(int id) async {
    await DBHelper.deleteSafeZone(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safe Zone Deleted'),
        backgroundColor: Colors.red,
      ),
    );
    _loadSafeZones();
  }

  void _showAddSafeZoneSheet() {
    nameController.clear();
    descriptionController.clear();
    setState(() {
      selectedIcon = Icons.home;
      selectedLat = null;
      selectedLng = null;
    });

    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            Future<void> pickLocation() async {
              LatLng? picked = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapPickerScreen(
                    initialLatLng: selectedLat != null && selectedLng != null
                        ? LatLng(selectedLat!, selectedLng!)
                        : null,
                  ),
                ),
              );
              if (picked != null) {
                sheetSetState(() {
                  selectedLat = picked.latitude;
                  selectedLng = picked.longitude;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Zone Name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: iconOptions.entries.map((entry) {
                      final isSelected = selectedIcon == entry.value;
                      return ChoiceChip(
                        label: Icon(entry.value,
                            color: isSelected ? Colors.white : Colors.black54),
                        selected: isSelected,
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.grey[200],
                        onSelected: (bool selected) {
                          if (selected) {
                            sheetSetState(() {
                              selectedIcon = entry.value;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: pickLocation,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        selectedLat != null
                            ? 'Location Selected\nLat: ${selectedLat!.toStringAsFixed(4)}, Lng: ${selectedLng!.toStringAsFixed(4)}'
                            : 'Select Location on Map',
                        textAlign: TextAlign.center,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                            color: Colors.deepPurple.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty ||
                            selectedLat == null ||
                            selectedLng == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please fill all fields and select a location on the map.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                        _addSafeZone();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Add Safe Zone',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safe Zones"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: safeZones.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.shield_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Safe Zones Added',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to add one.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: safeZones.length,
        itemBuilder: (context, index) {
          final zone = safeZones[index];
          final icon = IconData(zone['iconCode'],
              fontFamily: zone['iconFont'] ?? 'MaterialIcons');

          return Card(
            elevation: 2,
            margin:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.deepPurple.shade100,
                    child:
                    Icon(icon, color: Colors.deepPurple, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone['name'],
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        if (zone['description'] != null &&
                            zone['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            zone['description'],
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Lat: ${zone['latitude'].toStringAsFixed(4)}, Lng: ${zone['longitude'].toStringAsFixed(4)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () => _deleteSafeZone(zone['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: _showAddSafeZoneSheet,
      ),
    );
  }
}

// MapPickerScreen is unchanged from the last version, but included for completeness
class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLatLng;
  const MapPickerScreen({Key? key, this.initialLatLng}) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentCenter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getInitialLocation();
  }

  Future<void> _getInitialLocation() async {
    LatLng initialPosition;
    if (widget.initialLatLng != null) {
      initialPosition = widget.initialLatLng!;
    } else {
      try {
        Position position = await _determinePosition();
        initialPosition = LatLng(position.latitude, position.longitude);
      } catch (e) {
        initialPosition = LatLng(28.6139, 77.2090);
      }
    }

    if (mounted) {
      setState(() {
        _currentCenter = initialPosition;
        _isLoading = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter!,
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                if (position.center != null) {
                  _currentCenter = position.center;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
            ],
          ),
          const Center(
            child: Icon(
              Icons.location_pin,
              size: 50,
              color: Colors.red,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check),
        label: const Text("Confirm Location"),
        onPressed: () {
          Navigator.pop(context, _currentCenter);
        },
      ),
    );
  }
}