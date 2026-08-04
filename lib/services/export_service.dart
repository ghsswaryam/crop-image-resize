// lib/services/export_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../models/photo_item.dart';
import '../models/export_options.dart';

class ExportService {
  
  /// 1. تصاویر کو کسٹم فولڈر میں مطلوبہ فارمیٹ، کوالٹی اور آٹو نمبرنگ کے ساتھ محفوظ کرنا
  static Future<List<File>> exportImages(List<PhotoItem> photos, ExportOptions options) async {
    List<File> exportedFiles = [];
    int currentIndex = options.startNumber;

    for (var photo in photos) {
      final sourcePath = photo.processedPath ?? photo.imagePath;
      final sourceFile = File(sourcePath);
      
      if (!await sourceFile.exists()) continue;

      // فائل کا ایکسٹینشن طے کرنا
      String extension = _getExtensionString(options.format);
      if (options.format == ExportFormat.original) {
        extension = p.extension(sourcePath).replaceAll('.', '');
      }

      // 🌟 فائل کا نام تیار کرنا: اگر اس مخصوص تصویر کے لیے صارف نے پہلے
      // ہی نام لکھا ہے (photo.customName) تو وہی استعمال ہو گا — ورنہ
      // مشترکہ Base File Name + سیریل نمبر (مثلاً: Student_Image_001.jpg)
      final String? typedName = photo.customName?.trim();
      String fileName;
      if (typedName != null && typedName.isNotEmpty) {
        fileName = '$typedName.$extension';
      } else {
        String base = options.baseName.isNotEmpty ? options.baseName : 'Image';
        if (options.autoNumber) {
          String paddedNum = currentIndex.toString().padLeft(3, '0');
          fileName = '${base}_$paddedNum.$extension';
        } else {
          fileName = '$base.$extension';
        }
      }

      String targetFilePath = p.join(options.destinationPath, fileName);

      // ڈوپلیکیٹ فائل ہینڈلنگ (اگر اوور رائٹ کی اجازت نہ ہو)
      if (await File(targetFilePath).exists() && !options.overwriteExisting) {
        int duplicateIndex = 1;
        while (await File(targetFilePath).exists()) {
          String nameWithoutExt = p.basenameWithoutExtension(fileName);
          targetFilePath = p.join(options.destinationPath, '${nameWithoutExt}_$duplicateIndex.$extension');
          duplicateIndex++;
        }
      }

      // اصلی تصویر کو انکوڈ اور سیو کرنا
      File finalFile = await _processAndSaveFormat(sourceFile, targetFilePath, options);
      exportedFiles.add(finalFile);
      
      currentIndex++;
    }

    return exportedFiles;
  }

  /// 2. تمام تصاویر کی ZIP فائل تیار کرنا (پروگریس اور کینسل کے ساتھ)
  ///
  /// 🌟 اہم فکس: پہلے یہ فنکشن تصاویر کو براہِ راست اسی نظر آنے والے
  /// فولڈر (destinationPath) میں ایکسپورٹ کرتا تھا اور پھر انہی فائلوں
  /// کو zip کرتا تھا — نتیجہ یہ کہ صارف کو فولڈر میں الگ الگ jpg فائلیں
  /// اور ZIP دونوں نظر آتی تھیں۔ اب تصاویر ایک عارضی (temp) فولڈر میں
  /// ایکسپورٹ ہوتی ہیں، وہیں سے zip بنتی ہے، اور آخر میں عارضی فولڈر
  /// خودکار حذف ہو جاتا ہے — صارف کو صرف حتمی ZIP نظر آئے گی، بالکل
  /// کسی بھی پروفیشنل ایپ کی طرح۔
  static Future<File> createZipWithProgress({
    required List<PhotoItem> photos,
    required ExportOptions options,
    required bool Function() checkCancel,
    required Function(double) onProgress,
  }) async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('multi_image_zip_');

