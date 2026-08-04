// lib/services/image_service.dart
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/photo_item.dart';
import '../models/grid_settings.dart';

/// 🌟 لائیو پروگریس اور ای ٹی اے (ETA) کے لیے کلاس
class ImageProcessingProgress {
  final int processedCount;
  final int totalCount;
  final String currentFileName;
  final String estimatedTimeLeft;
  final int elapsedMs;

  ImageProcessingProgress({
    required this.processedCount,
    required this.totalCount,
    required this.currentFileName,
    required this.estimatedTimeLeft,
    required this.elapsedMs,
  });
}

/// 🌟 compute() آئسولیٹ کو بھیجنے کے لیے ان پٹ — decode/crop/resize/encode
/// کا سارا بھاری (pure-Dart, synchronous) کام اب یہاں الگ بیک گراؤنڈ
/// آئسولیٹ میں چلتا ہے، مین UI آئسولیٹ کو مصروف کیے بغیر۔
class _DecodeResizeInput {
  final Uint8List bytes;
  final int width;
  final int height;
  final double rotation;
  const _DecodeResizeInput({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rotation,
  });
}

class _DecodeResizeResult {
  final Uint8List? pngBytes;
  final int width;
  final int height;
  const _DecodeResizeResult({this.pngBytes, this.width = 0, this.height = 0});
}

/// 🌟 یہ فنکشن بیک گراؤنڈ آئسولیٹ میں چلتا ہے (compute() کے ذریعے)۔
/// یہی وہ اصل بھاری کام ہے (decode → orient → rotate → crop → resize →
/// lossless PNG encode) جو پہلے مین UI تھریڈ کو 1-2MB جیسی بڑی تصاویر پر
/// کئی سیکنڈ کے لیے مکمل طور پر منجمد کر دیتا تھا (اینیمیشنز، Elapsed
/// ٹائمر، اسکرولنگ وغیرہ سب رک جاتے تھے)۔ top-level ہونا ضروری ہے تاکہ
/// Dart اسے نئے آئسولیٹ میں بھیج سکے۔
_DecodeResizeResult _decodeCropResizeInBackground(_DecodeResizeInput input) {
  img.Image? rawImage;
  img.Image? resizedImage;
  try {
    rawImage = img.decodeImage(input.bytes);
    if (rawImage == null) return const _DecodeResizeResult();

    final oriented = img.bakeOrientation(rawImage);
    final processedImage =
        input.rotation != 0 ? img.copyRotate(oriented, angle: input.rotation) : oriented;

    final bool alreadyCorrectSize =
        processedImage.width == input.width && processedImage.height == input.height;

    img.Image finalImage;
    if (alreadyCorrectSize) {
      finalImage = processedImage;
    } else {
      // 🌟 فکس: پہلے یہاں تناسب نہ ملنے پر خودکار center-crop ہوتا تھا،
      // جس سے preview میں نظر نہ آنے والا حصہ ہمیشہ کے لیے ضائع ہو جاتا
      // تھا — چاہے یوزر نے خود کچھ کراپ نہ کیا ہو۔ اب یہاں کوئی خودکار
      // کراپ نہیں ہوتا: پوری تصویر (یا اگر یوزر نے ✂️ سے خود کراپ کی ہے
      // تو بالکل وہی منتخب کردہ حصہ) سیدھا ہدف کے exact width×height پر
      // اسٹریچ/سکوئز کر دی جاتی ہے۔ جو یوزر نے رکھا ہے وہی رہتا ہے —
      // خودکار کٹاؤ بالکل نہیں۔
      resizedImage = img.copyResize(
        processedImage,
        width: input.width,
        height: input.height,
        interpolation: img.Interpolation.cubic,
      );
      finalImage = resizedImage;
    }

    final Uint8List losslessBytes =
        Uint8List.fromList(img.encodePng(finalImage, level: 1));

    return _DecodeResizeResult(
      pngBytes: losslessBytes,
      width: finalImage.width,
      height: finalImage.height,
    );
  } catch (_) {
    return const _DecodeResizeResult();
  } finally {
    rawImage?.clear();
    resizedImage?.clear();
  }
}

class ImageService extends ChangeNotifier {
  final List<PhotoItem> _photos = [];
  bool _cancelRequested = false;

