// lib/models/grid_settings.dart
import 'package:flutter/foundation.dart';
import 'export_options.dart';

@immutable
class GridSettings {
  final int rows;
  final int cols;
  final int targetWidth;
  final int targetHeight;
  final int targetKB;
  final int quality;
  final ExportFormat format;
  
  // Internal Fields
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final double rowSpacing;
  final double colSpacing;
  final double borderWidth;

  const GridSettings({
    this.rows = 5,
    this.cols = 4,
    this.targetWidth = 600,
    this.targetHeight = 800,
    this.targetKB = 100,
    this.quality = 85,
    this.format = ExportFormat.jpg,
    this.marginTop = 0,
    this.marginBottom = 0,
    this.marginLeft = 0,
    this.marginRight = 0,
    this.rowSpacing = 0,
    this.colSpacing = 0,
    this.borderWidth = 1.0,
  });

  // --- 🌟 Compatibility Getters ---
  int get width => targetWidth;
  int get height => targetHeight;

  double get topMargin => marginTop;
  double get bottomMargin => marginBottom;
  double get leftMargin => marginLeft;
  double get rightMargin => marginRight;

  double get rowSpace => rowSpacing;
  double get colSpace => colSpacing;

  // --- 🌟 Dual-Support copyWith Method ---
  GridSettings copyWith({
    int? rows,
    int? cols,
    int? targetWidth,
    int? targetHeight,
    int? width,
    int? height,
    int? targetKB,
    int? quality,
    ExportFormat? format,

    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,

    double? topMargin,
    double? bottomMargin,
    double? leftMargin,
    double? rightMargin,

    double? rowSpacing,
    double? colSpacing,

    double? rowSpace,
    double? colSpace,

    double? borderWidth,
  }) {
    return GridSettings(
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      targetWidth: targetWidth ?? width ?? this.targetWidth,
      targetHeight: targetHeight ?? height ?? this.targetHeight,
      targetKB: targetKB ?? this.targetKB,
      quality: quality ?? this.quality,
      format: format ?? this.format,

      marginTop: marginTop ?? topMargin ?? this.marginTop,
      marginBottom: marginBottom ?? bottomMargin ?? this.marginBottom,
      marginLeft: marginLeft ?? leftMargin ?? this.marginLeft,
      marginRight: marginRight ?? rightMargin ?? this.marginRight,

      rowSpacing: rowSpacing ?? rowSpace ?? this.rowSpacing,
      colSpacing: colSpacing ?? colSpace ?? this.colSpacing,

      borderWidth: borderWidth ?? this.borderWidth,
    );
  }
}
