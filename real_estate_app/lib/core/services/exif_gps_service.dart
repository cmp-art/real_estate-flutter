// lib/core/services/exif_gps_service.dart
//
// Reads GPS coordinates embedded invisibly in photo EXIF metadata and
// compares them to the property's listed address coordinates.
//
// Every photo taken with a smartphone camera contains EXIF data that includes
// the GPS location where the photo was taken — provided the camera app has
// location permission.
//
// This proves that whoever listed the property was PHYSICALLY PRESENT at that
// location when they took the photos.  A scammer who copies photos from
// Google Images or other listings will have no matching EXIF GPS, or the EXIF
// will point to a completely different city.
//
// Works on: Android ✅  iOS ✅  Web ✅  PWA ✅
// Cost: $0 — uses the pure-Dart `exif` package.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ExifGpsResult {
  final bool    hasGps;
  final double? latitude;
  final double? longitude;

  const ExifGpsResult({
    required this.hasGps,
    this.latitude,
    this.longitude,
  });

  static const ExifGpsResult noGps = ExifGpsResult(hasGps: false);
}

class ExifGpsScanResult {
  /// Best GPS coordinate found across all scanned photos.
  final ExifGpsResult? bestGps;

  /// Distance in metres between [bestGps] and the property address.
  /// Null when [bestGps] is null or property coordinates are not set.
  final double? distanceMeters;

  /// True when at least one photo was taken within [kMatchRadiusMeters] of
  /// the property address.
  final bool matched;

  /// Number of photos that had EXIF GPS data.
  final int photosWithGps;

  const ExifGpsScanResult({
    required this.bestGps,
    required this.distanceMeters,
    required this.matched,
    required this.photosWithGps,
  });

  static const ExifGpsScanResult empty = ExifGpsScanResult(
    bestGps:        null,
    distanceMeters: null,
    matched:        false,
    photosWithGps:  0,
  );
}

/// Within this radius we consider the photos to have been taken "at" the
/// property.  300 m is generous enough to cover large plots, compounds, and
/// small GPS inaccuracies while still being tight enough to catch fraud.
const double kMatchRadiusMeters = 300.0;

class ExifGpsService {
  // ── Public API ────────────────────────────────────────────────────────────

  /// Scans [photos] for EXIF GPS data and returns the best match result.
  ///
  /// [propertyLat] / [propertyLng] — coordinates from the listing form.
  /// Pass null if the address was not geocoded (no comparison possible).
  Future<ExifGpsScanResult> scanPhotos({
    required List<XFile> photos,
    required double?     propertyLat,
    required double?     propertyLng,
  }) async {
    if (photos.isEmpty) return ExifGpsScanResult.empty;

    int photosWithGps = 0;
    ExifGpsResult? bestGps;
    double?        bestDist;

    for (final photo in photos) {
      final gps = await readGpsFromPhoto(photo);
      if (!gps.hasGps) continue;

      photosWithGps++;

      if (propertyLat == null || propertyLng == null) {
        // No property coords — record GPS found but can't compare
        bestGps ??= gps;
        continue;
      }

      final dist = distanceBetween(
        gps.latitude!,  gps.longitude!,
        propertyLat,    propertyLng,
      );

      if (bestDist == null || dist < bestDist) {
        bestDist = dist;
        bestGps  = gps;
      }
    }

    final matched = bestDist != null && bestDist <= kMatchRadiusMeters;

    _log('Scanned ${photos.length} photos — $photosWithGps had GPS. '
         '${bestDist != null ? "Closest: ${bestDist.toStringAsFixed(0)} m — "
              "${matched ? "MATCH ✅" : "NO MATCH ❌"}" : "No comparison (no property coords)"}');

    return ExifGpsScanResult(
      bestGps:        bestGps,
      distanceMeters: bestDist,
      matched:        matched,
      photosWithGps:  photosWithGps,
    );
  }

  // ── Single photo EXIF read ────────────────────────────────────────────────

  Future<ExifGpsResult> readGpsFromPhoto(XFile photo) async {
    try {
      final Uint8List bytes = await photo.readAsBytes();
      final Map<String, IfdTag> data = await readExifFromBytes(bytes);

      if (data.isEmpty) return ExifGpsResult.noGps;

      final latTag  = data['GPS GPSLatitude'];
      final lngTag  = data['GPS GPSLongitude'];
      final latRef  = data['GPS GPSLatitudeRef']?.printable  ?? 'N';
      final lngRef  = data['GPS GPSLongitudeRef']?.printable ?? 'E';

      if (latTag == null || lngTag == null) return ExifGpsResult.noGps;

      final lat = _parseDms(latTag, latRef);
      final lng = _parseDms(lngTag, lngRef);

      if (lat == null || lng == null) return ExifGpsResult.noGps;

      // Sanity-check: valid lat/lng ranges
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        return ExifGpsResult.noGps;
      }

      return ExifGpsResult(hasGps: true, latitude: lat, longitude: lng);
    } catch (e) {
      _log('EXIF read error (non-fatal): $e');
      return ExifGpsResult.noGps;
    }
  }

  // ── Haversine distance ───────────────────────────────────────────────────

  /// Returns the great-circle distance in metres between two coordinates.
  double distanceBetween(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const double r = 6371000; // Earth radius in metres
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
              math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // ── Internals ────────────────────────────────────────────────────────────

  /// Converts DMS (degrees / minutes / seconds) EXIF value to decimal degrees.
  /// [ref] is the hemisphere reference: 'N', 'S', 'E', or 'W'.
  double? _parseDms(IfdTag tag, String ref) {
    try {
      final values = tag.values.toList();
      if (values.length < 3) return null;

      double degrees = 0, minutes = 0, seconds = 0;

      degrees = _ratioToDouble(values[0]);
      minutes = _ratioToDouble(values[1]);
      seconds = _ratioToDouble(values[2]);

      double decimal = degrees + minutes / 60.0 + seconds / 3600.0;

      // Southern latitudes and western longitudes are negative
      if (ref == 'S' || ref == 'W') decimal = -decimal;

      return decimal;
    } catch (e) {
      return null;
    }
  }

  /// Converts a value that may be a [Ratio], [int], [double], or [String]
  /// to a plain [double].
  double _ratioToDouble(dynamic v) {
    if (v is Ratio) {
      return v.denominator != 0 ? v.numerator / v.denominator : 0.0;
    }
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double _toRad(double deg) => deg * math.pi / 180.0;

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ExifGPS] $msg');
  }
}
