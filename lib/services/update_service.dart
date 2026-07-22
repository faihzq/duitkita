import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duitkita/config/design_tokens.dart';

class UpdateService {
  static final _firestore = FirebaseFirestore.instance;

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
          currentBuild: currentBuild,
          latestVersion: latestVersion,
          latestBuild: latestBuild,
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
    required int currentBuild,
    required String latestVersion,
    required int latestBuild,
    required String downloadUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: Dialog(
          backgroundColor: DT.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.heroRadius)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(DS.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: DT.primarySoft,
                        borderRadius: BorderRadius.circular(DS.md),
                      ),
                      child: const Icon(Icons.system_update_rounded, color: DT.text, size: 22),
                    ),
                    const SizedBox(width: DS.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Update Available', style: GoogleFonts.manrope(
                            fontSize: 17, fontWeight: FontWeight.w800, color: DT.text,
                          )),
                          Text('A new version of DuitKita is available.', style: GoogleFonts.manrope(
                            fontSize: 12, color: DT.textSecondary,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DS.lg),

                // ── Version comparison card ──────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: DS.lg, vertical: DS.md),
                  decoration: BoxDecoration(
                    color: DT.surfaceAlt,
                    borderRadius: BorderRadius.circular(DS.cardRadius),
                    border: Border.all(color: DT.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current', style: GoogleFonts.manrope(
                              fontSize: 11, color: DT.textTertiary, fontWeight: FontWeight.w500,
                            )),
                            const SizedBox(height: 2),
                            Text('v$currentVersion ($currentBuild)', style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w700, color: DT.textSecondary,
                            )),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: DT.textTertiary, size: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Latest', style: GoogleFonts.manrope(
                              fontSize: 11, color: DT.textTertiary, fontWeight: FontWeight.w500,
                            )),
                            const SizedBox(height: 2),
                            Text('v$latestVersion ($latestBuild)', style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w700, color: DT.accent,
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Force update warning ─────────────────────────
                if (forceUpdate) ...[
                  const SizedBox(height: DS.md),
                  Container(
                    padding: const EdgeInsets.all(DS.md),
                    decoration: BoxDecoration(
                      color: DT.dangerSoft,
                      borderRadius: BorderRadius.circular(DS.md),
                      border: Border.all(color: DT.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: DT.danger),
                        const SizedBox(width: DS.sm),
                        Expanded(
                          child: Text(
                            'This update is required to continue using the app.',
                            style: GoogleFonts.manrope(
                              fontSize: 12, color: DT.danger, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: DS.xl),

                // ── Actions ──────────────────────────────────────
                Row(
                  children: [
                    if (!forceUpdate) ...[
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: DT.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DS.cardRadius),
                              side: const BorderSide(color: DT.border),
                            ),
                          ),
                          child: Text('Later', style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600, fontSize: 15,
                          )),
                        ),
                      ),
                      const SizedBox(width: DS.md),
                    ],
                    Expanded(
                      flex: forceUpdate ? 1 : 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final uri = Uri.parse(downloadUrl);
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(
                                  'Could not open link.',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DT.text,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DS.cardRadius),
                          ),
                        ),
                        child: Text('Update Now', style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700, fontSize: 15,
                        )),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
