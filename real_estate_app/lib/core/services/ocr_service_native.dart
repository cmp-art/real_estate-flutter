// lib/core/services/ocr_service_native.dart
//
// Native (Android / iOS) implementation.
// Uses Google ML Kit Text Recognition to extract names from ID cards and
// title deeds (Hati).  NOT compiled on web.
// Imported only via the conditional export in ocr_service.dart.

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

void _olog(String msg) {
  if (kDebugMode) debugPrint('[OCR] $msg');
}

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts the owner's name from [imageFile].
  /// Returns the extracted name string (trimmed), or null if recognition fails.
  Future<String?> extractName(XFile imageFile) async {
    if (kIsWeb) {
      _olog('ML Kit OCR not supported on web');
      return null;
    }

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final result     = await _recognizer.processImage(inputImage);
      final text       = result.text;

      _olog('Raw OCR (${imageFile.name}):\n$text');

      return _parseName(text);
    } catch (e) {
      _olog('OCR error for ${imageFile.name}: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }

  // ── Name parsing ────────────────────────────────────────────────────────

  String? _parseName(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    const nameLabels = [
      'JINA', 'JINA KAMILI', 'JINA LA MMILIKI', 'MMILIKI', 'MWENYE',
      'NAME', 'FULL NAME', 'OWNER', 'HOLDER',
      'REGISTERED TO', 'GRANTED TO', 'REGISTERED IN THE NAME OF',
    ];

    for (final label in nameLabels) {
      for (int i = 0; i < lines.length; i++) {
        final upper = lines[i].toUpperCase();
        if (upper.contains(label)) {
          final afterColon = _afterColon(lines[i]);
          if (afterColon != null && _looksLikeName(afterColon)) {
            _olog('Name found via label "$label" (same line): $afterColon');
            return afterColon;
          }
          if (i + 1 < lines.length && _looksLikeName(lines[i + 1])) {
            _olog('Name found via label "$label" (next line): ${lines[i + 1]}');
            return lines[i + 1];
          }
        }
      }
    }

    final capsLines = lines
        .where((l) => l == l.toUpperCase() && _looksLikeName(l))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (capsLines.isNotEmpty) {
      _olog('Name guessed from all-caps line: ${capsLines.first}');
      return capsLines.first;
    }

    final titleLines = lines
        .where((l) => _isTitleCase(l) && _looksLikeName(l))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (titleLines.isNotEmpty) {
      _olog('Name guessed from title-case line: ${titleLines.first}');
      return titleLines.first;
    }

    _olog('Could not extract a name from OCR text');
    return null;
  }

  String? _afterColon(String line) {
    final idx = line.indexOf(RegExp(r'[:–\-]'));
    if (idx == -1 || idx >= line.length - 1) return null;
    final after = line.substring(idx + 1).trim();
    return after.isEmpty ? null : after;
  }

  bool _looksLikeName(String text) {
    final cleaned = text.replaceAll(RegExp(r"['\-]"), ' ').trim();
    final tokens  = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 2 || tokens.length > 5) return false;
    for (final token in tokens) {
      if (token.length < 2 || token.length > 30) return false;
      if (!RegExp(r'^[A-Za-z]+$').hasMatch(token)) return false;
    }
    return true;
  }

  bool _isTitleCase(String text) {
    final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return tokens.every((t) => t.isNotEmpty && t[0] == t[0].toUpperCase());
  }
}

// ── Fuzzy name matching ──────────────────────────────────────────────────────

double fuzzyNameMatch(String a, String b) {
  final Set<String> tokensA = _nameTokens(a);
  final Set<String> tokensB = _nameTokens(b);

  if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

  final intersection = tokensA.intersection(tokensB).length;
  final union        = tokensA.union(tokensB).length;

  final score = (intersection / union) * 100.0;
  if (kDebugMode) {
    debugPrint('[OCR] fuzzyNameMatch: "$a" vs "$b" → '
        '$intersection/$union = ${score.toStringAsFixed(1)}%');
  }
  return score;
}

Set<String> _nameTokens(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z\s]"), '')
    .split(RegExp(r'\s+'))
    .where((t) => t.length >= 2)
    .toSet();
