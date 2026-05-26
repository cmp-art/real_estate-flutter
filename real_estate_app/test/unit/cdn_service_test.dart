// test/unit/cdn_service_test.dart
// Unit tests for CdnService URL building — pure Dart, no network calls.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:patamjengo_app/core/services/cdn_service.dart';

const _fakeUrl = 'https://abcdefghijklmno.supabase.co';
const _objectUrl =
    '$_fakeUrl/storage/v1/object/public/property-images/uuid/photo.jpg';
const _renderBase =
    '$_fakeUrl/storage/v1/render/image/public/property-images/uuid/photo.jpg';

void main() {
  setUpAll(() {
    // Inject a fake SUPABASE_URL so CdnService can build URLs without a real .env
    dotenv.testLoad(fileInput: 'SUPABASE_URL=$_fakeUrl\n');
  });

  setUp(() {
    // These suites verify transform-URL building, which only runs when
    // transforms are enabled. Production defaults this to false (plan limit).
    CdnService.transformsEnabled = true;
  });

  group('CdnService.isCdnEnabled', () {
    test('is true when SUPABASE_URL is set', () {
      expect(CdnService.isCdnEnabled, isTrue);
    });
  });

  group('CdnService.getOptimizedImageUrl', () {
    test('rewrites object URL to render endpoint', () {
      final url = CdnService.getOptimizedImageUrl(_objectUrl, width: 300);
      expect(url, contains('/storage/v1/render/image/public/'));
      expect(url, isNot(contains('/storage/v1/object/public/')));
    });

    test('appends width query parameter', () {
      final url = CdnService.getOptimizedImageUrl(_objectUrl, width: 400);
      expect(url, contains('width=400'));
    });

    test('appends height query parameter', () {
      final url = CdnService.getOptimizedImageUrl(_objectUrl, height: 300);
      expect(url, contains('height=300'));
    });

    test('appends quality parameter', () {
      final url =
          CdnService.getOptimizedImageUrl(_objectUrl, quality: 70);
      expect(url, contains('quality=70'));
    });

    test('omits format when format is origin', () {
      final url = CdnService.getOptimizedImageUrl(_objectUrl, format: 'origin');
      expect(url, isNot(contains('format=')));
    });

    test('appends format when not origin', () {
      final url = CdnService.getOptimizedImageUrl(_objectUrl, format: 'webp');
      expect(url, contains('format=webp'));
    });

    test('handles bare bucket path', () {
      const barePath = 'property-images/uuid/photo.jpg';
      final url = CdnService.getOptimizedImageUrl(barePath, width: 300);
      expect(url, startsWith(_fakeUrl));
      expect(url, contains('/render/image/public/'));
      expect(url, contains('width=300'));
    });

    test('returns empty string for empty input', () {
      expect(CdnService.getOptimizedImageUrl(''), equals(''));
    });

    test('unknown external URL still gets quality param appended', () {
      const external = 'https://other.cdn.com/photo.jpg';
      final url = CdnService.getOptimizedImageUrl(external);
      expect(url, startsWith(external));
      expect(url, contains('quality='));
    });
  });

  group('CdnService preset sizes', () {
    test('getThumbnailUrl includes width=300', () {
      final url = CdnService.getThumbnailUrl(_objectUrl);
      expect(url, contains('width=300'));
      expect(url, contains('height=200'));
      expect(url, contains('quality=70'));
    });

    test('getMediumUrl includes width=800', () {
      final url = CdnService.getMediumUrl(_objectUrl);
      expect(url, contains('width=800'));
      expect(url, contains('height=600'));
    });

    test('getFullSizeUrl includes width=1280', () {
      final url = CdnService.getFullSizeUrl(_objectUrl);
      expect(url, contains('width=1280'));
      expect(url, contains('height=960'));
    });

    test('all presets point to render endpoint', () {
      for (final url in [
        CdnService.getThumbnailUrl(_objectUrl),
        CdnService.getMediumUrl(_objectUrl),
        CdnService.getFullSizeUrl(_objectUrl),
      ]) {
        expect(url, contains('/render/image/public/'),
            reason: '$url should use render endpoint');
      }
    });
  });

  group('CdnService.transformsEnabled = false (default in production)', () {
    test('getOptimizedImageUrl serves the plain object URL', () {
      CdnService.transformsEnabled = false;
      final url = CdnService.getOptimizedImageUrl(_objectUrl, width: 300);
      expect(url, contains('/storage/v1/object/public/'));
      expect(url, isNot(contains('/render/image/')));
      expect(url, isNot(contains('width=')));
    });

    test('presets serve object URLs (no transform, no 403 round-trip)', () {
      CdnService.transformsEnabled = false;
      for (final url in [
        CdnService.getThumbnailUrl(_objectUrl),
        CdnService.getMediumUrl(_objectUrl),
        CdnService.getFullSizeUrl(_objectUrl),
      ]) {
        expect(url, contains('/storage/v1/object/public/'));
        expect(url, isNot(contains('/render/image/')));
      }
    });
  });
}
