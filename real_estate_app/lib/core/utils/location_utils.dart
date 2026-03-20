// lib/core/utils/location_utils.dart
//
// GPS + reverse-geocoding helper used across the app.
// Uses OpenStreetMap Nominatim — works on web, Android and iOS.
// The `geocoding` package is NOT used because it crashes on Flutter Web.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Requests location permission, gets current GPS position and reverse-geocodes
/// it to the most specific human-readable area name available.
///
/// Returns null when:
///   - permission denied
///   - timeout
///   - Nominatim unavailable
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

    return await _nominatimReverseGeocode(pos.latitude, pos.longitude);
  } catch (e) {
    debugPrint('detectCurrentLocation error: $e');
    return null;
  }
}

Future<String?> _nominatimReverseGeocode(double lat, double lon) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lon&format=json&zoom=14&addressdetails=1',
    );
    final response = await http
        .get(uri, headers: {
          'User-Agent':      'PatamjengoApp/1.0',
          'Accept-Language': 'en',
        })
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data    = jsonDecode(response.body) as Map<String, dynamic>;
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return null;

    // Pick the most specific non-null field available:
    //   suburb / neighbourhood → district-level area (e.g. "Masaki", "Westlands")
    //   city_district / quarter → broader city area
    //   city / town / state    → fallback
    return address['suburb']        as String?
        ?? address['neighbourhood'] as String?
        ?? address['city_district'] as String?
        ?? address['quarter']       as String?
        ?? address['city']          as String?
        ?? address['town']          as String?
        ?? address['state']         as String?;
  } catch (e) {
    debugPrint('Nominatim error: $e');
    return null;
  }
}
