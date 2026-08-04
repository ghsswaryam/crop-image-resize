import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'services/image_service.dart';
import 'services/app_config_service.dart';
import 'screens/home_screen.dart';
import 'screens/registration_screen.dart';
import 'widgets/force_update_dialog.dart';

// 🌟 1. بیک گراؤنڈ میسج ہینڈلر (جب ایپ بند یا کلوز ہو - صرف موبائل کے لیے)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp();
    print("Background message received: ${message.messageId}");
  }
}

Future<void> main() async {
  // Check if platform supports Firebase/AdMob (Android/iOS)
  final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  if (isMobile) {
    runZonedGuarded<Future<void>>(() async {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp();

      // 🌟 2. بیک گراؤنڈ ہینڈلر رجسٹر کریں
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 🌟 Crashlytics: catch Flutter framework errors
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      // 🌟 Crashlytics: catch errors outside the Flutter framework (async, isolates)
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      await MobileAds.instance.initialize(); // 🌟 AdMob

      runApp(const MyApp());
    }, (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    });
  } else {
    // Windows, Linux, macOS ke liye direct app run hogi bina Firebase/AdMob ke
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const MyApp());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Sirf mobile (Android/iOS) par Firebase Messaging chalayein
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // 🌟 3. ٹاپک کو خود بخود جوائن (Subscribe) کرنے کا کوڈ
      FirebaseMessaging.instance.subscribeToTopic('all_users').then((_) {
        print("Subscribed to all_users topic successfully!");
      });

      // 🌟 4. جب ایپ کھلی ہو (Foreground) تب نوٹیفیکیشن ریسیو کرنے کے لیے
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Foreground message data: ${message.notification?.title}');
        
        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification?.body}');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ImageService(),
      child: MaterialApp(
        title: 'Multi Image Tool',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: const Color(0xFF006064),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF006064),
            primary: const Color(0xFF006064),
          ),
          fontFamily: 'NotoNastaliqUrdu',
        ),
        home: const StartupGate(),
      ),
    );
  }
}

/// Decides, on every launch: force-update check (if online) → registration
/// (first launch + online only) → HomeScreen. Fully offline-safe: any step
/// that needs the network is skipped silently if there's no connection.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _ready = false;
  Widget _next = const HomeScreen();

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final online = await AppConfigService.hasInternet();

    if (online) {
      // 1) Force-update check first — block everything else if required
      final forceUpdateInfo = await AppConfigService.checkForceUpdate();
      if (mounted && forceUpdateInfo != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showForceUpdateDialog(context, forceUpdateInfo);
        });
      }

      // 2) One-time registration (only if online AND not already registered)
      final registered = await AppConfigService.isRegistered();
      if (!registered) {
        _next = const RegistrationScreen();
      }
    }
    // If offline: skip both checks entirely, go straight to HomeScreen.

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _next;
  }
}
