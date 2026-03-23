// lib/core/services/tflite_classifier_native.dart
//
// Native (Android / iOS / desktop) implementation.
// Contains the real TFLite model inference — NOT compiled on web.
// Imported only via the conditional export in tflite_classifier.dart.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void _tlog(String msg) {
  if (kDebugMode) debugPrint('[TFLite] $msg');
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT MODELS
// ─────────────────────────────────────────────────────────────────────────────

class LabelScore {
  final String label;
  final double score;
  const LabelScore(this.label, this.score);

  @override
  String toString() => '$label: ${(score * 100).toStringAsFixed(1)}%';
}

enum ImageCategory {
  realEstate,
  rejected,
  neutral,
}

class ImageClassificationResult {
  final List<LabelScore> topPredictions;
  final ImageCategory category;
  final String reason;
  final int confidence;

  const ImageClassificationResult({
    required this.topPredictions,
    required this.category,
    required this.reason,
    required this.confidence,
  });

  bool get isRealEstate => category == ImageCategory.realEstate;
  bool get isRejected   => category == ImageCategory.rejected;
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSIFIER
// ─────────────────────────────────────────────────────────────────────────────

class TFLiteClassifier {
  static const String _modelPath  = 'assets/ml/mobilenet_v3.tflite';
  static const String _labelsPath = 'assets/ml/imagenet_labels.txt';
  static const int    _inputSize  = 224;
  static const int    _topK       = 5;

  Interpreter?  _interpreter;
  List<String>  _labels      = [];
  bool          _initialized = false;
  String?       _initError;

  bool    get isInitialized => _initialized;
  String? get initError     => _initError;

  // ── Initialization ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initError = 'TFLite is not supported on web — rule-based fallback will be used';
      _tlog(_initError!);
      return;
    }

    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      final inShape  = _interpreter!.getInputTensor(0).shape;
      final outShape = _interpreter!.getOutputTensor(0).shape;
      _tlog('Model loaded — input: $inShape, output: $outShape');

      try {
        final raw = await rootBundle.loadString(_labelsPath);
        _labels = raw
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        _tlog('Labels loaded: ${_labels.length} classes');
      } catch (_) {
        _tlog('WARNING: imagenet_labels.txt not found in assets/ml/ — '
            'keyword matching disabled, using index-based fallback');
      }

