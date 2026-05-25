import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:mploya/config/constants.dart';

/// Service to handle device GPS location.
/// Uses geolocator package for cross-platform support (Android, iOS, Web).
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  LatLng? _lastKnownLocation;
  bool _permissionGranted = false;

  LatLng? get lastKnownLocation => _lastKnownLocation;
  bool get hasPermission => _permissionGranted;

  /// Check and request location permissions.
  /// Returns true if permission is granted.
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    _permissionGranted = true;
    return true;
  }

  /// Get the current device position.
  /// Returns null if permission is not granted or location unavailable.
  Future<LatLng?> getCurrentLocation() async {
    try {
      if (!_permissionGranted) {
        final granted = await requestPermission();
        if (!granted) return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: kLocationTimeoutSeconds),
        ),
      );

      _lastKnownLocation = LatLng(position.latitude, position.longitude);
      return _lastKnownLocation;
    } catch (e) {
      // Fallback: try last known position
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          _lastKnownLocation = LatLng(lastPosition.latitude, lastPosition.longitude);
          return _lastKnownLocation;
        }
      } catch (e) {
        debugPrint('Error getting last known position: $e');
      }
      return null;
    }
  }

  /// Calculate distance in km between two points.
  double distanceTo(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude, from.longitude,
      to.latitude, to.longitude,
    ) / 1000; // Convert meters to km
  }
}
