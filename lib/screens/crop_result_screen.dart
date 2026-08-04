// lib/screens/crop_result_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/image_service.dart';
import '../services/export_service.dart';
import '../models/photo_item.dart';
import '../models/grid_settings.dart';
import '../models/export_options.dart';
import '../utils/app_colors.dart'; // 🌟 برانڈ رنگ — ہوم اسکرین جیسا سیل گرین/گولڈ تھیم

enum ProcessingState { settings, processing, results }

class CropResultScreen extends StatefulWidget {
  final GridSettings settings;

  const CropResultScreen({super.key, required this.settings});

  @override
  State<CropResultScreen> createState() => _CropResultScreenState();
}

class _CropResultScreenState extends State<CropResultScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- UI Controllers (Step 1) ---
  late TextEditingController widthCtrl;
  late TextEditingController heightCtrl;
  late TextEditingController sizeCtrl;

  // --- UI Controllers (Step 3) ---
  final TextEditingController renameCtrl = TextEditingController();

  // 🌟 ہر تصویر کے رینیم باکس کے لیے علیحدہ FocusNode — کی پیڈ کے "Next"
  // بٹن سے سیدھا اگلے باکس پر جمپ کرنے کے لیے (settings اور results دونوں مراحل میں)
  final Map<String, FocusNode> _renameFocusNodes = {};
  FocusNode _focusFor(String id) => _renameFocusNodes.putIfAbsent(id, () => FocusNode());

  // --- State Variables ---
  ProcessingState _currentState = ProcessingState.settings;
  ExportFormat selectedFormat = ExportFormat.jpg;

  // --- Progress Variables (Step 2) ---
  int _processedCount = 0;
  int _totalCount = 0;
  String _currentFileName = '';
  String _estimatedTime = 'Calculating...';
  bool _isCancelled = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  int _elapsedMs = 0;

  // 🌟 فکس (ANR کی اصل وجہ): پہلے یہاں Timer.periodic ہر 100ms پر پوری
  // اسکرین کو setState سے دوبارہ بناتا تھا۔ اب صرف Stopwatch ہے — لائیو
  // ٹکنگ ڈسپلے کی ذمہ داری الگ، خود مختار _LiveElapsedText widget پر ہے۔
  final Stopwatch _liveStopwatch = Stopwatch();

  late GridSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings;

    widthCtrl = TextEditingController(text: _currentSettings.width.toString());
    heightCtrl = TextEditingController(text: _currentSettings.height.toString());
    sizeCtrl = TextEditingController(text: _currentSettings.targetKB.toString());

    selectedFormat = _currentSettings.format;
  }

  void _startLiveTimer() {
    _liveStopwatch
      ..reset()
      ..start();
  }

  void _stopLiveTimer() {
    _liveStopwatch.stop();
    if (mounted) setState(() => _elapsedMs = _liveStopwatch.elapsedMilliseconds);
  }

  @override
  void dispose() {
    widthCtrl.dispose();
    heightCtrl.dispose();
    sizeCtrl.dispose();
    renameCtrl.dispose();
    for (final node in _renameFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  // ==========================================
  // CORE LOGIC: Settings Update & Processing
  // ==========================================

  void _updateSettingsFromUI() {
    _currentSettings = _currentSettings.copyWith(
      width: int.tryParse(widthCtrl.text) ?? _currentSettings.width,
      height: int.tryParse(heightCtrl.text) ?? _currentSettings.height,
      targetKB: int.tryParse(sizeCtrl.text) ?? _currentSettings.targetKB,
      format: selectedFormat,
    );
  }

  Future<void> _startProcessing(List<PhotoItem> photos) async {
    if (!_formKey.currentState!.validate() || photos.isEmpty) return;

    FocusScope.of(context).unfocus();
    _updateSettingsFromUI();

    setState(() {
      _totalCount = photos.length;
      _currentState = ProcessingState.processing;
      _processedCount = 0;
      _isCancelled = false;
      _elapsedMs = 0;
    });
    _startLiveTimer();

    final imageService = context.read<ImageService>();

    await for (var progressUpdate in imageService.processPhotosAsStream(
      _currentSettings,
      () => _isCancelled,
    )) {
      if (_isCancelled) break;

      if (mounted) {
        setState(() {
          _processedCount = progressUpdate.processedCount;
          _totalCount = progressUpdate.totalCount;
          _currentFileName = progressUpdate.currentFileName;
          _estimatedTime = progressUpdate.estimatedTimeLeft;
          // نوٹ: _elapsedMs اب لائیو ٹائمر سے بھی اپڈیٹ ہوتا رہتا ہے،
          // یہ صرف حتمی/درست ویلیو کی تصدیق کے لیے ہے۔
          _elapsedMs = progressUpdate.elapsedMs;
        });
      }
    }

    _stopLiveTimer();

    if (mounted) {
      if (!_isCancelled) {
        setState(() => _currentState = ProcessingState.results);
      } else {
        setState(() => _currentState = ProcessingState.settings);
      }
    }
  }

  void _cancelProcessing() {
    // 🌟 ImageService اب رواں isolates کو فوراً kill کر دیتی ہے، اس لیے
    // یہاں سے کینسل کرتے ہی پروسیسنگ اسی لمحے رک جائے گی۔
    setState(() => _isCancelled = true);
    _stopLiveTimer();
    context.read<ImageService>().cancelProcessing();
  }

  // ==========================================
  // CORE LOGIC: Secure Storage Directory
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

  Future<void> _saveImagesToCustomFolder(List<PhotoItem> photos) async {
    try {
      // 🌟 پہلے عارضی فولڈر میں صحیح ناموں سے تیار کریں، پھر یوزر سے ایک
      // ہی بار فولڈر پوچھیں — بین الاقوامی ایپس کی طرح۔
      final tempDir = await getTemporaryDirectory();
      final workDir = '${tempDir.path}/img_temp_${DateTime.now().millisecondsSinceEpoch}';
      await Directory(workDir).create(recursive: true);

      final options = ExportOptions(
        format: _currentSettings.format,
        baseName: renameCtrl.text.trim().isNotEmpty ? renameCtrl.text.trim() : 'Student_Image',
        destinationPath: workDir,
        quality: _currentSettings.quality,
      );

      final List<File> preparedFiles = await ExportService.exportImages(photos, options);
      final bool saved = await ExportService.saveImagesWithDialog(preparedFiles);

      if (await Directory(workDir).exists()) {
        await Directory(workDir).delete(recursive: true);
      }

      if (mounted) {
        if (saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تصاویر کامیابی سے محفوظ ہو گئیں'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('محفوظ کرنا منسوخ کر دیا گیا'), backgroundColor: Colors.grey),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ایرر: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAsZip(List<PhotoItem> photos) async {
    if (photos.isEmpty) return;

    setState(() { _isExporting = true; _exportProgress = 0.0; });
    try {
      // 🌟 ZIP عارضی فولڈر میں بنے گی، پھر نیٹو Save-As ڈائیلاگ سے یوزر
      // خود فولڈر اور نام منتخب کرے گا۔
      final tempDir = await getTemporaryDirectory();
      final zipWorkDir = '${tempDir.path}/zip_temp_${DateTime.now().millisecondsSinceEpoch}';
      await Directory(zipWorkDir).create(recursive: true);

      final options = ExportOptions(
        format: _currentSettings.format,
        baseName: renameCtrl.text.trim().isNotEmpty ? renameCtrl.text.trim() : 'Student_Image',
        destinationPath: zipWorkDir,
        quality: _currentSettings.quality,
      );

      final zipFile = await ExportService.createZipWithProgress(
        photos: photos,
        options: options,
        checkCancel: () => false,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _exportProgress = progress);
        },
      );

      final String suggestedName =
          'Admissions_Export_${DateTime.now().millisecondsSinceEpoch}.zip';
      final String? savedPath =
          await ExportService.saveFileWithDialog(zipFile, suggestedName: suggestedName);

      if (await Directory(zipWorkDir).exists()) {
        await Directory(zipWorkDir).delete(recursive: true);
      }

      if (!mounted) return;
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ZIP کامیابی سے محفوظ ہو گئی:\n$savedPath'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('محفوظ کرنا منسوخ کر دیا گیا'), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ایرر: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isExporting = false; _exportProgress = 0.0; });
      }
    }
  }

  // ==========================================
  // UI BUILDER
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final photos = context.watch<ImageService>().photos;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('ملٹی امیج کراپ ریسائز اینڈ رینیم'), centerTitle: true),
      body: SafeArea(
        child: photos.isEmpty
            ? const Center(child: Text('کوئی تصویر موجود نہیں'))
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildBody(theme, photos),
              ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, List<PhotoItem> photos) {
    switch (_currentState) {
      case ProcessingState.settings: return _buildSettingsStep(theme, photos);
      case ProcessingState.processing: return _buildProcessingStep(theme);
      case ProcessingState.results: return _buildResultsStep(theme, photos);
    }
  }

  // ------------------------------------------
  // STEP 1: SETTINGS + LIVE PREVIEW
  // ------------------------------------------
  Widget _buildSettingsStep(ThemeData theme, List<PhotoItem> photos) {
    return SingleChildScrollView(
      key: const ValueKey('settings'),
      padding: const EdgeInsets.all(14.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Target Dimension & Size', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kSealGreen)),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTextField('Width (px)', widthCtrl, isQuality: false)),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField('Height (px)', heightCtrl, isQuality: false)),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField('Size (KB)', sizeCtrl, isQuality: false)),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<ExportFormat>(
              value: selectedFormat,
              decoration: const InputDecoration(
                labelText: 'Export Format',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                ExportFormat.jpg,
                ExportFormat.png,
                ExportFormat.original,
              ].map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (v) => setState(() => selectedFormat = v!),
            ),
            const SizedBox(height: 20),

            const Text('Live Grid Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kSealGreen)),
            const Divider(),

            photos.isEmpty
                ? Container(
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: const Text('کوئی تصویر موجود نہیں', style: TextStyle(color: Colors.grey)),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) => _buildPreviewTile(
                      photos[index],
                      isLast: index == photos.length - 1,
                      onSubmitted: () {
                        if (index < photos.length - 1) {
                          FocusScope.of(context).requestFocus(_focusFor(photos[index + 1].id));
                        } else {
                          FocusScope.of(context).unfocus();
                        }
                      },
                    ),
                  ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 6,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Resize and Rename', style: TextStyle(fontSize: 18)),
              onPressed: photos.isEmpty ? null : () => _startProcessing(photos),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 ہر کراپ شدہ تصویر کا تھمب نیل + رینیم باکس (کی پیڈ "Next" کے ساتھ)
  Widget _buildPreviewTile(PhotoItem photo, {required bool isLast, required VoidCallback onSubmitted}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
              child: Image.file(
                File(photo.imagePath),
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 26,
          child: TextFormField(
            initialValue: photo.customName ?? '',
            focusNode: _focusFor(photo.id),
            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              hintText: photo.name,
              hintStyle: const TextStyle(fontSize: 8, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onChanged: (val) {
              context.read<ImageService>().updatePhoto(photo.copyWith(customName: val));
            },
            onFieldSubmitted: (_) => onSubmitted(),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------
  // STEP 2: PROCESSING
  // ------------------------------------------
  Widget _buildProcessingStep(ThemeData theme) {
    double progress = _totalCount > 0 ? (_processedCount / _totalCount) : 0.0;

    return Center(
      key: const ValueKey('processing'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_processedCount / $_totalCount images', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('${(progress * 100).toInt()}%', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: kSealGreen)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 14,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(kSealGreen),
              ),
            ),
            const SizedBox(height: 20),
            Text('Processing: $_currentFileName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kSealGreenLight), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LiveElapsedText(stopwatch: _liveStopwatch, isRunning: true),
                Text('Remaining: $_estimatedTime', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('Cancel Processing', style: TextStyle(color: Colors.red)),
              onPressed: _cancelProcessing,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------
  // STEP 3: RESULTS & EXPORT
  // ------------------------------------------
  Widget _buildResultsStep(ThemeData theme, List<PhotoItem> photos) {
    if (_isExporting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Exporting... ${(_exportProgress * 100).toInt()}%'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('results'),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 6),
              Text(
                '${photos.length} تصاویر تیار ہو گئیں — ذیل میں ہر تصویر کا نام اور حتمی سائز/ڈائمنشن دیکھیں',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🌟 اب رزلٹ ایک بڑی سنگل پریویو کی بجائے اسی گرڈ شکل میں دکھایا
          // جاتا ہے جو سیٹنگز اسٹیپ میں تھا — ہر تصویر کا وہی نام جو پہلے
          // لکھا گیا تھا، ساتھ حتمی KB اور چوڑائی×لمبائی کی تصدیق کے ساتھ۔
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
              childAspectRatio: 0.62,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) => _buildResultTile(photos[index]),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: renameCtrl,
            decoration: const InputDecoration(
              labelText: 'Base File Name (e.g., Reg_Form) — اگر کسی تصویر کا اپنا نام نہ لکھا گیا ہو تو یہی استعمال ہو گا',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.folder),
                  label: const Text('Save Images'),
                  onPressed: () => _saveImagesToCustomFolder(photos),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.folder_zip),
                  label: const Text('Save as ZIP'),
                  onPressed: () => _exportAsZip(photos),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            icon: const Icon(Icons.arrow_back), label: const Text('Back to Settings'),
            onPressed: () => setState(() => _currentState = ProcessingState.settings),
          )
        ],
      ),
    );
  }

  // 🌟 رزلٹ گرڈ کی ٹائل: تصویر + لکھا ہوا نام + پروسیسنگ کے بعد کا اصل
  // سائز (KB) اور ڈائمنشن (width x height) — تاکہ صارف تصدیق کر سکے کہ
  // ری سائز واقعی مطلوبہ سیٹنگز کے مطابق ہوا ہے۔
  Widget _buildResultTile(PhotoItem photo) {
    final String path = photo.processedPath ?? photo.imagePath;
    final String displayName = (photo.customName != null && photo.customName!.trim().isNotEmpty)
        ? photo.customName!.trim()
        : photo.name;
    final bool hitTarget = photo.finalSizeKB != null && photo.finalSizeKB! <= _currentSettings.targetKB;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hitTarget ? Icons.check_circle : Icons.info,
              size: 8,
              color: hitTarget ? Colors.green.shade700 : Colors.orange.shade700,
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                '${photo.finalSizeKB ?? '?'} KB | ${photo.width}x${photo.height}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: hitTarget ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {required bool isQuality}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        final number = int.tryParse(value);
        if (number == null) {
          return 'Invalid number';
        }
        if (number <= 0) {
          return 'Must be > 0';
        }
        if (isQuality && (number < 1 || number > 100)) {
          return 'Range 1-100';
        }
        return null;
      },
    );
  }
}

/// 🌟 خود مختار elapsed-time ٹکر — صرف خود کو ہر 100ms میں ری بلڈ کرتی ہے،
/// پیرنٹ اسکرین کو بالکل نہیں چھیڑتی (ANR سے بچاؤ کے لیے)۔
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
        if (mounted) setState(() {});
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
    return Text('Elapsed: ${seconds.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.grey, fontSize: 13));
  }
}