      _initialized = true;
    } catch (e) {
      _initError = 'TFLite init failed: $e\n'
          'Ensure mobilenet_v3.tflite is in assets/ml/ and listed in pubspec.yaml assets.';
      _tlog(_initError!);
    }
  }

  // ── Classify ─────────────────────────────────────────────────────────────

  Future<ImageClassificationResult?> classify(XFile imageFile) async {
    if (!_initialized || _interpreter == null) {
      _tlog('Classifier not ready — skipping: ${imageFile.name}');
      return null;
    }

    try {
      final bytes   = await imageFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _tlog('Could not decode image: ${imageFile.name}');
        return null;
      }

      final resized   = img.copyResize(decoded, width: _inputSize, height: _inputSize);
      final inputData = Float32List(_inputSize * _inputSize * 3);
      for (final pixel in resized) {
        final idx = (pixel.y * _inputSize + pixel.x) * 3;
        inputData[idx]     = (pixel.r.toDouble() / 127.5) - 1.0;
        inputData[idx + 1] = (pixel.g.toDouble() / 127.5) - 1.0;
        inputData[idx + 2] = (pixel.b.toDouble() / 127.5) - 1.0;
      }

      final outputSize = _interpreter!.getOutputTensor(0).shape
          .reduce((a, b) => a * b);
      final outputData = Float32List(outputSize);

      _interpreter!.run(
        inputData.reshape([1, _inputSize, _inputSize, 3]),
        outputData.reshape([1, outputSize]),
      );

      final scores  = outputData.toList();
      final indexed = List.generate(scores.length, (i) => MapEntry(i, scores[i]));
      indexed.sort((a, b) => b.value.compareTo(a.value));

      final topK = indexed.take(_topK).map((e) {
        final name = _labelName(e.key);
        return LabelScore(name, e.value.clamp(0.0, 1.0));
      }).toList();

      _tlog('${imageFile.name} → top-3: ${topK.take(3).join(', ')}');

      return _categorize(topK);
    } catch (e) {
      _tlog('Classification error for ${imageFile.name}: $e');
      return null;
    }
  }

  // ── Categorization ───────────────────────────────────────────────────────

  ImageClassificationResult _categorize(List<LabelScore> topK) {
    for (final pred in topK) {
      if (_isRejectedLabel(pred.label) && pred.score > 0.30) {
        return ImageClassificationResult(
          topPredictions: topK,
          category:   ImageCategory.rejected,
          reason:     'Photo appears to show "${_humanize(pred.label)}" — '
                      'please upload a real property photo (room, exterior, or land).',
          confidence: (pred.score * 100).round().clamp(40, 98),
        );
      }
    }

    for (final pred in topK) {
      if (_isRealEstateLabel(pred.label) && pred.score > 0.18) {
        return ImageClassificationResult(
          topPredictions: topK,
          category:   ImageCategory.realEstate,
          reason:     'Photo appears to show property-related content.',
          confidence: (pred.score * 100).clamp(50, 90).round(),
        );
      }
    }

    return ImageClassificationResult(
      topPredictions: topK,
      category:   ImageCategory.neutral,
      reason:     'Image content is acceptable.',
      confidence: 65,
    );
  }

  // ── Label lookup ─────────────────────────────────────────────────────────

  String _labelName(int classIndex) {
    if (_labels.isNotEmpty && classIndex < _labels.length) {
      return _labels[classIndex];
    }
    return _fallbackLabelName(classIndex);
  }

  static bool _isRejectedLabel(String label) {
    final l = label.toLowerCase();
    return _rejectKeywords.any((k) => l.contains(k));
  }

  static bool _isRealEstateLabel(String label) {
    final l = label.toLowerCase();
    return _realEstateKeywords.any((k) => l.contains(k));
  }

  static String _humanize(String label) =>
      label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label;

  static const List<String> _rejectKeywords = [
    'sports car', 'convertible', 'taxicab', 'cab, hack',
    'minivan', 'minibus', 'school bus', 'trolleybus',
    'ambulance', 'fire engine', 'garbage truck', 'tow truck',
    'moving van', 'police van', 'passenger car', 'racer',
    'motor scooter', 'moped', 'go-kart',
    'bicycle', 'mountain bike',
    'airliner', 'warplane', 'helicopter',
    'speedboat', 'motor boat', 'warship',
    'tank, army',
    'pizza', 'cheeseburger', 'hotdog', 'hot dog',
    'french fries', 'mashed potato', 'burrito', 'trifle',
    'ice cream', 'ice lolly', 'bagel', 'pretzel',
    'banana', 'orange', 'lemon', 'fig', 'pineapple',
    'strawberry', 'pomegranate', 'broccoli', 'cauliflower',
    'mushroom', 'zucchini', 'bell pepper', 'head cabbage',
    'acorn squash', 'butternut squash', 'cucumber',
    'carbonara', 'meatloaf', 'potpie', 'guacamole',
    'consomme', 'chocolate sauce', 'red wine', 'espresso',
    'rifle', 'revolver', 'assault rifle', 'holster',
    'projectile, missile',
    'chihuahua', 'poodle', 'labrador', 'golden retriever',
    'german shepherd', 'bull mastiff', 'dalmatian',
    'egyptian cat', 'persian cat', 'siamese cat', 'tabby, tabby cat',
    'lion', 'tiger', 'cheetah', 'jaguar',
    'brown bear', 'ice bear', 'polar bear',
    'fox, reynard', 'timber wolf', 'coyote',
    'elephant', 'rhinoceros', 'hippopotamus',
    'monkey', 'baboon', 'chimpanzee', 'gorilla',
    'flamingo', 'penguin', 'parrot', 'macaw',
    'hamster', 'guinea pig', 'rabbit',
    'snake', 'king cobra', 'boa constrictor',
    'cellular telephone', 'cell phone',
    'laptop', 'notebook computer',
    'television', 'remote control',
    'joystick', 'computer keyboard',
    'jersey', 'sweatshirt', 'trench coat', 'fur coat',
    'gown', 'miniskirt', 'bikini',
    'sock', 'sandal', 'sneaker', 'running shoe',
  ];

  static const List<String> _realEstateKeywords = [
    'rocking chair', 'studio couch', 'couch', 'sofa',
    'desk', 'bookcase', 'wardrobe', 'chest',
    'dining table', 'coffee table',
    'four-poster', 'four poster',
    'refrigerator', 'fridge', 'stove', 'oven',
    'dishwasher', 'washer', 'dryer',
    'ceiling fan',
    'toilet seat', 'bathtub', 'shower',
    'medicine chest', 'bathroom',
    'swimming pool', 'hot tub', 'jacuzzi',
    'greenhouse', 'barn',
    'castle', 'palace', 'monastery', 'church',
    'balcony', 'porch', 'staircase', 'stairway',
    'window shade', 'sliding door', 'screen door',
    'picket fence', 'chain-link fence',
    'street sign',
    'parking meter',
    'lampshade', 'table lamp', 'floor lamp',
    'chandelier', 'sconce',
    'tile roof', 'thatch', 'flagpole',
  ];

  static String _fallbackLabelName(int index) {
    const Map<int, String> keyLabels = {
      409: 'ambulance',
      437: 'beach wagon, station wagon',
      468: 'cab, hack, taxi, taxicab',
      511: 'convertible',
      555: 'fire engine',
      569: 'garbage truck',
      609: 'minivan',
      627: 'moving van',
      656: 'minibus',
      675: 'motor scooter',
      705: 'passenger car',
      734: 'police van, police wagon',
      751: 'racer, race car',
      779: 'school bus',
      817: 'sports car',
      867: 'tow truck',
      444: 'bicycle',
      671: 'mountain bike',
      924: 'guacamole',
      925: 'consomme',
      928: 'ice cream',
      929: 'ice lolly',
      930: 'French loaf',
      931: 'bagel',
      932: 'pretzel',
      933: 'cheeseburger',
      934: 'hotdog',
      935: 'mashed potato',
      937: 'broccoli',
      939: 'orange',
      947: 'mushroom',
      949: 'strawberry',
      963: 'pizza',
      964: 'potpie',
      965: 'burrito',
      151: 'Chihuahua',
      281: 'tabby, tabby cat',
      290: 'lion',
      291: 'tiger',
      628: 'rifle',
      695: 'revolver',
      487: 'cellular telephone',
      620: 'laptop',
      765: 'rocking chair',
      831: 'studio couch',
      483: 'castle',
      698: 'palace',
      580: 'greenhouse',
    };
    return keyLabels[index] ?? 'class_$index';
  }

  // ── Feature vector extraction ─────────────────────────────────────────────

  Future<Float32List?> extractFeatureVector(XFile imageFile) async {
    if (!_initialized || _interpreter == null) return null;

    try {
      final bytes   = await imageFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final resized   = img.copyResize(decoded, width: _inputSize, height: _inputSize);
      final inputData = Float32List(_inputSize * _inputSize * 3);
      for (final pixel in resized) {
        final idx = (pixel.y * _inputSize + pixel.x) * 3;
        inputData[idx]     = (pixel.r.toDouble() / 127.5) - 1.0;
        inputData[idx + 1] = (pixel.g.toDouble() / 127.5) - 1.0;
        inputData[idx + 2] = (pixel.b.toDouble() / 127.5) - 1.0;
      }

      final outputSize = _interpreter!.getOutputTensor(0).shape.reduce((a, b) => a * b);
      final outputData = Float32List(outputSize);
      _interpreter!.run(
        inputData.reshape([1, _inputSize, _inputSize, 3]),
        outputData.reshape([1, outputSize]),
      );
      return outputData;
    } catch (e) {
      _tlog('Feature extraction error for ${imageFile.name}: $e');
      return null;
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  void dispose() {
    _interpreter?.close();
    _interpreter  = null;
    _initialized  = false;
    _initError    = null;
    _labels       = [];
  }
}
