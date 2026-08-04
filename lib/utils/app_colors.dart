// lib/utils/app_colors.dart
//
// 🌟 برانڈ رنگ پیلٹ (سیل گرین + گولڈ) — پوری ایپ میں یکساں تھیم کے لیے
// یہ رنگ پہلے صرف ہوم اسکرین اور رجسٹریشن اسکرین میں تھے، اب ہر اسکرین
// (Multi Upload, Grid Crop, Crop Result, App Drawer) اسی ایک جگہ سے
// رنگ لے گی تاکہ پوری ایپ میں مکمل مطابقت رہے۔
import 'package:flutter/material.dart';

/// گہرا سیل گرین — گریڈینٹ کا سب سے گہرا حصہ / ہیڈر شیڈو
const Color kSealGreenDark = Color(0xFF0B3D2E);

/// بنیادی برانڈ رنگ — بٹن، آئیکنز، نمایاں متن
const Color kSealGreen = Color(0xFF0B6E4F);

/// ہلکا سیل گرین — گریڈینٹ کا روشن حصہ
const Color kSealGreenLight = Color(0xFF14806A);

/// گولڈ — لہجے، ڈیوائیڈرز اور پریمیم لمس کے لیے
const Color kGold = Color(0xFFD4AF37);

/// عمومی پس منظر رنگ (تمام اسکرینز میں یکساں)
const Color kAppBackground = Color(0xFFF7F8F7);

/// ہیڈر/ایپ بار کے لیے معیاری گریڈینٹ
const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kSealGreenDark, kSealGreen, kSealGreenLight],
);

/// معیاری AppBar بنانے کا مددگار فنکشن — سیل گرین گریڈینٹ + گولڈ لکیر
PreferredSizeWidget buildBrandAppBar({
  required String title,
  required bool isUrdu,
  List<Widget>? actions,
  Widget? leading,
}) {
  final urduStyle = TextStyle(fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null);
  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight + 3),
    child: Container(
      decoration: const BoxDecoration(
        gradient: kBrandGradient,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            leading: leading,
            title: Text(
              title,
              style: urduStyle.copyWith(
                fontSize: isUrdu ? 20 : 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            actions: actions,
          ),
          Container(height: 3, color: kGold.withOpacity(0.85)),
        ],
      ),
    ),
  );
}
