import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/utils/utils.dart';

class UpdateService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final doc =
          await _firestore.collection('app_config').doc('version').get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final latestVersion = data['latestVersion'] as String? ?? '';
      final latestBuild = (data['buildNumber'] as int?) ?? 0;
      final downloadUrl = data['downloadUrl'] as String? ?? '';
      final forceUpdate = data['forceUpdate'] as bool? ?? false;

      // Play's own updater is preferred where it works: it installs without
      // leaving the app, and it can only offer a build that is actually
      // published — the config document can drift ahead of the store and
      // advertise a version nobody can install.
      //
      // It answers only for copies installed from Play, so a sideloaded build
      // throws and drops through to the dialog below. `forceUpdate` still comes
      // from Firestore, since Play's own priority signal can only be set
      // through the Publishing API at upload time.
      if (await _tryPlayUpdate(force: forceUpdate)) return;

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

  /// Returns true when Play has handled the question — including when it says
  /// the app is already current, because Play is authoritative for copies it
  /// installed and falling through would show a dialog contradicting it.
  ///
  /// Returns false only when Play cannot answer: another platform, a sideloaded
  /// or debug build, or no Play Store on the device.
  static Future<bool> _tryPlayUpdate({required bool force}) async {
    if (!Platform.isAndroid) return false;

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return true;
      }

      // Immediate blocks the app behind a full-screen Play flow; keep it for
      // releases actually marked as required, and only when Play says the
      // device can run it. Everything else downloads in the background.
      if (force && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }

      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
        return true;
      }

      // Play has an update but will run neither flow on this device. Let the
      // dialog offer the store link rather than saying nothing.
      return false;
    } catch (e) {
      // The common case, not an error: this copy did not come from Play.
      debugPrint('Play in-app update unavailable, using the link flow: $e');
      return false;
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
      builder:
          (ctx) => PopScope(
            canPop: !forceUpdate,
            child: Dialog(
              backgroundColor: DT.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.heroRadius),
              ),
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: DT.primarySoft,
                            borderRadius: BorderRadius.circular(DS.md),
                          ),
                          child: const Icon(
                            Icons.system_update_rounded,
                            color: DT.text,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: DS.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Update Available',
                                style: GoogleFonts.manrope(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: DT.text,
                                ),
                              ),
                              Text(
                                'A new version of DuitKita is available.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: DT.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DS.lg),

                    // ── Version comparison card ──────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.lg,
                        vertical: DS.md,
                      ),
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
                                Text(
                                  'Current',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: DT.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'v$currentVersion ($currentBuild)',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: DT.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: DT.textTertiary,
                            size: 16,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Latest',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: DT.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'v$latestVersion ($latestBuild)',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: DT.accent,
                                  ),
                                ),
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
                          border: Border.all(
                            color: DT.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: DT.danger,
                            ),
                            const SizedBox(width: DS.sm),
                            Expanded(
                              child: Text(
                                'This update is required to continue using the app.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: DT.danger,
                                  fontWeight: FontWeight.w600,
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    DS.cardRadius,
                                  ),
                                  side: const BorderSide(color: DT.border),
                                ),
                              ),
                              child: Text(
                                'Later',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
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
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (e) {
                                if (ctx.mounted) {
                                  showSnackBar(
                                    ctx,
                                    'Could not open link.',
                                    isError: true,
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DT.text,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  DS.cardRadius,
                                ),
                              ),
                            ),
                            child: Text(
                              'Update Now',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
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
