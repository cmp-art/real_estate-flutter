// lib/core/services/tflite_classifier.dart
//
// MobileNet V3 TFLite Image Classifier
// ======================================
//
// On-device image classification — no API key, no network call, no cost per image.
//
// REQUIRED SETUP (one-time):
//   1. Download the TFLite model and labels into assets/ml/:
//
//      Model (pick one):
//        Small (~2.5 MB, faster): mobilenet_v3_small_100_224_int8_1.tflite
//        Large (~5.4 MB, better): mobilenet_v3_large_100_224_int8_1.tflite
//        → Download from: https://tfhub.dev/google/lite-model/imagenet/
//          mobilenet_v3_small_100_224/classification/5/int8/1
//        → Rename to: mobilenet_v3.tflite
//
//      Labels:
//        → https://storage.googleapis.com/download.tensorflow.org/data/ImageNetLabels.txt
//        → Save as: imagenet_labels.txt
//
//   2. Place both files in: real_estate_app/assets/ml/
//
//   3. pubspec.yaml assets section must include:
//        - assets/ml/
//
//   4. Dependencies (pubspec.yaml):
//        tflite_flutter: ^0.10.4
//        image: ^4.1.7
//
// MODEL INPUT/OUTPUT:
//   Input  : [1, 224, 224, 3] float32, values in [-1.0, 1.0]
//   Output : [1, 1001] float32 — softmax probabilities
//             Index 0 = background, 1–1000 = ImageNet classes

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
  /// Clearly a real-estate image (room, building, land, etc.).
  realEstate,

  /// Clearly NOT real estate (vehicle, food, weapon, etc.) → reject.
  rejected,

  /// No strong signal either way → treat as acceptable (neutral pass).
  neutral,
}

class ImageClassificationResult {
  final List<LabelScore> topPredictions;
  final ImageCategory category;
  final String reason;

  /// Confidence 0–100.
  final int confidence;

  const ImageClassificationResult({
    required this.topPredictions,
    required this.category,
    required this.reason,
    required this.confidence,
  });

  bool get isRealEstate => category == ImageCategory.realEstate;
  bool get isRejected => category == ImageCategory.rejected;
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
      // Load TFLite interpreter from bundled model asset.
      _interpreter = await Interpreter.fromAsset(_modelPath);
      final inShape  = _interpreter!.getInputTensor(0).shape;
      final outShape = _interpreter!.getOutputTensor(0).shape;
      _tlog('Model loaded — input: $inShape, output: $outShape');

      // Load ImageNet labels (optional but required for keyword matching).
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

  /// Classifies [imageFile] and returns the validation result.
  /// Returns null if the model is not initialized or the image cannot be decoded.
  Future<ImageClassificationResult?> classify(XFile imageFile) async {
    if (!_initialized || _interpreter == null) {
      _tlog('Classifier not ready — skipping: ${imageFile.name}');
      return null;
    }

    try {
      // 1. Decode image.
      final bytes   = await imageFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _tlog('Could not decode image: ${imageFile.name}');
        return null;
      }

      // 2. Resize to 224×224.
      final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);

      // 3. Normalize pixels to [-1.0, 1.0] (MobileNet V3 convention).
      final inputData = Float32List(_inputSize * _inputSize * 3);
      for (final pixel in resized) {
        final idx = (pixel.y * _inputSize + pixel.x) * 3;
        inputData[idx]     = (pixel.r.toDouble() / 127.5) - 1.0;
        inputData[idx + 1] = (pixel.g.toDouble() / 127.5) - 1.0;
        inputData[idx + 2] = (pixel.b.toDouble() / 127.5) - 1.0;
      }

      // 4. Run inference.
      final outputSize = _interpreter!.getOutputTensor(0).shape
          .reduce((a, b) => a * b);
      final outputData = Float32List(outputSize);

      _interpreter!.run(
        inputData.reshape([1, _inputSize, _inputSize, 3]),
        outputData.reshape([1, outputSize]),
      );

      // 5. Find top-K predictions.
      final scores  = outputData.toList();
      final indexed = List.generate(scores.length, (i) => MapEntry(i, scores[i]));
      indexed.sort((a, b) => b.value.compareTo(a.value));

      final topK = indexed.take(_topK).map((e) {
        final name = _labelName(e.key);
        return LabelScore(name, e.value.clamp(0.0, 1.0));
      }).toList();

      _tlog('${imageFile.name} → top-3: ${topK.take(3).join(', ')}');

