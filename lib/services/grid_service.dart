// lib/services/grid_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/photo_item.dart';
import '../models/grid_settings.dart';

class GridService {
  // 🛠️ حدیں ایک ہی جگہ constants کے طور پر تاکہ سب فنکشنز ہم آہنگ رہیں۔
  static const int _maxFileBytes = 50 * 1024 * 1024; // 50MB
  static const int _maxMegapixels = 64 * 1000 * 1000; // 64MP

  /// تصویر کا تجزیہ ورکر آئسولیٹ میں تاکہ مین سکرین فریز نہ ہو
  static Future<bool> validateImageDimensions(String filePath) async {
    return await compute(_checkDimensions, filePath);
  }

  static bool _checkDimensions(String path) {
    try {
      final file = File(path);
      if (file.lengthSync() > _maxFileBytes) return false;
      final image = img.decodeImage(file.readAsBytesSync());
      if (image == null) return false;
      if (image.width * image.height > _maxMegapixels) return false;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// تصویر کو گرڈ میں تقسیم کرنے کا کام
  static Future<List<PhotoItem>> splitGridInIsolate({
    required String filePath,
    required GridSettings settings,
  }) async {
    // 🛠️ FIX (Performance/Memory): فائل سائز کی حد یہاں سستے طریقے سے
    // (بغیر decode کیے) چیک ہو جاتی ہے، تاکہ بہت بڑی فائل isolate تک
    // پہنچنے سے پہلے ہی واضح پیغام کے ساتھ رد ہو جائے۔
    final int fileBytes = await File(filePath).length();
    if (fileBytes > _maxFileBytes) {
      throw Exception('تصویر کا سائز 50MB کی حد سے زیادہ ہے۔ براہِ کرم چھوٹی تصویر منتخب کریں۔');
    }

    final tempDir = await getTemporaryDirectory();
    // 🛠️ FIX (Bug/Type-Safety): Map<String, dynamic> کی بجائے typed class۔
    final task = _GridSplitTask(
      filePath: filePath,
      tempDirPath: tempDir.path,
      settings: settings,
    );
    return await compute(_handleSplitGrid, task);
  }

  static List<PhotoItem> _handleSplitGrid(_GridSplitTask task) {
    final GridSettings settings = task.settings;
    // 🛠️ FIX (Bug): rows/cols کے غلط (0 یا منفی) ہونے پر واضح خرابی۔
    if (settings.rows <= 0 || settings.cols <= 0) {
      throw Exception('Rows اور Cols کم از کم 1 ہونے چاہئیں-');
    }

    img.Image? image;
    try {
      image = img.decodeImage(File(task.filePath).readAsBytesSync());
      if (image == null) {
        throw Exception('تصویر پڑھی نہیں جا سکی — فائل خراب یا غیر معاون فارمیٹ ہے۔');
      }

      // 🛠️ FIX (Memory): decode کے فوراً بعد pixel-count حد چیک
      if (image.width * image.height > _maxMegapixels) {
        throw Exception('تصویر کا ریزولیوشن 64 میگا پکسل کی حد سے زیادہ ہے۔');
      }

      // 🛠️ FIX (Bug): EXIF orientation اپلائی کریں
      image = img.bakeOrientation(image);

      // مارجن نکال کر قابلِ استعمال جگہ کا حساب
      final int usableWidth = (image.width - settings.marginLeft - settings.marginRight).toInt();
      final int usableHeight = (image.height - settings.marginTop - settings.marginBottom).toInt();

      if (usableWidth <= 0 || usableHeight <= 0) {
        throw Exception('مارجن اتنے زیادہ ہیں کہ تصویر میں کوئی جگہ نہیں بچی۔');
      }

      // سیلز کا سائز مع اسپیسنگ
      final double rawCellWidth = (usableWidth - (settings.colSpacing * (settings.cols - 1))) / settings.cols;
      final double rawCellHeight = (usableHeight - (settings.rowSpacing * (settings.rows - 1))) / settings.rows;

      final int cellWidth = rawCellWidth.floor();
      final int cellHeight = rawCellHeight.floor();

      if (cellWidth <= 0 || cellHeight <= 0) {
        throw Exception('Rows/Cols یا Spacing زیادہ ہیں — ہر سیل کا سائز صفر یا منفی بن رہا ہے۔');
      }

      final List<PhotoItem> list = [];
      final int stamp = DateTime.now().millisecondsSinceEpoch;
      int counter = 1;

      for (int r = 0; r < settings.rows; r++) {
        for (int c = 0; c < settings.cols; c++) {
          // 🛠️ FIX (Bug): floor() کا مستقل استعمال
          final int startX = (settings.marginLeft + (c * (cellWidth + settings.colSpacing))).floor();
          final int startY = (settings.marginTop + (r * (cellHeight + settings.rowSpacing))).floor();

          img.Image? croppedCell;
          img.Image? resized;

          try {
            // کراپنگ
            croppedCell = img.copyCrop(
              image,
              x: startX,
              y: startY,
              width: cellWidth,
              height: cellHeight,
            );

            // ری سائزنگ (ٹارگٹ ڈائمنشنز کے مطابق)
            resized = img.copyResize(
              croppedCell,
              width: settings.targetWidth,
              height: settings.targetHeight,
            );

            final jpgBytes = img.encodeJpg(resized, quality: 90);
            final String uniqueId = 'photo_${stamp}_$counter';
            final String cropPath = '${task.tempDirPath}/$uniqueId.jpg';
            File(cropPath).writeAsBytesSync(jpgBytes);

            list.add(
              PhotoItem(
                id: uniqueId,
                name: 'student_${counter.toString().padLeft(3, '0')}',
                imagePath: cropPath,
                width: settings.targetWidth,
                height: settings.targetHeight,
                hash: uniqueId,
                rollNo: '',
              ),
            );
            counter++;
          } finally {
            // 🛠️ FIX (Memory): ہر سیل کا عارضی buffer فوراً آزاد کریں
            croppedCell?.clear();
            resized?.clear();
          }
        }
      }
      return list;
    } finally {
      image?.clear();
    }
  }
}

/// 🛠️ FIX (Type-Safety): Isolate ٹاسک ڈیٹا کلاس
class _GridSplitTask {
  final String filePath;
  final String tempDirPath;
  final GridSettings settings;

  const _GridSplitTask({
    required this.filePath,
    required this.tempDirPath,
    required this.settings,
  });
}
