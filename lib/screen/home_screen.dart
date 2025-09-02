import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:safety_app/screen/safe_zones.dart';
import 'contacts_screen.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../services/db_helper.dart';
import 'map_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- UI THEME COLORS ---
  static const Color _primaryColor = Color(0xFF6A1B9A); // Deep Purple
  static const Color _accentColor = Color(0xFF00ACC1); // Cyan/Teal
  static const Color _sosColor = Color(0xFFD32F2F); // Strong Red
  static const Color _cardBackgroundColor = Color(0xCC212121); // Darker semi-transparent grey

  final MapController _mapController = MapController();
  double? latitude;
  double? longitude;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _sosActive = false;

  String primaryContactPhone = '';
  List<Map<String, dynamic>> _safeZones = [];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadPrimaryContact();
    _loadSafeZones();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSafeZones() async {
    final zones = await DBHelper.getSafeZones();
    if (mounted) {
      setState(() {
        _safeZones = zones;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _fetchLocation();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _fetchLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          latitude = position.latitude;
          longitude = position.longitude;
        });
        _mapController.move(LatLng(latitude!, longitude!), 16.5);
      }
    } catch (_) {}
  }

  Future<void> _loadPrimaryContact() async {
    final primaryContact = await DBHelper.getPrimaryContact();
    if (primaryContact != null && mounted) {
      setState(() {
        primaryContactPhone = primaryContact['phone'];
      });
    }
  }

  Future<void> _startSOS() async {
    if (_sosActive) return;
    setState(() => _sosActive = true);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('siren.mp3'));

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String mapsLink =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      await _firestore.collection('sos_alerts').add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'maps_link': mapsLink,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _stopSOS() async {
    await _audioPlayer.stop();
    setState(() => _sosActive = false);
  }

  void _handleSosTap() async {
    await _startSOS();
  }

  void _handleSosLongPress() async {
    await _stopSOS();
  }

  Future<void> _handleCallLongPress() async {
    if (primaryContactPhone.isNotEmpty) {
      String cleanPhone = primaryContactPhone.replaceAll(' ', '');
      final status = await Permission.phone.request();
      if (status.isGranted) {
        try {
          await FlutterPhoneDirectCaller.callNumber(cleanPhone);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone permission denied')));
        }
        if (status.isPermanentlyDenied) openAppSettings();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No primary contact selected")));
      }
    }
  }

  void _handleCallTap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactsScreen(),
      ),
    );
    _loadPrimaryContact();
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required Color backgroundColor,
    double size = 60.0,
    BoxShape shape = BoxShape.circle,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(16) : null,
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String deviceInfo =
        "${Platform.operatingSystem} (${Platform.operatingSystemVersion})";
    double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              mapController: _mapController,
              latitude: latitude,
              longitude: longitude,
              safeZones: _safeZones,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: _sosActive ? statusBarHeight : -80,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              color: _sosColor,
              alignment: Alignment.center,
              child: const Text(
                '🚨 SOS MODE ACTIVE 🚨',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _cardBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Device: $deviceInfo",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Latitude: ${latitude?.toStringAsFixed(4) ?? 'Loading...'}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Longitude: ${longitude?.toStringAsFixed(4) ?? 'Loading...'}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 16, 170),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFloatingActionButton(
                    icon: Icons.sos,
                    onTap: _handleSosTap,
                    onLongPress: _handleSosLongPress,
                    backgroundColor: _sosColor,
                    // --- CHANGE: Increased size for better visibility ---
                    size: 72,
                  ),
                  const SizedBox(height: 16),
                  _buildFloatingActionButton(
                    icon: Icons.call,
                    onTap: _handleCallTap,
                    onLongPress: _handleCallLongPress,
                    backgroundColor: _accentColor,
                    shape: BoxShape.rectangle,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  _buildFloatingActionButton(
                    icon: Icons.shield,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SafeZonesScreen(initialSafeZones: _safeZones),
                        ),
                      );
                      _loadSafeZones();
                    },
                    backgroundColor: _primaryColor,
                    shape: BoxShape.rectangle,
                    size: 56,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}