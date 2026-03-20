import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/property_filter_entity.dart';

class PropertyFilterModel extends PropertyFilterEntity {
  const PropertyFilterModel({
    super.type,
    super.category,
    super.minPrice,
    super.maxPrice,
    super.minBedrooms,
    super.maxBedrooms,
    super.minBathrooms,
    super.maxBathrooms,
    super.minArea,
    super.maxArea,
    super.location,
    super.status,
    super.country,
  });

  factory PropertyFilterModel.fromEntity(PropertyFilterEntity entity) {
    return PropertyFilterModel(
      type: entity.type,
      category: entity.category,
      minPrice: entity.minPrice,
      maxPrice: entity.maxPrice,
      minBedrooms: entity.minBedrooms,
      maxBedrooms: entity.maxBedrooms,
      minBathrooms: entity.minBathrooms,
      maxBathrooms: entity.maxBathrooms,
      minArea: entity.minArea,
      maxArea: entity.maxArea,
      location: entity.location,
      status: entity.status,
      country: entity.country,
    );
  }

  Map<String, dynamic> toQueryParams() {
    final Map<String, dynamic> params = {};

    if (type != null) {
      params['type'] = type == PropertyType.sale ? 'sale' : 'rent';
    }
    if (category != null) {
      switch (category!) {
        case PropertyCategory.house:
          params['category'] = 'house';
          break;
        case PropertyCategory.apartment:
          params['category'] = 'apartment';
          break;
        case PropertyCategory.land:
          params['category'] = 'land';
          break;
        case PropertyCategory.commercial:
          params['category'] = 'commercial';
          break;
      }
    }
    if (minPrice != null) params['min_price'] = minPrice;
    if (maxPrice != null) params['max_price'] = maxPrice;
    if (minBedrooms != null) params['min_bedrooms'] = minBedrooms;
    if (maxBedrooms != null) params['max_bedrooms'] = maxBedrooms;
    if (minBathrooms != null) params['min_bathrooms'] = minBathrooms;
    if (maxBathrooms != null) params['max_bathrooms'] = maxBathrooms;
    if (minArea != null) params['min_area'] = minArea;
    if (maxArea != null) params['max_area'] = maxArea;
    if (location != null && location!.isNotEmpty) params['location'] = location;
    if (country != null && country!.isNotEmpty) params['country'] = country;
    if (status != null) {
      switch (status!) {
        case PropertyStatus.available:
          params['status'] = 'available';
          break;
        case PropertyStatus.sold:
          params['status'] = 'sold';
          break;
        case PropertyStatus.rented:
          params['status'] = 'rented';
          break;
        case PropertyStatus.pending:
          params['status'] = 'pending';
          break;
      }
    }

    return params;
  }
}



