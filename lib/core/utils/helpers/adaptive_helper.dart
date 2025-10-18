import 'package:flutter/material.dart';

/// Provides adaptive scaling for design dimensions across different screen sizes
class AdaptiveHelper {
  /// Reference design width (iPhone 16 Pro Max)
  static const double designWidth = 430;

  /// Reference design height (iPhone 16 Pro Max)
  static const double designHeight = 932;

  /// Minimum allowed font scale factor
  static const double fontScaleMin = 0.7;

  /// Maximum allowed font scale factor
  static const double fontScaleMax = 1.5;

  /// Converts design height to screen height
  static double height(BuildContext context, double pixels) {
    return MediaQuery.of(context).size.height * (pixels / designHeight);
  }

  /// Converts design width to screen width
  static double width(BuildContext context, double pixels) {
    return MediaQuery.of(context).size.width * (pixels / designWidth);
  }

  /// Converts design spacing to screen spacing
  static double spacing(BuildContext context, double pixels) {
    return MediaQuery.of(context).size.height * (pixels / designHeight);
  }

  /// Converts design corner radius to screen radius
  static double corner(BuildContext context, double pixels) {
    return MediaQuery.of(context).size.height * (pixels / designHeight);
  }

  /// Converts design font size to screen font size with limits
  static double text(BuildContext context, double pixels) {
    final scale = MediaQuery.of(context).size.width / designWidth;
    final bounded = scale.clamp(fontScaleMin, fontScaleMax);
    return pixels * bounded;
  }
}
