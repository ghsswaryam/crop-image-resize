// lib/models/export_options.dart

/// تصویر کا ایکسپورٹ فارمیٹ
enum ExportFormat {
  jpg,
  png,
  webp,
  bmp,
  tiff,
  original,
}

/// ایکسپورٹ کا موڈ (تصاویر الگ سے محفوظ کرنی ہیں یا ZIP بنانی ہے)
enum ExportMode {
  images,
  zip,
}

class ExportOptions {
  /// تصویر کا مطلوبہ فارمیٹ (Enum کی وجہ سے ٹائپو ایررز کا خطرہ ختم)
  final ExportFormat format;
  
  /// ایکسپورٹ کا موڈ (Images یا Zip)
  final ExportMode mode;
  
  /// فائل کا بنیادی نام (مثلاً: Admission)
  final String baseName;
  
  /// وہ کسٹم فولڈر پاتھ جہاں فائلیں محفوظ ہوں گی
  final String destinationPath;
  
  /// کیا خودکار نمبرنگ آن کرنی ہے؟ (مثلاً: Admission_001.jpg)
  final bool autoNumber;
  
  /// گنتی کہاں سے شروع ہوگی
  final int startNumber;
  
  /// اگر فائل پہلے سے موجود ہو تو کیا اوور رائٹ کرنا ہے؟
  final bool overwriteExisting;
  
  /// کمپریشن کوالٹی (1 سے 100 تک - JPG/WEBP کے لیے)
  final int quality;
  
  /// کیا میٹا ڈیٹا (EXIF) محفوظ رکھنا ہے؟
  final bool preserveMetadata;
  
  /// اگر ZIP موڈ ہو تو اس کا مخصوص نام (опционально)
  final String? zipFileName;

  const ExportOptions({
    this.format = ExportFormat.jpg,
    this.mode = ExportMode.images,
    this.baseName = 'Image',
    required this.destinationPath,
    this.autoNumber = true,
    this.startNumber = 1,
    this.overwriteExisting = false,
    this.quality = 85,
    this.preserveMetadata = true,
    this.zipFileName,
  });

  /// سیٹنگز کو اپڈیٹ کرنے کے لیے کاپی میتھڈ
  ExportOptions copyWith({
    ExportFormat? format,
    ExportMode? mode,
    String? baseName,
    String? destinationPath,
    bool? autoNumber,
    int? startNumber,
    bool? overwriteExisting,
    int? quality,
    bool? preserveMetadata,
    String? zipFileName,
  }) {
    return ExportOptions(
      format: format ?? this.format,
      mode: mode ?? this.mode,
      baseName: baseName ?? this.baseName,
      destinationPath: destinationPath ?? this.destinationPath,
      autoNumber: autoNumber ?? this.autoNumber,
      startNumber: startNumber ?? this.startNumber,
      overwriteExisting: overwriteExisting ?? this.overwriteExisting,
      quality: quality ?? this.quality,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
      zipFileName: zipFileName ?? this.zipFileName,
    );
  }
}