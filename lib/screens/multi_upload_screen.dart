// lib/screens/multi_upload_screen.dart
import 'dart:async'; // 🌟 Completer اور Timer کے لیے لازمی امپورٹ
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/export_options.dart';
import '../services/export_service.dart';
import '../models/photo_item.dart';
import '../models/grid_settings.dart';
import '../services/image_service.dart';
import '../utils/app_strings.dart';
import '../utils/app_colors.dart'; // 🌟 برانڈ رنگ — ہوم اسکرین جیسا سیل گرین/گولڈ تھیم

class MultiUploadScreen extends StatefulWidget {
  const MultiUploadScreen({super.key});

  @override
  State<MultiUploadScreen> createState() => _MultiUploadScreenState();
}

class _MultiUploadScreenState extends State<MultiUploadScreen> {
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late TextEditingController _kbController;

  int targetWidth = 600;
  int targetHeight = 800;
  int targetKB = 23;

  bool isProcessing = false;
  bool hasProcessed = false;
  bool isSaving = false;
  bool _isLoadingImages = false; // 🌟 تصاویر لوڈ ہونے کا اسٹیٹ ویری ایبل
  String progressText = '';
  double progressValue = 0.0;
  int _processedCount = 0;
  int _totalToProcess = 0;
  int _elapsedMs = 0;
  final _uuid = const Uuid();

  // 🌟 فکس (ANR کی اصل وجہ): پہلے یہاں Timer.periodic ہر 100ms پر پوری
  // اسکرین (20 تصاویر والا GridView سمیت) کو setState سے دوبارہ بناتا
  // تھا، جو لمبی پروسیسنگ کے دوران "isn't responding" کی اصل وجہ بنی۔
  // اب یہاں صرف ایک عام Stopwatch ہے — لائیو ٹکنگ ڈسپلے کی ذمہ داری
  // نیچے موجود الگ، خود مختار _LiveElapsedText widget پر منتقل کر دی
  // گئی ہے (وہ صرف خود کو ری بلڈ کرتی ہے، پوری اسکرین کو نہیں)۔
  final Stopwatch _liveStopwatch = Stopwatch();

  void _startLiveTimer() {
    _liveStopwatch
      ..reset()
      ..start();
  }

  void _stopLiveTimer() {
    _liveStopwatch.stop();
    if (mounted) setState(() => _elapsedMs = _liveStopwatch.elapsedMilliseconds);
  }

  // 🌟 ہر تصویر کے نام باکس کے لیے علیحدہ FocusNode — Tab/Next سے اگلے باکس پر جانے کے لیے
  final Map<String, FocusNode> _focusNodes = {};

