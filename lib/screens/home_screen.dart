// lib/screens/home_screen.dart
import 'package:marquee/marquee.dart'; 
import '../widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../models/grid_settings.dart'; 
import '../services/image_service.dart';
import '../utils/app_strings.dart';
import '../widgets/app_drawer.dart'; 
import 'multi_upload_screen.dart'; 
import 'grid_crop_screen.dart';   
import '../utils/app_colors.dart'; // 🌟 برانڈ رنگ (سیل گرین + گولڈ) — اب مشترکہ فائل سے، تاکہ ہر اسکرین میں یکساں رہے

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key}); 

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  DateTime? currentBackPressTime;
  bool _exitDialogShowing = false; 
  bool _isUrdu = false; 
  final AudioPlayer _audioPlayer = AudioPlayer();

  TextStyle get urduStyle => TextStyle(fontFamily: _isUrdu ? 'NotoNastaliqUrdu' : null);

  late final AnimationController _introController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeIn = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic));
  }

  void _playClickSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('click.mp3'));
    } catch (e) {
      debugPrint("آڈیو چلانے میں مسئلہ: $e");
    }
  }

  Future<void> _onWillPop(BuildContext context) async {
    if (_exitDialogShowing) {
      _exitApp();
      return;
    }

    final now = DateTime.now();
    const maxDuration = Duration(seconds: 2);

    if (currentBackPressTime == null || now.difference(currentBackPressTime!) > maxDuration) {
      currentBackPressTime = now;
      _exitDialogShowing = true;

      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text(
                  "خبردار / Alert",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: const Text(
              "کیا آپ واقعی ایپ بند کرنا چاہتے ہیں؟\nایپ بند کرنے کے لیے دوبارہ بیک دبائیں۔",
              style: TextStyle(fontSize: 15, color: Colors.black87),
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("نہیں / Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _exitApp(); 
                },
                child: const Text("ٹھیک ہے", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );

      _exitDialogShowing = false;
    } else {
      _exitApp(); 
    }
  }

  void _exitApp() {
    if (Theme.of(context).platform == TargetPlatform.android) {
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop(); 
    _audioPlayer.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = context.select<ImageService, bool>((service) => service.isUrdu);
    _isUrdu = isUrdu; 

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onWillPop(context);
      },
      child: Directionality(
        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F8F7),
          drawer: const AppDrawer(), 
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 3),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kSealGreenDark, kSealGreen, kSealGreenLight],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    foregroundColor: Colors.white,
                    title: Align(
                      alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                      child: Text(
                        AppStrings.text('appName', isUrdu),
                        style: urduStyle.copyWith(
                          fontSize: isUrdu ? 22 : 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    centerTitle: false,
                  ),
                  Container(height: 3, color: kGold.withOpacity(0.85)),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    // 🌟 1. درود شریف کا بینر
                                    Container(
                                      height: 42,
                                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.shade200, width: 1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.shade900.withOpacity(0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: TickerMode(
                                          enabled: ModalRoute.of(context)?.isCurrent ?? true,
                                          child: Marquee(
                                            text: 'صلی اللہ علیہ وآلہ وسلم   —   صلی اللہ علیہ وآلہ وسلم   —   صلی اللہ علیہ وآلہ وسلم',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Colors.green.shade800,
                                              fontFamily: 'NotoNastaliqUrdu',
                                            ),
                                            scrollAxis: Axis.horizontal,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            blankSpace: 60.0,
                                            velocity: 35.0, 
                                            startPadding: 10.0,
                                            textDirection: TextDirection.ltr, 
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // 🌟 2. کام کا موڈ سلیکٹ کریں اور کارڈز
                                    FadeTransition(
                                      opacity: _fadeIn,
                                      child: SlideTransition(
                                        position: _slideUp,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24), 
                                          child: Column(
                                            children: [
                                              Column(
                                                children: [
                                                  Text(
                                                    AppStrings.text('selectWorkMode', isUrdu), // اگر یہاں 'selectWorkMode' تھا تو اسے برقرار رکھیں
                                                    style: urduStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold, color: kSealGreenDark),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    height: 3,
                                                    width: 42,
                                                    decoration: BoxDecoration(
                                                      color: kGold,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 20), 

                                              _ModeCard(
                                                title: AppStrings.text('gridPageTitle', isUrdu), 
                                                subtitle: AppStrings.text('gridPageSubtitle', isUrdu),
                                                icon: Icons.grid_view_rounded, 
                                                isUrdu: isUrdu,
                                                onTap: () {
                                                  _playClickSound(); 
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GridCropScreen(
                                                        initialSettings: GridSettings(rows: 5, cols: 4, targetWidth: 600, targetHeight: 800, targetKB: 23),
                                                  )));
                                                },
                                              ),
                                              const SizedBox(height: 16), 

                                              _ModeCard(
                                                title: AppStrings.text('uploadSeparateTitle', isUrdu), 
                                                subtitle: AppStrings.text('uploadSeparateSubtitle', isUrdu),
                                                icon: Icons.photo_library_rounded, 
                                                isUrdu: isUrdu,
                                                onTap: () {
                                                  _playClickSound(); 
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiUploadScreen())); 
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // 🌟 3. نچلا حصہ: Developed By اور فون نمبر (اب ہمیشہ نیچے رہے گا)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: kGold.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(
                                            color: kGold.withOpacity(0.5),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: const Text(
                                          "Developed By: Ghulam Shabbir",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: kSealGreenDark,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.phone_android_rounded,
                                            size: 14,
                                            color: kSealGreen,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            "All Rights Reserved ©2026",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const BannerAdWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isUrdu;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isUrdu,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final urduStyle =
        TextStyle(fontFamily: widget.isUrdu ? 'NotoNastaliqUrdu' : null);

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: kSealGreenDark.withOpacity(_pressed ? 0.05 : 0.08),
              blurRadius: _pressed ? 8 : 18,
              spreadRadius: _pressed ? 0 : 1,
              offset: Offset(0, _pressed ? 2 : 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kSealGreen.withOpacity(0.12), width: 1),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kSealGreen.withOpacity(0.12), kGold.withOpacity(0.14)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: kGold.withOpacity(0.35), width: 1),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 27,
                      color: kSealGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: urduStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          style: urduStyle.copyWith(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kSealGreen.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isUrdu
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: kSealGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
