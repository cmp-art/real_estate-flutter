// lib/core/utils/responsive_helper.dart
import 'package:flutter/material.dart';

/// Responsive helper utility for adapting UI to different screen sizes
/// 
/// Breakpoints:
/// - Mobile: < 600px
/// - Tablet: 600px - 1023px
/// - Desktop: >= 1024px
class ResponsiveHelper {
  // Private constructor to prevent instantiation
  ResponsiveHelper._();
  
  // Breakpoint constants
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  
  /// Check if device is mobile (phone)
  static bool isMobile(BuildContext context) {
    try {
      return MediaQuery.of(context).size.width < mobileBreakpoint;
    } catch (e) {
      debugPrint('ResponsiveHelper.isMobile error: $e');
      return true; // Default to mobile if error
    }
  }
  
  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    try {
      final width = MediaQuery.of(context).size.width;
      return width >= mobileBreakpoint && width < tabletBreakpoint;
    } catch (e) {
      debugPrint('ResponsiveHelper.isTablet error: $e');
      return false;
    }
  }
  
  /// Check if device is desktop/web
  static bool isDesktop(BuildContext context) {
    try {
      return MediaQuery.of(context).size.width >= tabletBreakpoint;
    } catch (e) {
      debugPrint('ResponsiveHelper.isDesktop error: $e');
      return false;
    }
  }
  
  /// Check if device is tablet or larger
  static bool isTabletOrLarger(BuildContext context) {
    try {
      return MediaQuery.of(context).size.width >= mobileBreakpoint;
    } catch (e) {
      debugPrint('ResponsiveHelper.isTabletOrLarger error: $e');
      return false;
    }
  }
  
  /// Get responsive padding based on screen size
  static double getResponsivePadding(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    return 32.0; // Desktop
  }
  
  /// Get responsive horizontal padding
  static double getResponsiveHorizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 32.0;
    return 48.0; // Desktop
  }
  
  /// Get responsive font size with fallbacks
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? (mobile * 1.2);
    if (isTablet(context)) return tablet ?? (mobile * 1.1);
    return mobile;
  }
  
  /// Get maximum content width for readability
  /// - Mobile: full width
  /// - Tablet: 768px
  /// - Desktop: 1200px (forms/lists), 1600px (grids)
  static double getMaxContentWidth(
    BuildContext context, {
    bool isWide = false,
  }) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 768.0;
    return isWide ? 1600.0 : 1200.0; // Desktop
  }
  
  /// Get maximum form width (for centered forms)
  static double getMaxFormWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 600.0;
    return 500.0; // Desktop - forms should be narrow
  }
  
  /// Get number of grid columns based on screen size
  static int getGridColumns(
    BuildContext context, {
    int? mobile,
    int? tablet,
    int? desktop,
  }) {
    if (isMobile(context)) return mobile ?? 1;
    if (isTablet(context)) return tablet ?? 2;
    return desktop ?? 3; // Desktop
  }
  
  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context) {
    if (isMobile(context)) return 24.0;
    if (isTablet(context)) return 28.0;
    return 32.0; // Desktop
  }
  
  /// Get responsive avatar size
  static double getResponsiveAvatarSize(BuildContext context) {
    if (isMobile(context)) return 40.0;
    if (isTablet(context)) return 48.0;
    return 56.0; // Desktop
  }
  
  /// Get responsive card elevation
  static double getResponsiveElevation(BuildContext context) {
    if (isMobile(context)) return 2.0;
    if (isTablet(context)) return 4.0;
    return 6.0; // Desktop
  }
  
  /// Get responsive spacing
  static double getResponsiveSpacing(
    BuildContext context, {
    double multiplier = 1.0,
  }) {
    final base = isMobile(context) 
        ? 8.0 
        : (isTablet(context) ? 12.0 : 16.0);
    return base * multiplier;
  }
  
  /// Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context) {
    if (isMobile(context)) return 8.0;
    if (isTablet(context)) return 12.0;
    return 16.0; // Desktop
  }
  
  /// Check if should use compact layout
  static bool shouldUseCompactLayout(BuildContext context) {
    return isMobile(context);
  }
  
  /// Get screen width
  static double getScreenWidth(BuildContext context) {
    try {
      return MediaQuery.of(context).size.width;
    } catch (e) {
      debugPrint('ResponsiveHelper.getScreenWidth error: $e');
      return 360.0; // Default mobile width
    }
  }
  
  /// Get screen height
  static double getScreenHeight(BuildContext context) {
    try {
      return MediaQuery.of(context).size.height;
    } catch (e) {
      debugPrint('ResponsiveHelper.getScreenHeight error: $e');
      return 640.0; // Default mobile height
    }
  }
  
  /// Get responsive dialog width
  static double getDialogWidth(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (isMobile(context)) return screenWidth * 0.9;
    if (isTablet(context)) return 500.0;
    return 600.0; // Desktop
  }
  
  /// Get responsive bottom sheet max height
  static double getBottomSheetMaxHeight(BuildContext context) {
    return getScreenHeight(context) * 0.9;
  }
  
  /// Get responsive list tile height
  static double getListTileHeight(BuildContext context) {
    if (isMobile(context)) return 72.0;
    if (isTablet(context)) return 80.0;
    return 88.0; // Desktop
  }
  
  /// Get app bar height based on device
  static double getAppBarHeight(BuildContext context) {
    if (isMobile(context)) return kToolbarHeight;
    return kToolbarHeight + 8.0; // Slightly taller on larger screens
  }

  /// Is device in landscape orientation?
  static bool isLandscape(BuildContext context) {
    try {
      return MediaQuery.of(context).orientation == Orientation.landscape;
    } catch (_) {
      return false;
    }
  }

  /// Property grid columns — adapts to orientation and screen class
  /// Phone landscape gets 2 cols; tablet landscape gets 3; desktop 4.
  static int getPropertyGridColumns(BuildContext context) {
    final width = getScreenWidth(context);
    if (width >= 1400) return 4;   // Large desktop / 4K
    if (width >= tabletBreakpoint) return 3;   // Desktop / laptop
    if (width >= mobileBreakpoint) return 2;   // Tablet portrait+landscape
    if (isLandscape(context))      return 2;   // Phone landscape
    return 1;                                   // Phone portrait
  }

  /// Returns a safe area-aware horizontal padding for scrollable content.
  /// On web/desktop adds extra gutters so content doesn't stretch edge-to-edge.
  static double getContentHorizontalPadding(BuildContext context) {
    final width = getScreenWidth(context);
    if (width >= 1400) return (width - 1320) / 2; // Centre on very wide screens
    if (width >= tabletBreakpoint) return 40.0;
    if (width >= mobileBreakpoint) return 24.0;
    return 16.0;
  }

  /// Clamps a value between min and max — convenience method.
  static double clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }
}

