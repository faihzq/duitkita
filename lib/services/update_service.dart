import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duitkita/config/app_theme.dart';

class UpdateService {
  static final _firestore = FirebaseFirestore.instance;

  /// Check for app updates by comparing installed version with Firestore config.
  /// Firestore doc: app_config/version
  /// Fields: { latestVersion: "1.1.0", buildNumber: 2, downloadUrl: "https://...", forceUpdate: false }
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final doc = await _firestore.collection('app_config').doc('version').get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final latestVersion = data['latestVersion'] as String? ?? '';
      final latestBuild = (data['buildNumber'] as int?) ?? 0;
      final downloadUrl = data['downloadUrl'] as String? ?? '';
      final forceUpdate = data['forceUpdate'] as bool? ?? false;

      if (latestVersion.isEmpty || downloadUrl.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (latestBuild > currentBuild && context.mounted) {
        _showUpdateDialog(
          context,
          currentVersion: packageInfo.version,
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          forceUpdate: forceUpdate,
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String downloadUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.system_update, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Update Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A new version of DuitKita is available.',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                          Text('v$currentVersion', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: AppTheme.textHint, size: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Latest', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                          Text('v$latestVersion', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (forceUpdate) ...[
                const SizedBox(height: 12),
                const Text('This update is required to continue using the app.',
                  style: TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(downloadUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Could not open link. Please visit: $downloadUrl')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
