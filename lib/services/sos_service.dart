import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class SOSService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _sirenPlaying = false;

  static Future<void> startSOS() async {
    if (_sirenPlaying) return;
    _sirenPlaying = true;

    try {
      await _audioPlayer.play(
        AssetSource('siren.mp3'),
        volume: 1.0,
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String mapsLink =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'maps_link': mapsLink,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _sirenPlaying = false; // Reset if failed
    }
  }

  static Future<void> stopSOS() async {
    try {
      await _audioPlayer.stop();
    } finally {
      _sirenPlaying = false;
    }
  }

  static bool isSirenPlaying() => _sirenPlaying;
}
