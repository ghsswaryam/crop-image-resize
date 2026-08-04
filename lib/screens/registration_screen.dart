// lib/screens/registration_screen.dart
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/app_config_service.dart';
import 'home_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  bool _saving = false;
  bool _isUrdu = false; // ڈیفالٹ زبان اب انگلش ہے

  // پس منظر کی ہلکی گریڈینٹ حرکت
  late AnimationController _bgController;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  // انٹرو اینیمیشن (لوگو + گلاس کارڈ)
  late AnimationController _introController;
  late Animation<double> _logoScale;
  late Animation<double> _fadeIn;
  late Animation<Offset> _formSlide;

  // لوگو کی مسلسل ہلکی "سانس لینے" (Breathing) جیسی حرکت
  late AnimationController _breatheController;
  late Animation<double> _breatheScale;

  // مقامی متن (Localization strings)
  Map<String, String> get _t => _isUrdu
      ? const {
          'welcome': 'خوش آمدید',
          'subtitle': 'ایپ کو شروع کرنے کے لیے سائن ان کریں',
          'buttonGoogle': 'گوگل کے ساتھ جاری رکھیں',
          'loading': 'لاگ ان ہو رہا ہے...',
          'errorTitle': 'لاگ ان ناکام',
          'errorFirebase': 'فائر بیس لاگ ان میں مسئلہ پیش آیا۔',
          'errorPlatform': 'گوگل سائن ان مکمل نہیں ہو سکا۔',
          'errorGeneric': 'لاگ ان نہیں ہو سکا۔\n\nبراہ کرم دوبارہ کوشش کریں۔',
          'ok': 'ٹھیک ہے',
          'termsPrefix': 'جاری رکھ کر آپ ہماری ',
          'termsLink': 'شرائط و ضوابط',
          'termsMiddle': ' سے متفق ہوتے ہیں',
          'langSwitch': 'EN',
        }
      : const {
          'welcome': 'Welcome',
          'subtitle': 'Sign in to continue to the app',
          'buttonGoogle': 'Continue with Google',
          'loading': 'Signing in...',
          'errorTitle': 'Sign-in Failed',
          'errorFirebase': 'There was a problem signing in with Firebase.',
          'errorPlatform': 'Google sign-in could not be completed.',
          'errorGeneric': 'Unable to sign in.\n\nPlease try again.',
          'ok': 'OK',
          'termsPrefix': 'By continuing, you agree to our ',
          'termsLink': 'Terms & Privacy Policy',
          'termsMiddle': '',
          'langSwitch': 'اردو',
        };

  @override
  void initState() {
    super.initState();

    // ---- پس منظر گریڈینٹ ----
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _topAlignmentAnimation = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));

    _bottomAlignmentAnimation = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));

    // ---- انٹرو اینیمیشن ----
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );

    _fadeIn = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    // ---- لوگو کی Breathing حرکت ----
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _breatheScale = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _breatheController.repeat(reverse: true);
      }
    });

    _introController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _introController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  // 🌟 خوبصورت ایرر ڈائیلاگ
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: _isUrdu ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFC62828)),
              const SizedBox(width: 8),
              Text(_t['errorTitle']!,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                _t['ok']!,
                style: const TextStyle(
                    color: Color(0xFF0B6E4F), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 ورژن 1 کا مستحکم گوگل لاگ ان لاجک
  Future<void> _signInWithGoogle() async {
    setState(() => _saving = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _saving = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint("Logged in user: ${userCredential.user?.email}");
      
      await AppConfigService.registerDevice();
      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Error: ${e.code}");
      debugPrint(e.message);
      _showErrorDialog(_t['errorFirebase']!);
    } on PlatformException catch (e) {
      debugPrint("Platform Error: ${e.code}");
      debugPrint(e.message);
      _showErrorDialog(_t['errorPlatform']!);
    } catch (e) {
      debugPrint(e.toString());
      _showErrorDialog(_t['errorGeneric']!);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleLanguage() {
    setState(() => _isUrdu = !_isUrdu);
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isUrdu ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ---- پس منظر: ہلکی اینیمیٹڈ گریڈینٹ ----
            AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [
                        Color(0xFF0B3D2E),
                        Color(0xFF0B6E4F),
                        Color(0xFF14806A),
                        Color(0xFF0B3D2E),
                      ],
                      begin: _topAlignmentAnimation.value,
                      end: _bottomAlignmentAnimation.value,
                    ),
                  ),
                );
              },
            ),

            // ---- زبان تبدیل کرنے کا بٹن ----
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Material(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: _toggleLanguage,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _t['langSwitch']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ---- مرکزی مواد (Minimalist Glassmorphism Style) ----
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // لوگو (Breathing Animation کے ساتھ)
                      ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _breatheScale,
                          builder: (context, child) => Transform.scale(
                            scale: _breatheScale.value,
                            child: child,
                          ),
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.5), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/ic_launcher.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // گلاس مارفیزم کارڈ
                      SlideTransition(
                        position: _formSlide,
                        child: FadeTransition(
                          opacity: _fadeIn,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(maxWidth: 400),
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.25)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      _t['welcome']!,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _t['subtitle']!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                                    const SizedBox(height: 36),

                                    // گوگل سائن ان بٹن
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed:
                                            _saving ? null : _signInWithGoogle,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor:
                                              const Color(0xFF1E1E1E),
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _saving
                                                ? const SizedBox(
                                                    height: 22,
                                                    width: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Color(0xFF0B6E4F),
                                                    ),
                                                  )
                                                : Image.asset(
                                                    'assets/images/google.png',
                                                    height: 24,
                                                  ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _saving
                                                  ? _t['loading']!
                                                  : _t['buttonGoogle']!,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    
                                    // Terms & Privacy
                                    RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7),
                                          height: 1.5,
                                        ),
                                        children: [
                                          TextSpan(text: _t['termsPrefix']),
                                          TextSpan(
                                            text: _t['termsLink'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                          TextSpan(text: _t['termsMiddle']),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