/// Responsive container that limits width on large screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool center;
  final EdgeInsetsGeometry? padding;
  
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.center = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? ResponsiveHelper.getMaxContentWidth(context),
      ),
      padding: padding,
      child: child,
    );
    
    return center ? Center(child: content) : content;
  }
}

/// Responsive padding wrapper
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final bool horizontal;
  final bool vertical;
  
  const ResponsivePadding({
    super.key,
    required this.child,
    this.horizontal = true,
    this.vertical = true,
  });

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveHelper.getResponsivePadding(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal ? padding : 0,
        vertical: vertical ? padding : 0,
      ),
      child: child,
    );
  }
}

/// Responsive grid or list based on screen size
class ResponsiveGridList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;
  final double? childAspectRatio;
  final ScrollPhysics? physics;
  
  const ResponsiveGridList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.childAspectRatio,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final columns = ResponsiveHelper.getGridColumns(context);
    final responsivePadding = padding ?? EdgeInsets.all(
      ResponsiveHelper.getResponsivePadding(context),
    );
    
    if (isMobile || columns == 1) {
      // Use ListView for mobile
      return ListView.builder(
        padding: responsivePadding,
        physics: physics,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: mainAxisSpacing ?? 16.0,
            ),
            child: itemBuilder(context, index),
          );
        },
      );
    }
    
    // Use GridView for tablet/desktop
    return GridView.builder(
      padding: responsivePadding,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: crossAxisSpacing ?? 16.0,
        mainAxisSpacing: mainAxisSpacing ?? 16.0,
        childAspectRatio: childAspectRatio ?? 1.0,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}