  FocusNode _focusFor(String id) => _focusNodes.putIfAbsent(id, () => FocusNode());

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(text: targetWidth.toString());
    _heightController = TextEditingController(text: targetHeight.toString());
    _kbController = TextEditingController(text: targetKB.toString());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ImageService>().clearPhotos();
    });
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _kbController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  GridSettings _getSettings() {
    return GridSettings(
      rows: 1,
      cols: 1,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      targetKB: targetKB,
    );
  }

    Future<void> _pickImages(bool isUrdu) async {
    // 🌟 1. کام شروع ہونے سے پہلے لوڈنگ آن کریں
    setState(() {
      _isLoadingImages = true;
    });

    try {
      final files = await _picker.pickMultiImage();
      if (files.isEmpty) return;

      if (!mounted) return;
      final service = context.read<ImageService>();
      final newItems = <PhotoItem>[];
      int duplicateCount = 0;
      final existingHashes = service.photos.map((e) => e.hash).toSet();

      for (final f in files) {
        final file = File(f.path);
        final bytes = await file.readAsBytes();
        final fileHash = sha256.convert(bytes).toString();

        if (existingHashes.contains(fileHash)) {
          duplicateCount++;
          continue;
        }

        existingHashes.add(fileHash);

        // 🌟 اصل تصویر کی حقیقی چوڑائی/لمبائی معلوم کرنے کا بالکل درست طریقہ
        int originalWidth = targetWidth;
        int originalHeight = targetHeight;
        try {
          final completer = Completer<ui.Image>();
          ui.decodeImageFromList(bytes, (ui.Image img) {
            completer.complete(img);
          });
          final decoded = await completer.future;
          originalWidth = decoded.width;
          originalHeight = decoded.height;
          decoded.dispose();
        } catch (_) {
          // ڈیکوڈ ناکام ہو تو ڈیفالٹ ویلیوز ہی رہنے دیں
        }

        newItems.add(PhotoItem(
          id: _uuid.v4(),
          name: f.name,
          rollNo: '',
          hash: fileHash,
          imagePath: f.path,
          originalBytes: bytes,
          width: originalWidth,
          height: originalHeight,
        ));
      }

      if (duplicateCount > 0 && mounted) {
        _showToast(AppStrings.text('duplicatesSkipped', isUrdu), isUrdu);
      }

      if (newItems.isNotEmpty) {
        service.addPhotos(newItems);
        setState(() {
          hasProcessed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showToast('${AppStrings.text('errorPrefix', isUrdu)} $e', isUrdu, isError: true);
      }
    } finally {
      // 🌟 2. کام ختم ہونے کے بعد لوڈنگ آف کر دیں
      if (mounted) {
        setState(() {
          _isLoadingImages = false;
        });
      }
    }
  }


  Future<void> _clearAllImages(bool isUrdu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.text('confirmClearTitle', isUrdu)),
        content: Text(AppStrings.text('confirmClearMsg', isUrdu)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.text('cancel', isUrdu)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.text('confirm', isUrdu)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<ImageService>().clearPhotos();
      setState(() => hasProcessed = false);
    }
  }

  Future<void> _processImagesOnly(bool isUrdu) async {
    final service = context.read<ImageService>();
    if (service.photos.isEmpty) return;

    setState(() {
      isProcessing = true;
      progressValue = 0.0;
      _processedCount = 0;
      _totalToProcess = service.photos.length;
      _elapsedMs = 0;
      progressText = AppStrings.text('resizingImages', isUrdu);
    });
    _startLiveTimer();

    try {
      final currentSettings = _getSettings();

      await for (final progress in service.processPhotosAsStream(currentSettings, () => !mounted)) {
        if (mounted) {
          setState(() {
            _processedCount = progress.processedCount;
            _totalToProcess = progress.totalCount;
            // نوٹ: _elapsedMs اب لائیو ٹائمر سے مسلسل اپڈیٹ ہوتا ہے، یہاں
            // صرف حتمی/تصدیق شدہ ویلیو سیٹ کی جا رہی ہے۔
            _elapsedMs = progress.elapsedMs;
            progressValue = progress.totalCount > 0 ? progress.processedCount / progress.totalCount : 0.0;
            progressText = '${AppStrings.text('processingImages', isUrdu)} ($_processedCount/$_totalToProcess)';
          });
        }
      }

      _stopLiveTimer();
      setState(() {
        isProcessing = false;
        hasProcessed = true;
        progressValue = 1.0;
        _showToast(AppStrings.text('processingComplete', isUrdu), isUrdu);
      });
    } catch (e) {
      _stopLiveTimer();
      setState(() {
        isProcessing = false;
      });
      _showToast("${AppStrings.text('processingFailed', isUrdu)} $e", isUrdu, isError: true);
    }
  }

  // ==========================================
  // 🌟 ایپ کا اپنا محفوظ فولڈر (Save to Gallery / Save to Folder کے لیے)
  // ==========================================
  /// 🌟 اب فائلیں اینڈرائیڈ کے پبلک "Download" فولڈر میں محفوظ ہوں گی
  /// (کسی بھی فائل مینیجر میں براہِ راست نظر آئیں گی) — نہ کہ
  /// Android/data کے اندر چھپے ہوئے ایپ-مخصوص فولڈر میں۔
  Future<String> _getAppCustomDirectory(String subFolder) async {
    if (Platform.isAndroid) {
      try {
        if (await Permission.manageExternalStorage.isGranted ||
            await Permission.manageExternalStorage.request().isGranted ||
            await Permission.storage.request().isGranted) {
          final publicDir = Directory('/storage/emulated/0/Download/MultiImageTool/$subFolder');
          if (!await publicDir.exists()) {
            await publicDir.create(recursive: true);
          }
          return publicDir.path;
        }
      } catch (_) {
        // نیچے فال بیک پر جائیں
      }
    }

    // 🌟 فال بیک: اگر پرمیشن نہ ملے تو ایپ کریش ہونے کی بجائے اپنے
    // محفوظ فولڈر میں سیو کر دے
    Directory? directory;
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        directory = Directory('${externalDir.path}/MultiImageTool/$subFolder');
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        directory = Directory('${docDir.path}/MultiImageTool/$subFolder');
      }
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      directory = Directory('${docDir.path}/MultiImageTool/$subFolder');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  Future<void> _downloadAction(bool asZip, bool isUrdu) async {
    final service = context.read<ImageService>();
    if (service.photos.isEmpty) return;

    setState(() {
      isSaving = true;
    });

    try {
      if (asZip) {
        // 🌟 ZIP پہلے عارضی (کسی کو نظر نہ آنے والے) فولڈر میں بنائی جاتی
        // ہے، پھر Android کا اپنا نیٹو Save-As ڈائیلاگ کھلتا ہے — یوزر
        // خود فولڈر اور فائل کا نام منتخب کرتا ہے (بین الاقوامی طریقہ)۔
        final tempDir = await getTemporaryDirectory();
        final zipTargetDir = '${tempDir.path}/zip_temp_${DateTime.now().millisecondsSinceEpoch}';
        await Directory(zipTargetDir).create(recursive: true);

        final options = ExportOptions(destinationPath: zipTargetDir);
        final zipFile = await ExportService.createZipWithProgress(
          photos: service.photos,
          options: options,
          checkCancel: () => false,
          onProgress: (p) {},
        );

        final String suggestedName =
            'Admissions_Export_${DateTime.now().millisecondsSinceEpoch}.zip';
        final String? savedPath =
            await ExportService.saveFileWithDialog(zipFile, suggestedName: suggestedName);

        // 🌟 عارضی فولڈر صاف کریں
        if (await Directory(zipTargetDir).exists()) {
          await Directory(zipTargetDir).delete(recursive: true);
        }

        if (mounted) {
          if (savedPath != null) {
            _showToast('${AppStrings.text('savedZipToFolder', isUrdu)}\n$savedPath', isUrdu);
          } else {
            _showToast(isUrdu ? 'محفوظ کرنا منسوخ کر دیا گیا' : 'Save cancelled', isUrdu);
          }
        }
      } else {
        // 🌟 تصاویر پہلے عارضی فولڈر میں صحیح ناموں سے تیار کی جاتی ہیں،
        // پھر ایک ہی بار یوزر سے فولڈر پوچھا جاتا ہے — ہر تصویر اسی
        // منتخب شدہ فولڈر میں محفوظ ہو جاتی ہے۔
        final tempDir = await getTemporaryDirectory();
        final imagesTempDir = '${tempDir.path}/images_temp_${DateTime.now().millisecondsSinceEpoch}';
        await Directory(imagesTempDir).create(recursive: true);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final List<File> preparedFiles = [];

        for (int i = 0; i < service.photos.length; i++) {
          final photo = service.photos[i];
          final String name = (photo.customName != null && photo.customName!.trim().isNotEmpty)
              ? photo.customName!.trim()
              : "Bulk_Photo_$i";
          final tempPath = '$imagesTempDir/${name}_$timestamp.jpg';
          final sourcePath = photo.processedPath ?? photo.imagePath;
          preparedFiles.add(await File(sourcePath).copy(tempPath));
        }

        final bool saved = await ExportService.saveImagesWithDialog(preparedFiles);

        if (await Directory(imagesTempDir).exists()) {
          await Directory(imagesTempDir).delete(recursive: true);
        }

        if (mounted) {
          if (saved) {
            _showToast(AppStrings.text('savedToGallery', isUrdu), isUrdu);
          } else {
            _showToast(isUrdu ? 'محفوظ کرنا منسوخ کر دیا گیا' : 'Save cancelled', isUrdu);
          }
        }
      }
    } catch (e) {
      _showToast("${AppStrings.text('downloadFailed', isUrdu)} $e", isUrdu, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // 🌟 کسی مخصوص تصویر کو الگ سے کراپ/روٹیٹ کرنا — اگر کسی ایک تصویر کی
  // سائیڈیں خراب ہوں تو صارف صرف اسی کو ٹچ کر کے درست کر سکتا ہے۔
  Future<void> _cropSinglePhoto(PhotoItem photo, bool isUrdu) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: photo.imagePath,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: AppStrings.text('cropImage', isUrdu),
            toolbarColor: kSealGreen,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: AppStrings.text('cropImage', isUrdu),
          ),
        ],
      );

      if (cropped == null || !mounted) return;

      final bytes = await File(cropped.path).readAsBytes();
      int newWidth = photo.width;
      int newHeight = photo.height;
      try {
        final completer = Completer<ui.Image>();
        ui.decodeImageFromList(bytes, (ui.Image img) => completer.complete(img));
        final decoded = await completer.future;
        newWidth = decoded.width;
        newHeight = decoded.height;
        decoded.dispose();
      } catch (_) {}

      final sizeInBytes = bytes.length;
      final sizeInMB = sizeInBytes / (1024 * 1024);
      final String newSizeDisplay = sizeInMB > 1.0
          ? '${sizeInMB.toStringAsFixed(2)} MB'
          : '${(sizeInBytes / 1024).toStringAsFixed(0)} KB';

      context.read<ImageService>().updatePhoto(photo.copyWith(
            imagePath: cropped.path,
            width: newWidth,
            height: newHeight,
            originalSizeDisplay: newSizeDisplay,
            clearProcessedPath: true,
            clearFinalSizeKB: true,
          ));
      setState(() => hasProcessed = false);
    } catch (e) {
      if (mounted) {
        _showToast("${AppStrings.text('errorPrefix', isUrdu)} $e", isUrdu, isError: true);
      }
    }
  }

  void _showToast(String msg, bool isUrdu, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null, fontSize: 13)),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Widget _buildSmallField(String label, TextEditingController controller, Function(String) onChanged, bool isUrdu) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 11, fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      onChanged: onChanged,
    );
  }

  // 🌟 قومی و بین الاقوامی سطح پر عام استعمال ہونے والے سائز/ڈائمنشنز
  static const List<Map<String, dynamic>> _sizePresets = [
    {'ur': 'بورڈ داخلہ فارم (پاکستان) — 600×800، 23 KB', 'en': 'Board Admission Form (Pakistan) — 600×800, 23 KB', 'w': 600, 'h': 800, 'kb': 23},
    {'ur': 'پاسپورٹ سائز (بین الاقوامی) — 413×531، 30 KB', 'en': 'Passport Size (International) — 413×531, 30 KB', 'w': 413, 'h': 531, 'kb': 30},
    {'ur': 'CNIC / فارم-B فوٹو — 600×600، 30 KB', 'en': 'CNIC / Form-B Photo — 600×600, 30 KB', 'w': 600, 'h': 600, 'kb': 30},
    {'ur': 'یو ایس ویزا فوٹو — 600×600، 50 KB', 'en': 'US Visa Photo — 600×600, 50 KB', 'w': 600, 'h': 600, 'kb': 50},
    {'ur': 'NADRA فیملی رجسٹریشن — 350×450، 20 KB', 'en': 'NADRA Family Registration — 350×450, 20 KB', 'w': 350, 'h': 450, 'kb': 20},
    {'ur': 'اسٹیمپ سائز فوٹو — 200×230، 15 KB', 'en': 'Stamp Size Photo — 200×230, 15 KB', 'w': 200, 'h': 230, 'kb': 15},
  ];

  String? _selectedPresetLabel;

  void _applyPreset(Map<String, dynamic> preset, bool isUrdu) {
    setState(() {
      _selectedPresetLabel = isUrdu ? preset['ur'] as String : preset['en'] as String;
      targetWidth = preset['w'] as int;
      targetHeight = preset['h'] as int;
      targetKB = preset['kb'] as int;
      _widthController.text = targetWidth.toString();
      _heightController.text = targetHeight.toString();
      _kbController.text = targetKB.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ImageService>();
    final photos = service.photos;
    final bool isUrdu = service.isUrdu;
    final urduStyle = TextStyle(fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null);

    int crossAxisCount = 4;
    double aspectRatio = 0.65;

    if (photos.length == 1) {
      crossAxisCount = 1;
      aspectRatio = 1.0;
    } else if (photos.length == 2) {
      crossAxisCount = 2;
      aspectRatio = 0.85;
    }

    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: kAppBackground,
        appBar: AppBar(
          title: Text(
            AppStrings.text('multiUploadTitle', isUrdu),
            style: urduStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: kBrandGradient,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              tooltip: AppStrings.text('home', isUrdu),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            IconButton(
              icon: const Icon(Icons.language, color: Colors.white),
              tooltip: AppStrings.text('language', !isUrdu),
              onPressed: () {
                context.read<ImageService>().toggleLanguage();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (isProcessing) _buildPremiumProgressBar(isUrdu),
            if (isSaving && !isProcessing)
              const LinearProgressIndicator(color: kGold, backgroundColor: kSealGreenLight),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      AppStrings.text('customSizeTitle', isUrdu),
                      style: urduStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: kSealGreen),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildSmallField(AppStrings.text('widthLabel', isUrdu), _widthController, (v) => targetWidth = int.tryParse(v) ?? 600, isUrdu)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildSmallField(AppStrings.text('heightLabel', isUrdu), _heightController, (v) => targetHeight = int.tryParse(v) ?? 800, isUrdu)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildSmallField(AppStrings.text('sizeKbLabel', isUrdu), _kbController, (v) => targetKB = int.tryParse(v) ?? 23, isUrdu)),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      AppStrings.text('defaultSizeTitle', isUrdu),
                      style: urduStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: kSealGreen),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedPresetLabel,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    hint: Text(
                      AppStrings.text('choosePresetHint', isUrdu),
                      style: urduStyle.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: _sizePresets.map((preset) {
                      final String label = isUrdu ? preset['ur'] as String : preset['en'] as String;
                      return DropdownMenuItem<String>(
                        value: label,
                        child: Text(label, style: urduStyle.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? newLabel) {
                      if (newLabel == null) return;
                      final preset = _sizePresets.firstWhere(
                        (p) => (isUrdu ? p['ur'] : p['en']) == newLabel,
                        orElse: () => _sizePresets.first,
                      );
                      _applyPreset(preset, isUrdu);
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSealGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: isProcessing ? null : () => _pickImages(isUrdu),
                      icon: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 20),
                      label: Text(
                        AppStrings.text('selectFromGallery', isUrdu),
                        style: urduStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        side: BorderSide(color: Colors.red.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: isProcessing ? null : () => _clearAllImages(isUrdu),
                      icon: Icon(Icons.delete_sweep, color: Colors.red.shade700, size: 20),
                      label: Text(
                        AppStrings.text('clearAll', isUrdu),
                        style: urduStyle.copyWith(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                // 🌟 3. یہاں لوڈنگ والی کنڈیشن لگا دی گئی ہے
                child: _isLoadingImages
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: kSealGreen),
                            const SizedBox(height: 16),
                            Text(
                              isUrdu ? 'تصاویر لوڈ ہو رہی ہیں، براہ کرم انتظار کریں...' : 'Loading images, please wait...',
                              style: urduStyle.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: kSealGreen),
                            ),
                          ],
                        ),
                      )
                    : photos.isEmpty
                        ? Center(child: Text(AppStrings.text('noImagesSelected', isUrdu), style: urduStyle.copyWith(color: Colors.grey, fontSize: 14)))
                        : GridView.builder(

                        padding: const EdgeInsets.all(6),
                        itemCount: photos.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: aspectRatio,
                        ),
                        itemBuilder: (context, i) {
                          final photo = photos[i];
                          final isLast = i == photos.length - 1;
                          return _IndividualPhotoTile(
                            photo: photo,
                            hasProcessed: hasProcessed,
                            isUrdu: isUrdu,
                            focusNode: _focusFor(photo.id),
                            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                            targetAspectRatio: targetWidth / targetHeight,
                            onRemove: () => service.removePhoto(photo.id),
                            onCropRequested: hasProcessed ? null : () => _cropSinglePhoto(photo, isUrdu),
                            onNameChanged: (val) {
                              service.updatePhoto(photo.copyWith(customName: val));
                            },
                            onSubmitted: () {
                              if (!isLast) {
                                FocusScope.of(context).requestFocus(_focusFor(photos[i + 1].id));
                              } else {
                                FocusScope.of(context).unfocus();
                              }
                            },
                          );
                        },
                      ),
              ),
            ),

            // 🌟 "ری سائز اینڈ رینیم" بٹن اب پریویو گرڈ کے نیچے، اسکرین کی
            // آخری (فکسڈ) لائن پر رہے گا — پروسیسنگ سے پہلے کی حالت میں۔
            if (photos.isNotEmpty && !hasProcessed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(colors: [kGold, Color(0xFFB8860B)]),
                      boxShadow: [BoxShadow(color: kGold.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isProcessing ? null : () => _processImagesOnly(isUrdu),
                      icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                      label: Text(
                        AppStrings.text('resizeAndRename', isUrdu),
                        style: urduStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ),

            // 🌟 پروسیسنگ مکمل ہونے کے بعد کی حالت میں Save بٹن اسی فکسڈ باٹم لائن پر
            if (hasProcessed && photos.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSealGreenLight,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: isSaving ? null : () => _downloadAction(false, isUrdu),
                        icon: const Icon(Icons.image, size: 18, color: Colors.white),
                        label: Text(
                          AppStrings.text('saveToGallery', isUrdu),
                          style: urduStyle.copyWith(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSealGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: isSaving ? null : () => _downloadAction(true, isUrdu),
                        icon: const Icon(Icons.folder_zip, size: 18, color: Colors.white),
                        label: Text(
                          AppStrings.text('saveToFolder', isUrdu),
                          style: urduStyle.copyWith(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🌟 پروفیشنل / پریمیم پروگریس بار — گریڈینٹ رنگ، فیصد اور شمار کے ساتھ
  Widget _buildPremiumProgressBar(bool isUrdu) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  progressText,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null, fontSize: 12, fontWeight: FontWeight.bold, color: kSealGreenDark),
                ),
              ),
              Text('${(progressValue * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kSealGreen)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(kSealGreen),
            ),
          ),
          const SizedBox(height: 4),
          // 🌟 فکس: پہلے یہ Text پیرنٹ اسکرین کے پورے rebuild پر منحصر تھا
          // (Timer.periodic ہر 100ms پر پوری اسکرین سمیت 20 تصاویر والا
          // GridView دوبارہ بناتا تھا — یہی اصل وجہ تھی "isn't responding"
          // ایرر کی، خاص طور پر لمبی پروسیسنگ کے دوران)۔ اب یہ الگ چھوٹی
          // widget ہے جو خود اپنا ٹائمر چلاتی ہے اور صرف خود کو ری بلڈ
          // کرتی ہے — باقی اسکرین بالکل غیر متاثر رہتی ہے۔
          _LiveElapsedText(stopwatch: _liveStopwatch, isRunning: isProcessing),
        ],
      ),
    );
  }
}

/// 🌟 خود مختار elapsed-time ٹکر — صرف خود کو ہر 100ms میں ری بلڈ کرتی ہے،
/// پیرنٹ اسکرین کو بالکل نہیں چھیڑتی۔
class _LiveElapsedText extends StatefulWidget {
  final Stopwatch stopwatch;
  final bool isRunning;
  const _LiveElapsedText({required this.stopwatch, required this.isRunning});

  @override
  State<_LiveElapsedText> createState() => _LiveElapsedTextState();
}

class _LiveElapsedTextState extends State<_LiveElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _maybeStartTimer();
  }

  @override
  void didUpdateWidget(covariant _LiveElapsedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartTimer();
  }

  void _maybeStartTimer() {
    _timer?.cancel();
    if (widget.isRunning) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {}); // 🌟 صرف یہی چھوٹی Text widget ری بلڈ ہوتی ہے
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.stopwatch.elapsedMilliseconds / 1000;
    return Text(
      'Elapsed: ${seconds.toStringAsFixed(1)}s',
      style: const TextStyle(fontSize: 10, color: Colors.grey),
    );
  }
}

