// lib/screens/grid_crop_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/grid_settings.dart';
import '../services/image_service.dart';
import '../services/grid_service.dart';
import '../utils/app_colors.dart'; // 🌟 برانڈ رنگ — ہوم اسکرین جیسا سیل گرین/گولڈ تھیم
import 'crop_result_screen.dart';

class GridCropScreen extends StatefulWidget {
  final GridSettings initialSettings;

  const GridCropScreen({super.key, required this.initialSettings});

  @override
  State<GridCropScreen> createState() => _GridCropScreenState();
}

class _GridCropScreenState extends State<GridCropScreen> {
  late GridSettings _settings;
  File? _selectedImage;
  ui.Image? _decodedImage; // 🌟 اصل تصویر کی ڈائمنشنز کے لیے
  bool _isProcessing = false;

  // 🌟 Rows/Columns کے لیے انپٹ باکس کنٹرولرز
  late TextEditingController _rowsCtrl;
  late TextEditingController _colsCtrl;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _rowsCtrl = TextEditingController(text: _settings.rows.toString());
    _colsCtrl = TextEditingController(text: _settings.cols.toString());
  }

  @override
  void dispose() {
    _rowsCtrl.dispose();
    _colsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final uiImage = await decodeImageFromList(bytes); // 🌟 تصویر کو UI لیول پر ڈیکوڈ کریں

      setState(() {
        _selectedImage = File(pickedFile.path);
        _decodedImage = uiImage;
      });
    }
  }

  Future<void> _processGrid() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final isValid = await GridService.validateImageDimensions(_selectedImage!.path);
      if (!isValid) {
        throw Exception("تصویر کا سائز یا ریزولیوشن مقررہ حد سے زیادہ ہے۔");
      }

      final croppedPhotos = await GridService.splitGridInIsolate(
        filePath: _selectedImage!.path,
        settings: _settings,
      );

      if (!mounted) return;

      context.read<ImageService>().addPhotos(croppedPhotos);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CropResultScreen(settings: _settings),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 ڈائنامک میکس ویلیوز (تصویر نہ ہو تو ڈیفالٹ 1000)
    final double maxW = _decodedImage?.width.toDouble() ?? 1000.0;
    final double maxH = _decodedImage?.height.toDouble() ?? 1000.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grid Crop Preview'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF1E1E1E), // ڈارک بیک گراؤنڈ
              child: _selectedImage == null
                  ? Center(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('تصویر منتخب کریں'),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.file(_selectedImage!, fit: BoxFit.contain),

                        if (_decodedImage != null)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GridPainter(
                                settings: _settings,
                                image: _decodedImage!,
                              ),
                            ),
                          ),

                        if (_isProcessing)
                          const CircularProgressIndicator(color: kSealGreen),
                      ],
                    ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Grid Dimensions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kSealGreen)),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: _buildIntField('Rows', _rowsCtrl, (val) {
                            setState(() => _settings = _settings.copyWith(rows: val));
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildIntField('Columns', _colsCtrl, (val) {
                            setState(() => _settings = _settings.copyWith(cols: val));
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Text('Spacing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kSealGreen)),
                    const Divider(),
                    _buildSliderPairRow(
                      'Row Spacing', _settings.rowSpacing, 0, 100,
                      (val) => setState(() => _settings = _settings.copyWith(rowSpacing: val)),
                      'Col Spacing', _settings.colSpacing, 0, 100,
                      (val) => setState(() => _settings = _settings.copyWith(colSpacing: val)),
                    ),

                    const SizedBox(height: 16),
                    const Text('Margins (Pixels)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kSealGreen)),
                    const Divider(),
                    _buildSliderPairRow(
                      'Top Margin', _settings.marginTop, 0, maxH / 2,
                      (val) => setState(() => _settings = _settings.copyWith(marginTop: val)),
                      'Bottom Margin', _settings.marginBottom, 0, maxH / 2,
                      (val) => setState(() => _settings = _settings.copyWith(marginBottom: val)),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderPairRow(
                      'Left Margin', _settings.marginLeft, 0, maxW / 2,
                      (val) => setState(() => _settings = _settings.copyWith(marginLeft: val)),
                      'Right Margin', _settings.marginRight, 0, maxW / 2,
                      (val) => setState(() => _settings = _settings.copyWith(marginRight: val)),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSealGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.crop),
                        label: Text(_isProcessing ? 'Processing...' : 'Crop', style: const TextStyle(fontSize: 16)),
                        onPressed: (_selectedImage == null || _isProcessing) ? null : _processGrid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 Rows/Columns کے لیے انپٹ باکس
  Widget _buildIntField(String label, TextEditingController controller, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: kSealGreen, width: 1.5),
            ),
          ),
          onChanged: (val) {
            final n = int.tryParse(val);
            if (n != null && n > 0) onChanged(n);
          },
        ),
      ],
    );
  }

  // 🌟 دو سلائیڈرز ایک ہی لائن میں (Spacing اور Margins کے لیے)
  Widget _buildSliderPairRow(
    String label1, double val1, double min1, double max1, ValueChanged<double> onChanged1,
    String label2, double val2, double min2, double max2, ValueChanged<double> onChanged2,
  ) {
    return Row(
      children: [
        Expanded(child: _buildCompactSlider(label1, val1, min1, max1, onChanged1)),
        const SizedBox(width: 12),
        Expanded(child: _buildCompactSlider(label2, val2, min2, max2, onChanged2)),
      ],
    );
  }

  Widget _buildCompactSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(value.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max <= min ? min + 1 : max,
            activeColor: kSealGreen,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 🌟 پروفیشنل لائیو گرڈ پینٹر
class _GridPainter extends CustomPainter {
  final GridSettings settings;
  final ui.Image image;

  _GridPainter({required this.settings, required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 🌟 applyBoxFit کے ذریعے تصویر کی اصل Display Rect معلوم کریں
    final imgSize = Size(image.width.toDouble(), image.height.toDouble());
    final fittedSizes = applyBoxFit(BoxFit.contain, imgSize, size);

    final destSize = fittedSizes.destination;
    final dx = (size.width - destSize.width) / 2;
    final dy = (size.height - destSize.height) / 2;

    // 2. 🌟 Scale Factors: اصل تصویر کے پکسلز کو کینوس کے پکسلز پر میپ کریں
    final scaleX = destSize.width / imgSize.width;
    final scaleY = destSize.height / imgSize.height;

    canvas.save();
    canvas.translate(dx, dy); // کینوس کو تصویر کے آغاز پر شفٹ کریں

    // 3. اسکیلڈ مارجنز اور اسپیسنگ
    final double sMarginLeft = settings.marginLeft * scaleX;
    final double sMarginRight = settings.marginRight * scaleX;
    final double sMarginTop = settings.marginTop * scaleY;
    final double sMarginBottom = settings.marginBottom * scaleY;
    final double sColSpacing = settings.colSpacing * scaleX;
    final double sRowSpacing = settings.rowSpacing * scaleY;

    final double usableWidth = destSize.width - sMarginLeft - sMarginRight;
    final double usableHeight = destSize.height - sMarginTop - sMarginBottom;

    if (usableWidth <= 0 || usableHeight <= 0) {
      canvas.restore();
      return;
    }

    final double cellWidth = (usableWidth - (sColSpacing * (settings.cols - 1))) / settings.cols;
    final double cellHeight = (usableHeight - (sRowSpacing * (settings.rows - 1))) / settings.rows;

    // 4. پاتھس (Paths) اوورلے اور گرڈ کے لیے
    final fullImgRect = Rect.fromLTWH(0, 0, destSize.width, destSize.height);
    final Path overlayPath = Path()..addRect(fullImgRect);
    final Path cellsPath = Path();

    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    int counter = 1;
    for (int r = 0; r < settings.rows; r++) {
      for (int c = 0; c < settings.cols; c++) {
        final double startX = sMarginLeft + (c * (cellWidth + sColSpacing));
        final double startY = sMarginTop + (r * (cellHeight + sRowSpacing));

        final rect = Rect.fromLTWH(startX, startY, cellWidth, cellHeight);
        cellsPath.addRect(rect); // 🌟 یہ حصہ شفاف (clear) رہے گا
        canvas.drawRect(rect, paint); // سرخ آؤٹ لائن

        // 5. 🌟 ہر سیل پر نمبر (Indicators) دکھائیں
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$counter',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: (cellHeight * 0.3).clamp(10.0, 40.0), // رسپانسیو فونٹ سائز
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1))]
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            startX + (cellWidth - textPainter.width) / 2,
            startY + (cellHeight - textPainter.height) / 2,
          ),
        );
        counter++;
      }
    }

    // 6. 🌟 Semi-Transparent Overlay (مارجن اور کٹنے والے حصوں کو گہرا کریں)
    final darkenedPath = Path.combine(PathOperation.difference, overlayPath, cellsPath);
    final darkPaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(darkenedPath, darkPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.settings != settings || oldDelegate.image != image;
  }
}