      // 6. Categorize.
      return _categorize(topK);
    } catch (e) {
      _tlog('Classification error for ${imageFile.name}: $e');
      return null;
    }
  }

  // ── Categorization ───────────────────────────────────────────────────────

  ImageClassificationResult _categorize(List<LabelScore> topK) {
    // Check top predictions for reject categories.
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

    // Check for positive real-estate indicators.
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

    // No strong signal → neutral pass (acceptable by default).
    return ImageClassificationResult(
      topPredictions: topK,
      category:   ImageCategory.neutral,
      reason:     'Image content is acceptable.',
      confidence: 65,
    );
  }

  // ── Label lookup ─────────────────────────────────────────────────────────

  String _labelName(int classIndex) {
    // If labels were loaded from asset, use them.
    if (_labels.isNotEmpty && classIndex < _labels.length) {
      return _labels[classIndex];
    }
    // Fall back to index-based lookup for key classes.
    return _fallbackLabelName(classIndex);
  }

  // ── Keyword lists ────────────────────────────────────────────────────────

  /// Returns true if [label] indicates a category that should cause rejection.
  static bool _isRejectedLabel(String label) {
    final l = label.toLowerCase();
    return _rejectKeywords.any((k) => l.contains(k));
  }

  /// Returns true if [label] positively indicates real-estate content.
  static bool _isRealEstateLabel(String label) {
    final l = label.toLowerCase();
    return _realEstateKeywords.any((k) => l.contains(k));
  }

  static String _humanize(String label) =>
      label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label;

  // ─────────────────────────────────────────────────────────────────────────
  // REJECT KEYWORDS
  // Substrings matched against ImageNet class labels (case-insensitive).
  // ─────────────────────────────────────────────────────────────────────────
  static const List<String> _rejectKeywords = [
    // ── Vehicles ──
    'sports car', 'convertible', 'taxicab', 'cab, hack',
    'minivan', 'minibus', 'school bus', 'trolleybus',
    'ambulance', 'fire engine', 'garbage truck', 'tow truck',
    'moving van', 'police van', 'passenger car', 'racer',
    'motor scooter', 'moped', 'go-kart',
    'bicycle', 'mountain bike',
    'airliner', 'warplane', 'helicopter',
    'speedboat', 'motor boat', 'warship',
    'tank, army',
    // ── Food ──
    'pizza', 'cheeseburger', 'hotdog', 'hot dog',
    'french fries', 'mashed potato', 'burrito', 'trifle',
    'ice cream', 'ice lolly', 'bagel', 'pretzel',
    'banana', 'orange', 'lemon', 'fig', 'pineapple',
    'strawberry', 'pomegranate', 'broccoli', 'cauliflower',
    'mushroom', 'zucchini', 'bell pepper', 'head cabbage',
    'acorn squash', 'butternut squash', 'cucumber',
    'carbonara', 'meatloaf', 'potpie', 'guacamole',
    'consomme', 'chocolate sauce', 'red wine', 'espresso',
    // ── Weapons ──
    'rifle', 'revolver', 'assault rifle', 'holster',
    'projectile, missile',
    // ── Animals ──
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
    // ── Electronics ──
    'cellular telephone', 'cell phone',
    'laptop', 'notebook computer',
    'television', 'remote control',
    'joystick', 'computer keyboard',
    // ── Clothing / fashion ──
    'jersey', 'sweatshirt', 'trench coat', 'fur coat',
    'gown', 'miniskirt', 'bikini',
    'sock', 'sandal', 'sneaker', 'running shoe',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // REAL-ESTATE KEYWORDS
  // Positive indicators that the image shows property-related content.
  // ─────────────────────────────────────────────────────────────────────────
  static const List<String> _realEstateKeywords = [
    // ── Interior furniture ──
    'rocking chair', 'studio couch', 'couch', 'sofa',
    'desk', 'bookcase', 'wardrobe', 'chest',
    'dining table', 'coffee table',
    'four-poster', 'four poster',
    // ── Appliances ──
    'refrigerator', 'fridge', 'stove', 'oven',
    'dishwasher', 'washer', 'dryer',
    'ceiling fan',
    // ── Bathroom ──
    'toilet seat', 'bathtub', 'shower',
    'medicine chest', 'bathroom',
    // ── Outdoor / architecture ──
    'swimming pool', 'hot tub', 'jacuzzi',
    'greenhouse', 'barn',
    'castle', 'palace', 'monastery', 'church',
    'balcony', 'porch', 'staircase', 'stairway',
    'window shade', 'sliding door', 'screen door',
    'picket fence', 'chain-link fence',
    'street sign',    // indicates urban/neighbourhood
    'parking meter',  // street-level property context
    // ── Lighting ──
    'lampshade', 'table lamp', 'floor lamp',
    'chandelier', 'sconce',
    // ── Flooring / walls ──
    'tile roof', 'thatch', 'flagpole',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // FALLBACK LABEL NAMES
  // Used when imagenet_labels.txt is not found in assets.
  // Only covers key classes relevant to real-estate validation.
  // Full list: https://storage.googleapis.com/download.tensorflow.org/data/ImageNetLabels.txt
  // ─────────────────────────────────────────────────────────────────────────
  static String _fallbackLabelName(int index) {
    const Map<int, String> keyLabels = {
      // Vehicles
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
      // Bikes
      444: 'bicycle',
      671: 'mountain bike',
      // Food
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
      // Animals
      151: 'Chihuahua',
      281: 'tabby, tabby cat',
      290: 'lion',
      291: 'tiger',
      // Weapons
      628: 'rifle',
      695: 'revolver',
      // Electronics
      487: 'cellular telephone',
      620: 'laptop',
      // Interior (positive)
      765: 'rocking chair',
      831: 'studio couch',
      // Architecture (positive)
      483: 'castle',
      698: 'palace',
      580: 'greenhouse',
    };
    return keyLabels[index] ?? 'class_$index';
  }

  // ── Feature vector extraction ─────────────────────────────────────────────
  // Returns the raw softmax output (1001-dim) for a given image.
  // Used by PhotoSimilarityService to compute cosine similarity between photos.

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