class _IndividualPhotoTile extends StatelessWidget {
  final PhotoItem photo;
  final bool hasProcessed;
  final bool isUrdu;
  final FocusNode focusNode;
  final TextInputAction textInputAction;
  final VoidCallback onRemove;
  final VoidCallback? onCropRequested;
  final Function(String) onNameChanged;
  final VoidCallback onSubmitted;
  final double targetAspectRatio; // 🌟 width/height — اصل پروسیسنگ کا crop اسی تناسب میں ہوتا ہے

  const _IndividualPhotoTile({
    required this.photo,
    required this.hasProcessed,
    required this.isUrdu,
    required this.focusNode,
    required this.textInputAction,
    required this.onRemove,
    required this.onCropRequested,
    required this.onNameChanged,
    required this.onSubmitted,
    required this.targetAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final urduStyle = TextStyle(fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null);
    final imageFile = File(photo.processedPath ?? photo.imagePath);
    final String displayName = photo.customName?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            child: hasProcessed
                // 🌟 پروسیسنگ کے بعد: کنفرمیشن کے ساتھ اصل فائنل سائز/ڈائمنشن دکھائیں
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 9, color: Colors.green.shade700),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          "${photo.finalSizeKB ?? 0} KB | ${photo.width}x${photo.height}",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  )
                // 🌟 پروسیسنگ سے پہلے: اصل (original) فائل کا سائز اور ڈائمنشن دکھائیں
                : Text(
                    "${AppStrings.text('unprocessed', isUrdu)} | ${photo.originalSizeDisplay ?? '...'} | ${photo.width}x${photo.height}",
                    style: urduStyle.copyWith(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: GestureDetector(
                      onTap: onCropRequested,
                      // 🌟 فکس: پروسیسنگ اب crop نہیں کرتی بلکہ پوری تصویر کو
                      // ہدف کے تناسب پر اسٹریچ/سکوئز کرتی ہے — اس لیے preview
                      // بھی BoxFit.fill سے بالکل وہی دکھاتی ہے (کوئی حصہ کٹتا
                      // نظر نہیں آئے گا، پوری تصویر بس تھوڑی کھنچی ہوئی نظر
                      // آئے گی، بالکل ویسے جیسے حتمی نتیجہ ہوگا)۔
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: targetAspectRatio,
                          child: ClipRect(
                            child: Image.file(
                              imageFile,
                              fit: BoxFit.fill,
                              cacheWidth: 256,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (onCropRequested != null)
                  Positioned(
                    bottom: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(4)),
                      child: const Icon(Icons.crop, color: Colors.white, size: 12),
                    ),
                  ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: onRemove,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 🌟 پروسیسنگ سے پہلے: نام لکھنے کا خانہ (Tab/Next سے اگلے خانے پر خودکار فوکس)
          // 🌟 پروسیسنگ کے بعد: خانہ مکمل طور پر غائب — صرف لکھا ہوا نام (اگر موجود ہو) دکھایا جائے
          if (!hasProcessed)
            Padding(
              padding: const EdgeInsets.all(3.0),
              child: SizedBox(
                height: 24,
                child: TextField(
                  focusNode: focusNode,
                  textInputAction: textInputAction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    hintText: AppStrings.text('nameRollNo', isUrdu),
                    hintStyle: urduStyle.copyWith(fontSize: 8, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: kSealGreen)),
                  ),
                  onChanged: onNameChanged,
                  onSubmitted: (_) => onSubmitted(),
                ),
              ),
            )
          else if (displayName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}