  // 🌟 بیک وقت زیادہ سے زیادہ 3 تصاویر پروسیس ہوں گی۔ ہر تصویر کا بھاری
  // decode/crop/resize/encode کا کام اب compute() کے ذریعے ایک الگ
  // بیک گراؤنڈ آئسولیٹ میں چلتا ہے (mobile کے 3 سے زیادہ کور استعمال ہو
  // سکیں)، جبکہ native quality-compression والا حصہ (flutter_image_compress)
  // پہلے ہی خودکار طور پر UI تھریڈ سے باہر چلتا ہے۔ 3 کی حد میموری اور
  // بیک وقت کھلے آئسولیٹس کی تعداد کو قابو میں رکھنے کے لیے ہے۔
  static const int _concurrency = 3;

  List<PhotoItem> get photos => _photos;

  bool _isUrdu = true;
  bool get isUrdu => _isUrdu;

  void toggleLanguage() {
    _isUrdu = !_isUrdu;
    notifyListeners();
  }

  void addPhotos(List<PhotoItem> items) {
    for (var item in items) {
      final file = File(item.imagePath);
      if (file.existsSync()) {
        final sizeInBytes = file.lengthSync();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        String originalSize = sizeInMB > 1.0
            ? '${sizeInMB.toStringAsFixed(2)} MB'
            : '${(sizeInBytes / 1024).toStringAsFixed(0)} KB';
        _photos.add(item.copyWith(originalSizeDisplay: originalSize));
      } else {
        _photos.add(item);
      }
    }
    notifyListeners();
  }

  void setPhotos(List<PhotoItem> photos) {
    _photos.clear();
    _photos.addAll(photos);
    notifyListeners();
  }

  void clearPhotos() {
    _photos.clear();
    notifyListeners();
  }

  void updatePhoto(PhotoItem updatedPhoto) {
    final index = _photos.indexWhere((p) => p.id == updatedPhoto.id);
    if (index != -1) {
      _photos[index] = updatedPhoto;
      notifyListeners();
    }
  }

