import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

// Sentinel object used to distinguish "not passed" from "explicitly null"
// in copyWith calls, enabling individual filter fields to be cleared.
const _$unset = Object();

class PropertyFilterEntity extends Equatable {
  final PropertyType? type;
  final PropertyCategory? category;
  final double? minPrice;
  final double? maxPrice;
  final int? minBedrooms;
  final int? maxBedrooms;
  final int? minBathrooms;
  final int? maxBathrooms;
  final double? minArea;
  final double? maxArea;
  final String? location;
  final PropertyStatus? status;

  const PropertyFilterEntity({
    this.type,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.minBedrooms,
    this.maxBedrooms,
    this.minBathrooms,
    this.maxBathrooms,
    this.minArea,
    this.maxArea,
    this.location,
    this.status,
  });

  @override
  List<Object?> get props => [
        type,
        category,
        minPrice,
        maxPrice,
        minBedrooms,
        maxBedrooms,
        minBathrooms,
        maxBathrooms,
        minArea,
        maxArea,
        location,
        status,
      ];

  /// Supports clearing individual fields back to null by passing null explicitly.
  /// Example: filter.copyWith(type: null)  — clears the type filter.
  PropertyFilterEntity copyWith({
    Object? type = _$unset,
    Object? category = _$unset,
    Object? minPrice = _$unset,
    Object? maxPrice = _$unset,
    Object? minBedrooms = _$unset,
    Object? maxBedrooms = _$unset,
    Object? minBathrooms = _$unset,
    Object? maxBathrooms = _$unset,
    Object? minArea = _$unset,
    Object? maxArea = _$unset,
    Object? location = _$unset,
    Object? status = _$unset,
  }) {
    return PropertyFilterEntity(
      type:         identical(type, _$unset)         ? this.type         : type as PropertyType?,
      category:     identical(category, _$unset)     ? this.category     : category as PropertyCategory?,
      minPrice:     identical(minPrice, _$unset)     ? this.minPrice     : minPrice as double?,
      maxPrice:     identical(maxPrice, _$unset)     ? this.maxPrice     : maxPrice as double?,
      minBedrooms:  identical(minBedrooms, _$unset)  ? this.minBedrooms  : minBedrooms as int?,
      maxBedrooms:  identical(maxBedrooms, _$unset)  ? this.maxBedrooms  : maxBedrooms as int?,
      minBathrooms: identical(minBathrooms, _$unset) ? this.minBathrooms : minBathrooms as int?,
      maxBathrooms: identical(maxBathrooms, _$unset) ? this.maxBathrooms : maxBathrooms as int?,
      minArea:      identical(minArea, _$unset)      ? this.minArea      : minArea as double?,
      maxArea:      identical(maxArea, _$unset)      ? this.maxArea      : maxArea as double?,
      location:     identical(location, _$unset)     ? this.location     : location as String?,
      status:       identical(status, _$unset)       ? this.status       : status as PropertyStatus?,
    );
  }

  bool get hasActiveFilters {
    return type != null ||
        category != null ||
        minPrice != null ||
        maxPrice != null ||
        minBedrooms != null ||
        maxBedrooms != null ||
        minBathrooms != null ||
        maxBathrooms != null ||
        minArea != null ||
        maxArea != null ||
        location != null ||
        status != null;
  }

  PropertyFilterEntity clear() {
    return const PropertyFilterEntity();
  }
}