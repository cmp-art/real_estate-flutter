// core/services/image_compression_service.dart
// Compress images before upload to reduce egress

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressionService {
  /// Compress image to JPEG with quality 75 and max dimension 1920px
  /// Target size: < 500KB per image
  static Future<File?> compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      final splitPath = filePath.substring(0, lastIndex);
      final outPath = '${splitPath}_compressed.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 75,  // 75% quality - good balance
        minWidth: 1920,  // Max width 1920px
        minHeight: 1920,  // Max height 1920px
        format: CompressFormat.jpeg,  // Always convert to JPEG
      );
      
      if (result == null) {
        return null;
      }
      
      // Check if compressed file is still too large
      final compressedFile = File(result.path);
      final fileSize = await compressedFile.length();
      
      // If still > 1MB, compress more aggressively
      if (fileSize > 1024 * 1024) {
        final result2 = await FlutterImageCompress.compressAndGetFile(
          compressedFile.absolute.path,
          '${splitPath}_compressed2.jpg',
          quality: 60,  // Lower quality
          minWidth: 1280,  // Smaller dimensions
          minHeight: 1280,
          format: CompressFormat.jpeg,
        );
        
        // Delete intermediate file
        await compressedFile.delete();
        
        return result2 != null ? File(result2.path) : null;
      }
      
      return compressedFile;
    } catch (e) {
      if (kDebugMode) debugPrint('Image compression error: $e');
      return null;
    }
  }
  
  /// Compress multiple images
  static Future<List<File>> compressImages(List<File> files) async {
    final List<File> compressedFiles = [];
    
    for (final file in files) {
      final compressed = await compressImage(file);
      if (compressed != null) {
        compressedFiles.add(compressed);
      } else {
        // If compression fails, use original but warn
        if (kDebugMode) debugPrint('Warning: Failed to compress ${file.path}, using original');
        compressedFiles.add(file);
      }
    }
    
    return compressedFiles;
  }
  
  /// Get file size in MB
  static Future<double> getFileSizeMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }
  
  /// Check if file exceeds size limit
  static Future<bool> exceedsSizeLimit(File file, double maxMB) async {
    final sizeMB = await getFileSizeMB(file);
    return sizeMB > maxMB;
  }
  
  /// Compress image to thumbnail (400x400, quality 60)
  static Future<File?> compressToThumbnail(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = file.path.split('/').last.split('.').first;
      final outPath = '${tempDir.path}/${fileName}_thumb.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 60,
        minWidth: 400,
        minHeight: 400,
        format: CompressFormat.jpeg,
      );
      
      return result != null ? File(result.path) : null;
    } catch (e) {
      if (kDebugMode) debugPrint('Thumbnail compression error: $e');
      return null;
    }
  }
}