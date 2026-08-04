import 'dart:typed_data';
import 'package:flutter/foundation.dart';

@immutable
class PhotoItem {
  // 🌟 تمام فیلڈز بشمول 'id' فائنل ہونا ضروری ہیں تاکہ امیوٹیبلٹی (Immutability) برقرار رہے
  final String id;
  final String name;
  final String rollNo;
  final String hash;
  final String imagePath;
  final String? processedPath;
  final Uint8List? originalBytes;
  final Uint8List? processedBytes;
  final bool isProcessing;
  final double rotation;
  final int? finalSizeKB;
  final int width;
  final int height;
  final String? customName;
  final String? originalSizeDisplay; // 🌟 اصل فائل سائز دکھانے کے لیے (مثلاً "1.20 MB")

  const PhotoItem({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.hash,
    required this.imagePath,
    this.processedPath,
    this.originalBytes,
    this.processedBytes,
    this.isProcessing = false,
    this.rotation = 0,
    this.finalSizeKB,
    this.width = 600,
    this.height = 800,
    this.customName,
    this.originalSizeDisplay,
  });

  // 🌟 یہ گیٹر پراسیسڈ پاتھ یا اوریجنل پاتھ حاصل کرنے کے لیے بہترین ہے
  String get path => processedPath ?? imagePath;

  // 🌟 اسٹیٹ مینجمنٹ (State Management) اور لائیو رینیمنگ کے لیے اپڈیٹڈ کاپی ود فنکشن
  PhotoItem copyWith({
    String? id, // آئی ڈی کو تبدیل کرنے کا آپشن (ضرورت پڑنے پر)
    String? name,
    String? rollNo,
    String? hash,
    String? imagePath,
    String? processedPath,
    Uint8List? originalBytes,
    Uint8List? processedBytes,
    bool? isProcessing,
    double? rotation,
    int? finalSizeKB,
    int? width,
    int? height,
    String? customName,
    String? originalSizeDisplay,
    bool clearProcessedPath = false,
    bool clearFinalSizeKB = false,
  }) {
    return PhotoItem(
      id: id ?? this.id, // اگر نئی آئی ڈی نہ دی جائے تو پرانی ہی رہے گی
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      hash: hash ?? this.hash,
      imagePath: imagePath ?? this.imagePath,
      processedPath: clearProcessedPath ? null : (processedPath ?? this.processedPath),
      originalBytes: originalBytes ?? this.originalBytes,
      processedBytes: processedBytes ?? this.processedBytes,
      isProcessing: isProcessing ?? this.isProcessing,
      rotation: rotation ?? this.rotation,
      finalSizeKB: clearFinalSizeKB ? null : (finalSizeKB ?? this.finalSizeKB),
      width: width ?? this.width,
      height: height ?? this.height,
      customName: customName ?? this.customName,
      originalSizeDisplay: originalSizeDisplay ?? this.originalSizeDisplay,
    );
  }
}
