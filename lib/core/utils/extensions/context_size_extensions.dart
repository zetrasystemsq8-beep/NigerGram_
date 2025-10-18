import 'package:flutter/material.dart';
import 'package:flutter_video_feed/core/utils/helpers/adaptive_helper.dart';

/// Adds responsive sizing methods to BuildContext
extension ContextSizeExtensions on BuildContext {
  // MARK: - Dimensions

  /// Adaptive height scaling
  /// ```dart
  /// Container(height: h(100))
  /// ```
  double h(double pixels) => AdaptiveHelper.height(this, pixels);

  /// Adaptive width scaling
  /// ```dart
  /// Container(width: w(200))
  /// ```
  double w(double pixels) => AdaptiveHelper.width(this, pixels);

  /// Adaptive square dimension
  /// ```dart
  /// Icon(size: sq(24))
  /// ```
  double sq(double pixels) => AdaptiveHelper.width(this, pixels);

  /// Adaptive font size with boundaries
  /// ```dart
  /// TextStyle(fontSize: fontSize(16))
  /// ```
  double fontSize(double pixels) => AdaptiveHelper.text(this, pixels);

  // MARK: - Spacing

  /// Vertical spacing widget
  /// ```dart
  /// Column(children: [Text('A'), hSpace(16), Text('B')])
  /// ```
  SizedBox hSpace(double pixels) => SizedBox(height: h(pixels));

  /// Horizontal spacing widget
  /// ```dart
  /// Row(children: [Text('A'), wSpace(12), Text('B')])
  /// ```
  SizedBox wSpace(double pixels) => SizedBox(width: w(pixels));

  /// Empty space widget
  /// ```dart
  /// visible ? widget : empty()
  /// ```
  SizedBox empty() => const SizedBox.shrink();

  // MARK: - Padding

  /// Equal padding on all edges
  /// ```dart
  /// Container(padding: paddingAll(16))
  /// ```
  EdgeInsets paddingAll(double pixels) => EdgeInsets.all(_spacing(pixels));

  /// Padding on horizontal edges
  /// ```dart
  /// Container(padding: paddingHorizontal(20))
  /// ```
  EdgeInsets paddingHorizontal(double pixels) =>
      EdgeInsets.symmetric(horizontal: _spacing(pixels));

  /// Padding on vertical edges
  /// ```dart
  /// Container(padding: paddingVertical(12))
  /// ```
  EdgeInsets paddingVertical(double pixels) =>
      EdgeInsets.symmetric(vertical: _spacing(pixels));

  /// Padding on top edge only
  /// ```dart
  /// Container(padding: paddingTop(8))
  /// ```
  EdgeInsets paddingTop(double pixels) =>
      EdgeInsets.only(top: _spacing(pixels));

  /// Padding on bottom edge only
  /// ```dart
  /// Container(padding: paddingBottom(8))
  /// ```
  EdgeInsets paddingBottom(double pixels) =>
      EdgeInsets.only(bottom: _spacing(pixels));

  /// Padding on left edge only
  /// ```dart
  /// Container(padding: paddingLeft(12))
  /// ```
  EdgeInsets paddingLeft(double pixels) =>
      EdgeInsets.only(left: _spacing(pixels));

  /// Padding on right edge only
  /// ```dart
  /// Container(padding: paddingRight(12))
  /// ```
  EdgeInsets paddingRight(double pixels) =>
      EdgeInsets.only(right: _spacing(pixels));

  /// No padding
  /// ```dart
  /// Container(padding: paddingNone)
  /// ```
  EdgeInsets get paddingNone => EdgeInsets.zero;

  // MARK: - Radius

  /// Rounded corners on all sides
  /// ```dart
  /// Container(decoration: BoxDecoration(borderRadius: radiusAll(12)))
  /// ```
  BorderRadius radiusAll(double pixels) =>
      BorderRadius.circular(_corner(pixels));

  /// Rounded top corners
  /// ```dart
  /// borderRadius: radiusTop(8)
  /// ```
  BorderRadius radiusTop(double pixels) =>
      BorderRadius.vertical(top: Radius.circular(_corner(pixels)));

  /// Rounded bottom corners
  /// ```dart
  /// borderRadius: radiusBottom(8)
  /// ```
  BorderRadius radiusBottom(double pixels) =>
      BorderRadius.vertical(bottom: Radius.circular(_corner(pixels)));

  /// Rounded left corners
  /// ```dart
  /// borderRadius: radiusLeft(8)
  /// ```
  BorderRadius radiusLeft(double pixels) => BorderRadius.only(
        topLeft: Radius.circular(_corner(pixels)),
        bottomLeft: Radius.circular(_corner(pixels)),
      );

  /// Rounded right corners
  /// ```dart
  /// borderRadius: radiusRight(8)
  /// ```
  BorderRadius radiusRight(double pixels) => BorderRadius.only(
        topRight: Radius.circular(_corner(pixels)),
        bottomRight: Radius.circular(_corner(pixels)),
      );

  /// Rounded top-left corner
  /// ```dart
  /// borderRadius: radiusTopLeft(8)
  /// ```
  BorderRadius radiusTopLeft(double pixels) => BorderRadius.only(
        topLeft: Radius.circular(_corner(pixels)),
      );

  /// Rounded top-right corner
  /// ```dart
  /// borderRadius: radiusTopRight(8)
  /// ```
  BorderRadius radiusTopRight(double pixels) => BorderRadius.only(
        topRight: Radius.circular(_corner(pixels)),
      );

  /// Rounded bottom-left corner
  /// ```dart
  /// borderRadius: radiusBottomLeft(8)
  /// ```
  BorderRadius radiusBottomLeft(double pixels) => BorderRadius.only(
        bottomLeft: Radius.circular(_corner(pixels)),
      );

  /// Rounded bottom-right corner
  /// ```dart
  /// borderRadius: radiusBottomRight(8)
  /// ```
  BorderRadius radiusBottomRight(double pixels) => BorderRadius.only(
        bottomRight: Radius.circular(_corner(pixels)),
      );

  // MARK: - Private

  double _spacing(double pixels) => AdaptiveHelper.spacing(this, pixels);
  double _corner(double pixels) => AdaptiveHelper.corner(this, pixels);

  // MARK: - Device Info

  /// Safe area padding at screen top
  double get safeTop => MediaQuery.viewPaddingOf(this).top;

  /// Safe area padding at screen bottom
  double get safeBottom => MediaQuery.viewPaddingOf(this).bottom;

  /// Total screen width
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Total screen height
  double get screenHeight => MediaQuery.sizeOf(this).height;
}
