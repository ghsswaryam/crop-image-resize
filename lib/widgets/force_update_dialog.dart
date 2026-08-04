// lib/widgets/force_update_dialog.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_config_service.dart';
import '../utils/app_colors.dart'; // 🌟 برانڈ رنگ — ہوم اسکرین جیسا سیل گرین/گولڈ تھیم

Future<void> showForceUpdateDialog(BuildContext context, ForceUpdateInfo info) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Update Required',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          info.message.isNotEmpty ? info.message : 'A new version of the app is available. Please update to continue.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kSealGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Update Now'),
            onPressed: () async {
              final uri = Uri.parse(info.updateUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    ),
  );
}
