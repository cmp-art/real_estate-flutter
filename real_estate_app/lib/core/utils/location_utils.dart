// lib/core/utils/location_utils.dart
//
// GPS + geocoding helpers used across the app.
// Uses Photon (by Komoot) — free, no API key, works on web, Android and iOS.
// The `geocoding` package is NOT used because it crashes on Flutter Web.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class PhotonPlace {
  final String name;        // short label, e.g. "Masaki"
  final String context;     // e.g. "Dar es Salaam, Tanzania"
  final String displayName; // full, e.g. "Masaki, Dar es Salaam, Tanzania"
  final double? latitude;   // from geometry.coordinates[1]
  final double? longitude;  // from geometry.coordinates[0]

  const PhotonPlace({
    required this.name,
    required this.context,
    required this.displayName,
    this.latitude,
    this.longitude,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FORWARD SEARCH (autocomplete) — restricted to East Africa bbox
// ─────────────────────────────────────────────────────────────────────────────

/// Returns up to 6 place suggestions for [query] within East Africa.
/// Requires at least 3 characters. Returns empty list on error.
Future<List<PhotonPlace>> photonSearch(String query) async {
  if (query.trim().length < 3) return [];
  try {
    final uri = Uri.parse(
      'https://photon.komoot.io/api/'
      '?q=${Uri.encodeComponent(query.trim())}'
      '&limit=6&lang=en&bbox=21,-27,48,15',
    );
    final response = await http
        .get(uri, headers: {'User-Agent': 'PatamjengoApp/1.0'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];

    final data     = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];

    return features.map<PhotonPlace>((f) {
      final feature = f as Map<String, dynamic>;
      final props   = feature['properties'] as Map<String, dynamic>? ?? {};
      final geometry = feature['geometry'] as Map<String, dynamic>?;

      final name    = (props['name']    as String?) ?? '';
      final city    = (props['city']    as String?)
                   ?? (props['county']  as String?)
                   ?? (props['state']   as String?)
                   ?? '';
      final country = (props['country'] as String?) ?? '';

      final context = [city, country].where((s) => s.isNotEmpty).join(', ');
      final display = [name, context].where((s) => s.isNotEmpty).join(', ');

      // Photon GeoJSON: coordinates[0] = longitude, coordinates[1] = latitude
      double? lat;
      double? lng;
      if (geometry != null) {
        final coords = geometry['coordinates'] as List<dynamic>?;
        if (coords != null && coords.length >= 2) {
          lng = (coords[0] as num?)?.toDouble();
          lat = (coords[1] as num?)?.toDouble();
        }
      }

      return PhotonPlace(
        name:        name.isNotEmpty ? name : display,
        context:     context,
        displayName: display.isNotEmpty ? display : name,
        latitude:    lat,
        longitude:   lng,
      );
    }).where((p) => p.name.isNotEmpty).toList();
  } catch (e) {
    debugPrint('photonSearch error: $e');
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVERSE GEOCODING — no bbox (user may be anywhere in the world)
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> photonReverse(double lat, double lon) async {
  try {
    final uri = Uri.parse(
      'https://photon.komoot.io/reverse'
      '?lat=$lat&lon=$lon&limit=1&lang=en',
    );
    final response = await http
        .get(uri, headers: {'User-Agent': 'PatamjengoApp/1.0'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data     = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) return null;

    final props  = (features.first as Map<String, dynamic>)['properties']
        as Map<String, dynamic>? ?? {};

    // Return the most specific label available
    return (props['suburb']  as String?)
        ?? (props['name']    as String?)
        ?? (props['city']    as String?)
        ?? (props['county']  as String?)
        ?? (props['state']   as String?);
  } catch (e) {
    debugPrint('photonReverse error: $e');
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GPS + REVERSE GEOCODE
// ─────────────────────────────────────────────────────────────────────────────

/// Requests location permission, gets GPS position, reverse-geocodes via Photon.
/// Returns null on permission denied, timeout, or API failure.
Future<String?> detectCurrentLocation() async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );

    return await photonReverse(pos.latitude, pos.longitude);
  } catch (e) {
    debugPrint('detectCurrentLocation error: $e');
    return null;
  }
}

/// Requests location permission, gets GPS position, reverse-geocodes via Photon.
/// Returns a record with the place name, latitude, and longitude.
/// Any field may be null on failure.
Future<({String? name, double? latitude, double? longitude})>
    detectCurrentLocationFull() async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return (name: null, latitude: null, longitude: null);
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );

    final name = await photonReverse(pos.latitude, pos.longitude);
    return (name: name, latitude: pos.latitude, longitude: pos.longitude);
  } catch (e) {
    debugPrint('detectCurrentLocationFull error: $e');
    return (name: null, latitude: null, longitude: null);
  }
}