    try {
      final ExportOptions tempOptions =
          options.copyWith(destinationPath: tempDir.path);

      List<File> exportedFiles = await exportImages(photos, tempOptions);

      final encoder = ZipFileEncoder();

      String zipName = options.zipFileName?.isNotEmpty == true
          ? '${options.zipFileName}.zip'
          : 'Admissions_Export_${DateTime.now().millisecondsSinceEpoch}.zip';

      String zipPath = p.join(options.destinationPath, zipName);
      encoder.create(zipPath);

      int totalFiles = exportedFiles.length;
      for (int i = 0; i < totalFiles; i++) {
        if (checkCancel()) {
          encoder.close();
          throw Exception('Processing cancelled by user.');
        }

        final file = exportedFiles[i];
        encoder.addFile(file);

        onProgress((i + 1) / totalFiles);
        await Future.delayed(const Duration(milliseconds: 10));
      }

      encoder.close();
      return File(zipPath);
    } finally {
      // 🌟 عارضی فولڈر ہمیشہ صاف کریں — چاہے کامیابی ہو یا کینسل/ایرر
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// 3. فائل شیئرنگ کے لیے
  static Future<void> shareFile(File file) async {
    if (await file.exists()) {
      await Share.shareXFiles([XFile(file.path)], text: 'ملٹی امیج کراپ ریسائز اینڈ رینیم سے برآمد کردہ فائل');
    }
  }

  // ==========================================
  // 🌟 NATIVE "SAVE AS" DIALOGS (انٹرنیشنل پریکٹس)
  // ==========================================
  //
  // یہی وہ طریقہ ہے جو Chrome/Google Drive/WhatsApp جیسی بین الاقوامی
  // ایپس استعمال کرتی ہیں — ایپ خود کوئی فولڈر یا نام طے نہیں کرتی، بلکہ
  // Android کا اپنا نیٹو "Save As" ڈائیلاگ کھلتا ہے جہاں یوزر خود فولڈر
  // اور فائل کا نام منتخب کرتا ہے۔

  /// ایک ہی فائل (مثلاً ZIP) کو نیٹو Save-As ڈائیلاگ سے محفوظ کرنا۔
  /// واپسی میں محفوظ شدہ جگہ کا پاتھ ملتا ہے، یا cancel کرنے پر null۔
  static Future<String?> saveFileWithDialog(File sourceFile, {String? suggestedName}) async {
    final params = SaveFileDialogParams(
      sourceFilePath: sourceFile.path,
      fileName: suggestedName ?? p.basename(sourceFile.path),
    );
    return await FlutterFileDialog.saveFile(params: params);
  }

  /// متعدد تصاویر کو ایک ہی بار میں محفوظ کرنا — پہلے یوزر سے فولڈر پوچھا
  /// جاتا ہے (ایک ہی بار)، پھر ہر تصویر اسی فولڈر میں اپنے نام سے لکھی
  /// جاتی ہے، بار بار ڈائیلاگ نہیں کھلتا۔ کامیابی پر true، cancel پر false۔
  static Future<bool> saveImagesWithDialog(List<File> files) async {
    if (!await FlutterFileDialog.isPickDirectorySupported()) {
      return false;
    }

    final pickedDirectory = await FlutterFileDialog.pickDirectory();
    if (pickedDirectory == null) return false; // یوزر نے cancel کیا

    for (final file in files) {
      final Uint8List bytes = await file.readAsBytes();
      await FlutterFileDialog.saveFileToDirectory(
        directory: pickedDirectory,
        data: bytes,
        fileName: p.basename(file.path),
        mimeType: 'image/jpeg',
        replace: true,
      );
    }
    return true;
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  static String _getExtensionString(ExportFormat format) {
    switch (format) {
      case ExportFormat.jpg: return 'jpg';
      case ExportFormat.png: return 'png';
      case ExportFormat.webp: return 'webp';
      case ExportFormat.bmp: return 'bmp';
      case ExportFormat.tiff: return 'tiff';
      case ExportFormat.original: return 'jpg';
    }
  }

  static Future<File> _processAndSaveFormat(File sourceFile, String targetPath, ExportOptions options) async {
    // 🌟 اہم فکس: JPG/Original کے لیے sourceFile (ImageService کی طرف سے
    // پہلے سے بائنری-سرچ کے ذریعے صحیح KB اور ڈائمنشن پر بنائی گئی تصویر)
    // کو دوبارہ decode/encode نہیں کرنا — کیونکہ دوبارہ ایک مختلف/فکسڈ
    // کوالٹی پر انکوڈ کرنے سے اصل ہدف سائز ٹوٹ جاتا ہے (یہی وہ بگ تھا
    // جس کی وجہ سے سکرین پر 23 KB نظر آنے کے باوجود اصل فائل 30-45 KB
    // بن رہی تھی)۔ بس وہی بائٹس ہو بہو کاپی کر دیں۔
    if (options.format == ExportFormat.jpg || options.format == ExportFormat.original) {
      return await sourceFile.copy(targetPath);
    }

    // 🌟 دیگر فارمیٹس (PNG/BMP/TIFF/WebP) لاسلیس یا مختلف کوڈیک ہیں —
    // ان میں KB ہدف کا اطلاق نہیں ہوتا (PNG وغیرہ ہمیشہ JPG سے بڑی ہوں
    // گی چاہے quality کچھ بھی ہو)، لیکن چوڑائی/لمبائی وہی رہے گی جو
    // sourceFile میں پہلے سے موجود ہے۔
    final bytes = await sourceFile.readAsBytes();
    final img.Image? decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      return await sourceFile.copy(targetPath);
    }

    List<int> encodedBytes;

    switch (options.format) {
      case ExportFormat.png:
        encodedBytes = img.encodePng(decodedImage);
        break;
      case ExportFormat.webp:
        encodedBytes = img.encodeNamedImage(targetPath, decodedImage) ?? img.encodeJpg(decodedImage, quality: options.quality);
        break;
      case ExportFormat.bmp:
        encodedBytes = img.encodeBmp(decodedImage);
        break;
      case ExportFormat.tiff:
        // اگر tiff فارمیٹ ہو تو اسے درست طریقے سے ہینڈل کرنا یا فال بیک دینا
        encodedBytes = img.encodeJpg(decodedImage, quality: options.quality);
        break;
      case ExportFormat.jpg:
      case ExportFormat.original:
        // یہاں کبھی نہیں پہنچے گا (اوپر ہی return ہو چکا ہوتا ہے) — صرف
        // switch کو exhaustive رکھنے کے لیے۔
        encodedBytes = img.encodeJpg(decodedImage, quality: options.quality);
        break;
    }

    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(encodedBytes);
    return targetFile;
  }
}