  void removePhoto(String id) {
    _photos.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  /// 🌟 کینسل: صرف فلیگ سیٹ ہوتا ہے۔ کوئی بھی in-flight compute()
  /// آئسولیٹ یا native call اپنا موجودہ ایک تصویر مکمل کر لے گا، لیکن
  /// اس کا نتیجہ نظرانداز کر دیا جائے گا اور کوئی نئی تصویر شروع نہیں
  /// ہو گی، اس لیے UI تقریباً فوری طور پر رک جاتا ہے۔
  void cancelProcessing() {
    _cancelRequested = true;
  }

  Stream<ImageProcessingProgress> processPhotosAsStream(
    GridSettings settings,
    bool Function() checkCancel,
  ) {
    final controller = StreamController<ImageProcessingProgress>();
    _runProcessingPool(settings, checkCancel, controller);
    return controller.stream;
  }

  Future<void> _runProcessingPool(
    GridSettings settings,
    bool Function() checkCancel,
    StreamController<ImageProcessingProgress> controller,
  ) async {
    _cancelRequested = false;
    final int total = _photos.length;
    if (total == 0) {
      await controller.close();
      return;
    }

    final stopwatch = Stopwatch()..start();
    int nextIndex = 0;
    int running = 0;
    int finished = 0;
    bool stopped = false;

    void maybeStop() {
      if (stopped) return;
      final bool cancelledAndIdle = (_cancelRequested || checkCancel()) && running == 0;
      final bool naturallyDone = finished >= total && running == 0;
      if (cancelledAndIdle || naturallyDone) {
        stopped = true;
        stopwatch.stop();
        notifyListeners();
        controller.close();
      }
    }

    void launchNext() {
      while (running < _concurrency && nextIndex < total) {
        if (_cancelRequested || checkCancel()) break;
        final i = nextIndex++;
        running++;
        final photo = _photos[i];
        final fileName = File(photo.imagePath).uri.pathSegments.last;

        _processOne(i, settings).then((result) {
          running--;
          if (!_cancelRequested && !checkCancel() && result.success && result.outputPath != null) {
            _photos[i] = photo.copyWith(
              processedPath: result.outputPath,
              finalSizeKB: result.sizeKB,
              width: result.finalWidth ?? settings.targetWidth,
              height: result.finalHeight ?? settings.targetHeight,
            );
          }
          finished++;

          if (!controller.isClosed && !_cancelRequested && !checkCancel()) {
            final elapsedMs = stopwatch.elapsedMilliseconds;
            final avgTimePerImage = finished > 0 ? elapsedMs / finished : 0;
            final remainingImages = total - finished;
            final estimatedMs = (avgTimePerImage * remainingImages).toInt();

            String timeStr = '${(estimatedMs / 1000).toStringAsFixed(1)}s remaining';
            if (estimatedMs < 1000) timeStr = 'Less than a second';

            controller.add(ImageProcessingProgress(
              processedCount: finished,
              totalCount: total,
              currentFileName: fileName,
              estimatedTimeLeft: timeStr,
              elapsedMs: elapsedMs,
            ));
          }

          if (_cancelRequested || checkCancel()) {
            maybeStop();
          } else {
            launchNext();
            maybeStop();
          }
        });
      }
      maybeStop();
    }

    launchNext();
  }

  /// 🌟 ایک تصویر پروسیس کرنے کا فیصلہ: اگر پہلے سے ہدف ڈائمنشن اور KB
  /// حد کے اندر ہے تو دوبارہ decode/encode کیے بغیر فوری "مکمل" مان لیا جاتا ہے۔
  Future<_ProcessResult> _processOne(int index, GridSettings settings) async {
    final photo = _photos[index];
    final file = File(photo.imagePath);
    if (!await file.exists()) return _ProcessResult.failure();

    try {
      final lengthBytes = await file.length();
      final targetBytes = settings.targetKB * 1024;
      final bool alreadyGood = photo.width == settings.targetWidth &&
          photo.height == settings.targetHeight &&
          photo.rotation == 0 &&
          lengthBytes > 0 &&
          lengthBytes <= targetBytes;

      if (alreadyGood) {
        return _ProcessResult(
          success: true,
          sizeKB: (lengthBytes / 1024).round(),
          outputPath: photo.imagePath,
          finalWidth: photo.width,
          finalHeight: photo.height,
        );
      }
    } catch (_) {
      // معلوم نہ ہو سکے تو نیچے دیئے گئے مکمل پروسیسنگ والے راستے پر جائیں
    }

    if (_cancelRequested) return _ProcessResult.failure();

    final outputPath =
        '${Directory.systemTemp.path}/${photo.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    return _processSingleImageNative(
      imagePath: photo.imagePath,
      width: settings.targetWidth,
      height: settings.targetHeight,
      targetSizeKB: settings.targetKB,
      quality: settings.quality,
      rotation: photo.rotation,
      outputPath: outputPath,
    );
  }

