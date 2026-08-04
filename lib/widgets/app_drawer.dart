import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/image_service.dart';
import '../utils/app_strings.dart'; 
import '../utils/app_colors.dart'; // 🌟 برانڈ رنگ — ہوم اسکرین جیسا سیل گرین/گولڈ تھیم
import 'feedback_dialog.dart'; // فیڈبیک ڈائیلاگ کی فائل کا امپورٹ

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageService>(
      builder: (context, service, child) {
        final isUrdu = service.isUrdu;
        final urduStyle = TextStyle(fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null);

        return Directionality(
          textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
          child: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(gradient: kBrandGradient),
                  child: Center(
                    child: Text(
                      AppStrings.text('appName', isUrdu), // 🛠️ فکس: ایپ کا نام[span_1](start_span)[span_1](end_span)
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home, color: kSealGreen),
                  title: Text(AppStrings.text('home', isUrdu), style: urduStyle), // 🛠️ فکس: ہوم[span_2](start_span)[span_2](end_span)
                  onTap: () {
                    Navigator.pop(context);
                    // ہوم پر جانے کا منطقی طریقہ[span_3](start_span)[span_3](end_span)
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language, color: kSealGreen),
                  title: Text(AppStrings.text('language', isUrdu), style: urduStyle), // 🛠️ فکس: زبان[span_4](start_span)[span_4](end_span)
                  onTap: () {
                    service.toggleLanguage();
                    Navigator.pop(context);
                  },
                ),
                
                // --- مینو کو الگ کرنے والی لائن ---
                const Divider(),
                
                // --- صرف فیڈبیک کا آپشن ---
                ListTile(
                  leading: const Icon(Icons.rate_review_outlined, color: Colors.amber),
                  title: Text(isUrdu ? 'اپنی رائے دیں' : 'Feedback', style: urduStyle),
                  onTap: () {
                    Navigator.pop(context); // پہلے ڈراور بند کریں
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      builder: (context) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: const FeedbackSheet(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
