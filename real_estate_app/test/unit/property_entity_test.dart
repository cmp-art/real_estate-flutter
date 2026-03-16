// test/unit/property_entity_test.dart
// Unit tests for PropertyEntity domain model — pure Dart, no widgets.

import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate_app/features/properties/domain/entities/property_entity.dart';
import 'package:real_estate_app/core/constants/app_constants.dart';

PropertyEntity _makeProperty({
  PropertyType type = PropertyType.sale,
  RentDuration? rentDuration,
  double price = 50000000,
  PropertyStatus status = PropertyStatus.available,
}) {
  return PropertyEntity(
    id: 'test-id-123',
    title: 'Test Property',
    description: 'A beautiful test property',
    price: price,
    type: type,
    category: PropertyCategory.house,
    location: 'Dar es Salaam',
    bedrooms: 3,
    bathrooms: 2,
    area: 120.0,
    images: const ['https://example.com/image.jpg'],
    ownerId: 'owner-id',
    ownerName: 'Test Owner',
    ownerTier: 'pro',
    status: status,
    rentDuration: rentDuration,
    createdAt: DateTime(2024, 1, 15),
    updatedAt: DateTime(2024, 1, 15),
  );
}

void main() {
  group('PropertyEntity basics', () {
    test('creates entity with required fields', () {
      final property = _makeProperty();
      expect(property.id, equals('test-id-123'));
      expect(property.title, equals('Test Property'));
      expect(property.price, equals(50000000));
      expect(property.bedrooms, equals(3));
    });

    test('images list is populated', () {
      final property = _makeProperty();
      expect(property.images, isNotEmpty);
      expect(property.images.first, contains('http'));
    });

    test('videos default to empty list', () {
      final property = _makeProperty();
      expect(property.videos, isEmpty);
    });

    test('ownerTier defaults correctly', () {
      final property = _makeProperty();
      expect(property.ownerTier, equals('pro'));
    });
  });

  group('PropertyEntity.priceSuffix', () {
    test('returns empty string for sale property', () {
      final property = _makeProperty(type: PropertyType.sale);
      expect(property.priceSuffix, equals(''));
    });

    test('returns /month for monthly rent', () {
      final property = _makeProperty(
        type: PropertyType.rent,
        rentDuration: RentDuration.monthly,
      );
      expect(property.priceSuffix, equals('/month'));
    });

    test('returns /year for yearly rent', () {
      final property = _makeProperty(
        type: PropertyType.rent,
        rentDuration: RentDuration.yearly,
      );
      expect(property.priceSuffix, equals('/year'));
    });
  });

  group('PropertyEntity.rentDurationDisplayText', () {
    test('returns empty for sale listing', () {
      final property = _makeProperty(type: PropertyType.sale);
      expect(property.rentDurationDisplayText, equals(''));
    });

    test('returns non-empty for rent listing', () {
      final property = _makeProperty(
        type: PropertyType.rent,
        rentDuration: RentDuration.monthly,
      );
      expect(property.rentDurationDisplayText, isNotEmpty);
    });
  });

  group('PropertyEntity equality (Equatable)', () {
    test('two properties with same id are equal', () {
      final p1 = _makeProperty();
      final p2 = _makeProperty();
      expect(p1, equals(p2));
    });

    test('properties with different prices are not equal', () {
      final p1 = _makeProperty(price: 50000000);
      final p2 = _makeProperty(price: 60000000);
      expect(p1, isNot(equals(p2)));
    });
  });

  group('PropertyStatus', () {
    test('available status is correctly set', () {
      final property = _makeProperty(status: PropertyStatus.available);
      expect(property.status, equals(PropertyStatus.available));
    });

    test('sold status is correctly set', () {
      final property = _makeProperty(status: PropertyStatus.sold);
      expect(property.status, equals(PropertyStatus.sold));
    });
  });
}