  /// 🌟 اصل پروسیسنگ: crop/resize/PNG-encode اب compute() کے ذریعے ایک
  /// الگ بیک گراؤنڈ آئسولیٹ میں چلتا ہے (مین UI تھریڈ آزاد رہتا ہے)،
  /// اور آخر میں quality-search native compressor سے (تیز، HTML/Canvas
  /// جتنی رفتار)۔
  static Future<_ProcessResult> _processSingleImageNative({
    required String imagePath,
    required int width,
    required int height,
    required int targetSizeKB,
    required int quality,
    required double rotation,
    required String outputPath,
  }) async {
    // 🌟 حفاظتی ٹائم آؤٹ: چاہے compute() آئسولیٹ پھنس جائے (مثلاً Hot
    // Reload کے بعد کی معروف خرابی)، یا native compressor کسی خراب/corrupt
    // فائل پر اٹک جائے — 25 سیکنڈ کے بعد یہ ایک تصویر ناکام مان لی جائے گی
    // اور باقی قطار (queue) رکنے کی بجائے آگے بڑھتی رہے گی۔ پہلے کوئی
    // ٹائم آؤٹ نہ ہونے کی وجہ سے ایک اٹکی ہوئی تصویر پوری بیچ (batch) کو
    // ہمیشہ کے لیے 0% پر روک سکتی تھی۔
    try {
      return await _runProcessSingleImage(
        imagePath: imagePath,
        width: width,
        height: height,
        targetSizeKB: targetSizeKB,
        quality: quality,
        rotation: rotation,
        outputPath: outputPath,
      ).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('⚠️ Image processing TIMED OUT after 25s: $imagePath');
      }
      return _ProcessResult.failure();
    } catch (_) {
      return _ProcessResult.failure();
    }
  }

  static Future<_ProcessResult> _runProcessSingleImage({
    required String imagePath,
    required int width,
    required int height,
    required int targetSizeKB,
    required int quality,
    required double rotation,
    required String outputPath,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return _ProcessResult.failure();

      final bytes = await file.readAsBytes();

      final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;

      // 🌟 یہاں compute() اصل بھاری، synchronous Dart کام (decode, crop,
      // resize, PNG encode) کو ایک نئے بیک گراؤنڈ آئسولیٹ میں بھیج دیتا
      // ہے۔ مین UI آئسولیٹ اس دوران بالکل آزاد رہتا ہے — اینیمیشنز،
      // Elapsed ٹائمر اور اسکرولنگ سب رواں دواں رہتے ہیں، چاہے تصویر
      // 1-2MB یا اس سے بڑی ہی کیوں نہ ہو۔
      final decodeResult = await compute(
        _decodeCropResizeInBackground,
        _DecodeResizeInput(bytes: bytes, width: width, height: height, rotation: rotation),
      );

      if (kDebugMode) {
        debugPrint('🕒 compute() decode/resize took ${stopwatch!.elapsedMilliseconds}ms for $imagePath');
      }

      final Uint8List? losslessBytes = decodeResult.pngBytes;
      if (losslessBytes == null) return _ProcessResult.failure();

      final int targetBytes = targetSizeKB * 1024;
      final Uint8List bestEncoded = await _nativeBestQualityForTarget(
        losslessBytes,
        quality,
        targetBytes,
        decodeResult.width,
        decodeResult.height,
      );

      if (kDebugMode) {
        debugPrint('🕒 total (decode+compress) took ${stopwatch!.elapsedMilliseconds}ms for $imagePath');
      }

      final File tempFile = File('$outputPath.tmp');
      await tempFile.writeAsBytes(bestEncoded);
      await tempFile.rename(outputPath);

      return _ProcessResult(
        success: true,
        sizeKB: (bestEncoded.length / 1024).round(),
        outputPath: outputPath,
        finalWidth: decodeResult.width,
        finalHeight: decodeResult.height,
      );
    } catch (_) {
      return _ProcessResult.failure();
    }
  }

  /// 🌟 native (hardware) JPEG انکوڈر کے ساتھ binary-search — کم از کم
  /// کوالٹی 40% رکھی گئی ہے تاکہ تصویر HD رہے۔ ہر attempt native ہونے کی
  /// وجہ سے پرانے pure-Dart طریقے سے کئی گنا تیز ہے۔
  static Future<Uint8List> _nativeBestQualityForTarget(
    Uint8List sourceBytes,
    int maxQuality,
    int targetBytes,
    int width,
    int height,
  ) async {
    int low = 40;
    int high = maxQuality.clamp(40, 100);

    Uint8List? best = await FlutterImageCompress.compressWithList(
      sourceBytes,
      minWidth: width,
      minHeight: height,
      quality: low,
      format: CompressFormat.jpeg,
    );

    while (low <= high) {
      final int mid = (low + high) ~/ 2;
      final Uint8List attempt = await FlutterImageCompress.compressWithList(
        sourceBytes,
        minWidth: width,
        minHeight: height,
        quality: mid,
        format: CompressFormat.jpeg,
      );
      if (attempt.length <= targetBytes) {
        best = attempt;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // 🌟 اگر کم از کم کوالٹی پر بھی سائز بڑا ہو تو کوالٹی مزید نہیں گراتے،
    // بلکہ dimensions کو آہستہ آہستہ 10% کم کرتے ہیں (پرانے کوڈ جیسا رویہ)
    int w = width, h = height;
    int safety = 0;
    while (best!.length > targetBytes && safety < 6) {
      safety++;
      w = (w * 0.90).round();
      h = (h * 0.90).round();
      if (w < 100 || h < 100) break;
      best = await FlutterImageCompress.compressWithList(
        sourceBytes,
        minWidth: w,
        minHeight: h,
        quality: 40,
        format: CompressFormat.jpeg,
      );
    }

    return best;
  }
}

class _ProcessResult {
  final bool success;
  final int? sizeKB;
  final String? outputPath;
  final int? finalWidth;
  final int? finalHeight;

  const _ProcessResult({
    required this.success,
    this.sizeKB,
    this.outputPath,
    this.finalWidth,
    this.finalHeight,
  });

  factory _ProcessResult.failure() => const _ProcessResult(success: false);
}
