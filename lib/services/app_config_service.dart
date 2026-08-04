// lib/services/app_config_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForceUpdateInfo {
  final bool forceUpdate;
  final String updateUrl;
  final String message;
  ForceUpdateInfo({required this.forceUpdate, required this.updateUrl, required this.message});
}

class AppConfigService {
  static const _kIsRegistered = 'is_registered';

  static Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsRegistered) ?? false;
  }

  static Future<void> _markRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsRegistered, true);
  }

  /// بغیر نام کے صرف ڈیوائس کا ماڈل اور پلیٹ فارم فائر بیس میں محفوظ کرتا ہے
  static Future<void> registerDevice() async {
    String deviceModel = 'Unknown';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceModel = '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceModel = info.utsname.machine;
      }
    } catch (_) {}

    try {
      if (await hasInternet()) {
        await FirebaseFirestore.instance.collection('users').add({
          'device_model': deviceModel,
          'platform': Platform.operatingSystem,
          'created_at': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}

    await _markRegistered();
  }

  static Future<ForceUpdateInfo?> checkForceUpdate() async {
    if (!await hasInternet()) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) return null;
      final data = doc.data()!;

      final minVersion = (data['min_version'] ?? '').toString();
      final forceUpdate = (data['force_update'] ?? false) as bool;
      final updateUrl = (data['update_url'] ?? '').toString();
      final message = (data['message'] ?? 'A new version is available. Please update to continue.').toString();

      if (!forceUpdate || minVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final isOutdated = _isVersionLower(packageInfo.version, minVersion);

      if (isOutdated) {
        return ForceUpdateInfo(forceUpdate: true, updateUrl: updateUrl, message: message);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isVersionLower(String current, String minRequired) {
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final m = minRequired.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = c.length > m.length ? c.length : m.length;
    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = i < m.length ? m[i] : 0;
      if (cv != mv) return cv < mv;
    }
    return false;
  }
}