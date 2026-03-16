// lib/core/services/ai_search_service.dart
//
// AI-POWERED PROPERTY SEARCH & FILTER — 100% FREE
//
// Strategy: Client-side NLP parsing of natural language queries.
// No API calls needed — extracts intent from the query string and
// maps it to PropertyFilterEntity fields that Supabase already supports.
//
// Examples:
//   "3 bedroom apartment in Dar es Salaam under 500k"
//   → filter: category=apartment, bedrooms≥3, location=Dar es Salaam, maxPrice=500000
//
//   "cheap house for rent in Arusha"
//   → filter: category=house, type=rent, location=Arusha, maxPrice=(cheap heuristic)
//
// This is FREE because it runs entirely on-device without any API calls.

import '../../features/properties/domain/entities/property_filter_entity.dart';
import '../../core/constants/app_constants.dart';

class AiSearchResult {
  final PropertyFilterEntity filter;
  final String summary;          // Human-readable summary of what was parsed
  final bool hasAnyFilter;

  const AiSearchResult({
    required this.filter,
    required this.summary,
    required this.hasAnyFilter,
  });
}

class AiSearchService {
  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  /// Parse a natural language search query into a PropertyFilterEntity.
  /// Returns null summary parts if nothing was detected.
  AiSearchResult parseQuery(String query) {
    if (query.trim().isEmpty) {
      return const AiSearchResult(
        filter: PropertyFilterEntity(),
        summary: '',
        hasAnyFilter: false,
      );
    }

    final q = query.toLowerCase().trim();

    final type      = _extractType(q);
    final category  = _extractCategory(q);
    final bedrooms  = _extractBedrooms(q);
    final price     = _extractPrice(q);
    final location  = _extractLocation(q, query); // pass original for casing
    final status    = _extractStatus(q);

    final filter = PropertyFilterEntity(
      type:        type,
      category:    category,
      minBedrooms: bedrooms?['min'],
      maxBedrooms: bedrooms?['max'],
      minPrice:    price?['min'],
      maxPrice:    price?['max'],
      location:    location,
      status:      status,
    );

    final hasAny = type != null || category != null || bedrooms != null ||
        price != null || location != null || status != null;

    return AiSearchResult(
      filter:       filter,
      summary:      _buildSummary(filter, type, category, bedrooms, price, location, status),
      hasAnyFilter: hasAny,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXTRACTORS
  // ══════════════════════════════════════════════════════════════════════════

  PropertyType? _extractType(String q) {
    // Explicit rent signals
    if (RegExp(r'\brent(ing|ed|al)?\b|\bfor rent\b|\bmonthly\b|\bper month\b'
        r'|\btenants?\b|\blease\b').hasMatch(q)) {
      return PropertyType.rent;
    }
    // Explicit sale signals
    if (RegExp(r'\bsale?\b|\bbuy(ing)?\b|\bpurchas(e|ing)\b|\bfor sale\b'
        r'|\bown(ing)?\b|\bprice\b').hasMatch(q)) {
      return PropertyType.sale;
    }
    return null;
  }

  PropertyCategory? _extractCategory(String q) {
    if (RegExp(r'\bapartments?\b|\bflats?\b|\bstudio\b|\bloft\b').hasMatch(q)) {
      return PropertyCategory.apartment;
    }
    if (RegExp(r'\bvillas?\b|\bmansions?\b|\bbungalows?\b').hasMatch(q)) {
      return PropertyCategory.house; // villas map to house for filter
    }
    if (RegExp(r'\bhouses?\b|\bhomes?\b|\bresidential\b|\bfamily\b').hasMatch(q)) {
      return PropertyCategory.house;
    }
    if (RegExp(r'\bland\b|\bplots?\b|\bacres?\b|\bfarm\b').hasMatch(q)) {
      return PropertyCategory.land;
    }
    if (RegExp(r'\bcommercial\b|\boffice\b|\bshops?\b|\bwarehouse\b|\bstore\b')
        .hasMatch(q)) {
      return PropertyCategory.commercial;
    }
    return null;
  }

  Map<String, int>? _extractBedrooms(String q) {
    // "3 bedroom", "3 bed", "3br", "3+bedroom"
    final exact = RegExp(r'(\d+)\s*(?:\+\s*)?(?:bed(?:room)?s?|br\b)');
    final plus  = RegExp(r'(\d+)\+\s*(?:bed(?:room)?s?|br\b)');
    final range = RegExp(r'(\d+)\s*[-–to]+\s*(\d+)\s*bed(?:room)?s?');

    final rangeMatch = range.firstMatch(q);
    if (rangeMatch != null) {
      return {
        'min': int.parse(rangeMatch.group(1)!),
        'max': int.parse(rangeMatch.group(2)!),
      };
    }

    final plusMatch = plus.firstMatch(q);
    if (plusMatch != null) {
      return {'min': int.parse(plusMatch.group(1)!)};
    }

    final exactMatch = exact.firstMatch(q);
    if (exactMatch != null) {
      final n = int.parse(exactMatch.group(1)!);
      return {'min': n, 'max': n};
    }

    return null;
  }

  Map<String, double>? _extractPrice(String q) {
    // Support: "under 500k", "below 2M", "max 300,000", "500k-1M",
    //          "cheap", "affordable", "luxury", "above 100k"
    double? parseAmount(String s) {
      s = s.replaceAll(',', '').trim();
      if (s.endsWith('m')) {
        return double.tryParse(s.replaceAll('m', '')) != null
          ? double.parse(s.replaceAll('m', '')) * 1000000 : null;
      }
      if (s.endsWith('k')) {
        return double.tryParse(s.replaceAll('k', '')) != null
          ? double.parse(s.replaceAll('k', '')) * 1000 : null;
      }
      return double.tryParse(s);
    }

    // Range: "500k - 1M" or "500,000 to 1,000,000"
    final rangeRe = RegExp(
        r'(\d[\d,]*(?:\.\d+)?[mk]?)\s*[-–to]+\s*(\d[\d,]*(?:\.\d+)?[mk]?)',
        caseSensitive: false);
    final rangeMatch = rangeRe.firstMatch(q);
    if (rangeMatch != null) {
      final min = parseAmount(rangeMatch.group(1)!);
      final max = parseAmount(rangeMatch.group(2)!);
      if (min != null && max != null) return {'min': min, 'max': max};
    }

    // Under / below / max / less than
    final underRe = RegExp(
        r'(?:under|below|max|less than|up to|at most)\s*(\d[\d,]*(?:\.\d+)?[mk]?)',
        caseSensitive: false);
    final underMatch = underRe.firstMatch(q);
    if (underMatch != null) {
      final max = parseAmount(underMatch.group(1)!);
      if (max != null) return {'max': max};
    }

    // Above / over / min / from
    final overRe = RegExp(
        r'(?:above|over|min|from|at least|more than)\s*(\d[\d,]*(?:\.\d+)?[mk]?)',
        caseSensitive: false);
    final overMatch = overRe.firstMatch(q);
    if (overMatch != null) {
      final min = parseAmount(overMatch.group(1)!);
      if (min != null) return {'min': min};
    }

    // Heuristic keywords
    if (RegExp(r'\bcheap\b|\baffordable\b|\bbudget\b|\blow[- ]cost\b').hasMatch(q)) {
      return {'max': 500000}; // TZS 500K heuristic
    }
    if (RegExp(r'\bluxury\b|\bpremium\b|\bexpensive\b|\bhigh[- ]end\b').hasMatch(q)) {
      return {'min': 5000000}; // TZS 5M heuristic
    }

    return null;
  }

  /// Extract location — returns original-case string for DB ilike match.
  String? _extractLocation(String q, String original) {
    // Tanzania cities & regions
    const knownLocations = [
      'dar es salaam', 'arusha', 'moshi', 'kilimanjaro', 'dodoma',
      'mwanza', 'zanzibar', 'tanga', 'morogoro', 'iringa', 'mbeya',
      'tabora', 'kigoma', 'lindi', 'mtwara', 'songea', 'musoma',
      'kibaha', 'bagamoyo', 'mikocheni', 'masaki', 'oyster bay',
      'kinondoni', 'ilala', 'temeke', 'kariakoo', 'upanga', 'msasani',
      'mbezi', 'tegeta', 'goba', 'bunju', 'kunduchi',
    ];

    for (final loc in knownLocations) {
      if (q.contains(loc)) {
        // Return properly-cased version
        final idx = q.indexOf(loc);
        return original.substring(idx, idx + loc.length);
      }
    }

    // Generic "in <place>" pattern
    final inPattern = RegExp(r'\bin\s+([A-Za-z][A-Za-z\s]{2,20})(?:\b|$)');
    final match = inPattern.firstMatch(original);
    if (match != null) {
      final place = match.group(1)?.trim();
      if (place != null && place.isNotEmpty) return place;
    }

    // "near <place>" pattern
    final nearPattern = RegExp(r'\bnear\s+([A-Za-z][A-Za-z\s]{2,20})(?:\b|$)');
    final nearMatch = nearPattern.firstMatch(original);
    if (nearMatch != null) {
      final place = nearMatch.group(1)?.trim();
      if (place != null && place.isNotEmpty) return place;
    }

    return null;
  }

  PropertyStatus? _extractStatus(String q) {
    if (RegExp(r'\bavailable\b|\bopen\b').hasMatch(q)) return PropertyStatus.available;
    if (RegExp(r'\bsold\b').hasMatch(q)) return PropertyStatus.sold;
    if (RegExp(r'\brented\b').hasMatch(q)) return PropertyStatus.rented;
    if (RegExp(r'\bpending\b').hasMatch(q)) return PropertyStatus.pending;
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUMMARY BUILDER
  // ══════════════════════════════════════════════════════════════════════════

  String _buildSummary(
    PropertyFilterEntity filter,
    PropertyType? type,
    PropertyCategory? category,
    Map<String, int>? bedrooms,
    Map<String, double>? price,
    String? location,
    PropertyStatus? status,
  ) {
    final parts = <String>[];

    if (bedrooms != null) {
      if (bedrooms['min'] != null && bedrooms['max'] != null &&
          bedrooms['min'] == bedrooms['max']) {
        parts.add('${bedrooms['min']}-bedroom');
      } else if (bedrooms['min'] != null && bedrooms['max'] == null) {
        parts.add('${bedrooms['min']}+ bedroom');
      } else if (bedrooms['min'] != null && bedrooms['max'] != null) {
        parts.add('${bedrooms['min']}–${bedrooms['max']} bedroom');
      }
    }

    if (category != null) parts.add(category.displayName.toLowerCase());
    if (type != null) parts.add('for ${type.displayName.toLowerCase()}');
    if (location != null) parts.add('in $location');

    if (price != null) {
      final f = _formatPrice;
      if (price['max'] != null && price['min'] == null) {
        parts.add('under ${f(price['max']!)}');
      } else if (price['min'] != null && price['max'] == null) {
        parts.add('above ${f(price['min']!)}');
      } else if (price['min'] != null && price['max'] != null) {
        parts.add('${f(price['min']!)}–${f(price['max']!)}');
      }
    }

    if (parts.isEmpty) return 'Showing all properties';
    return 'Showing ${parts.join(' ')}';
  }

  String _formatPrice(double p) {
    if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000)    return '${(p / 1000).toStringAsFixed(0)}K';
    return p.toStringAsFixed(0);
  }
}