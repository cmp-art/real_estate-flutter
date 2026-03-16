// lib/core/l10n/translation_helper.dart
// Helper functions and widgets for translations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:real_estate_app/features/settings/presentation/screens/app_translations.dart';
import '../../features/settings/presentation/providers/app_providers.dart';


// Helper function to get translation in non-widget contexts
String tr(String key, BuildContext context, WidgetRef ref) {
  final languageCode = ref.watch(languageProvider).languageCode;
  return AppTranslations.translate(key, languageCode);
}

// Translated Text Widget
class TrText extends ConsumerWidget {
  final String translationKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TrText(
    this.translationKey, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(languageProvider).languageCode;
    final translatedText = AppTranslations.translate(translationKey, languageCode);
    
    return Text(
      translatedText,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

// Extension for BuildContext to easily get translations
extension TranslationContext on BuildContext {
  String tr(String key, WidgetRef ref) {
    final languageCode = ref.watch(languageProvider).languageCode;
    return AppTranslations.translate(key, languageCode);
  }
}

// Mixin for easy translations in StatefulWidget
mixin TranslationMixin {
  String translate(String key, String languageCode) {
    return AppTranslations.translate(key, languageCode);
  }
}