import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/features/onboarding/onboarding_screen.dart';
import 'package:duitkita/models/user_profile.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/widgets/help_sheet.dart';
import 'package:duitkita/widgets/floating_field.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>(
  (_) => PackageInfo.fromPlatform(),
);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingImage = false;

  // ─── Avatar picker ─────────────────────────────────────────────────────────
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Change photo', style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _PhotoOption(icon: Icons.camera_alt_outlined, label: 'Camera', onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); })),
                  const SizedBox(width: 14),
                  Expanded(child: _PhotoOption(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); })),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (picked == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512, maxHeight: 512, compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop Photo', toolbarColor: const Color(0xFF0B1F3A), toolbarWidgetColor: Colors.white, activeControlsWidgetColor: DT.accent, lockAspectRatio: true),
          IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: true, resetAspectRatioEnabled: false),
        ],
      );
      if (cropped == null) return;
      if (!mounted) return;
      setState(() => _isUploadingImage = true);
      final url = await ref.read(storageServiceProvider).uploadProfileImage(userId: userId, file: File(cropped.path));
      await ref.read(profileServiceProvider).setProfileImageUrl(userId, url);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // ─── Help overlay ──────────────────────────────────────────────────────────
  void _showHelp() {
    showHelpSheet(context, onShowIntro: _showOnboarding);
  }

  void _showOnboarding() {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => OnboardingScreen(
        onDone: () => Navigator.of(context).pop(),
      ),
    ));
  }

  // ─── Sign out ──────────────────────────────────────────────────────────────
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.logout_rounded, color: DT.danger, size: 26),
              ),
              const SizedBox(height: 16),
              Text('Sign out?', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
              const SizedBox(height: 8),
              Text('You\'ll need to sign in again to access your data.', textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _OutlineBtn(label: 'Cancel', onTap: () => Navigator.pop(ctx))),
                const SizedBox(width: 12),
                Expanded(child: _FilledBtn(label: 'Sign out', color: DT.danger, onTap: () {
                  Navigator.pop(ctx); // close the confirm dialog
                  // Drop every pushed route first. ProfileScreen sits on top of
                  // AuthWrapper's home route, so swapping home -> LoginScreen
                  // would otherwise leave this screen covering it, rendering
                  // the "Not logged in" placeholder instead of the login form.
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  ref.read(authControllerProvider.notifier).signOut();
                })),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Email migration ───────────────────────────────────────────────────────
  Future<void> _migrateEmail(String uid, String email) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'email': email});
      if (!mounted) return;
      ref.invalidate(userProfileStreamProvider(uid));
      messenger.showSnackBar(const SnackBar(content: Text('Email added to profile')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  // ─── Edit profile ──────────────────────────────────────────────────────────
  void _showEditProfile(UserProfile profile) {
    final nameCtrl = TextEditingController(text: profile.name ?? '');
    final phoneCtrl = TextEditingController(text: profile.phoneNumber ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Edit profile', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
                const SizedBox(height: 20),
                FloatingField(controller: nameCtrl, gap: 0, label: 'Full name', icon: Icons.person_outline_rounded, hint: 'Your full name', capitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                FloatingField(controller: phoneCtrl, gap: 0, label: 'Phone number', icon: Icons.phone_outlined, hint: 'e.g. 012-3456789', keyboardType: TextInputType.phone),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: saving ? null : () async {
                    setSheetState(() => saving = true);
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(sheetCtx);
                    try {
                      final updated = profile.copyWith(
                        name: nameCtrl.text.trim(),
                        phoneNumber: phoneCtrl.text.trim(),
                      );
                      await ref.read(profileServiceProvider).updateUserProfile(updated);
                      if (!mounted) return;
                      nav.pop();
                      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                    } finally {
                      if (mounted) setSheetState(() => saving = false);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(14)),
                    child: Center(
                      child: saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Save changes', style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final userEmail = ref.watch(authControllerProvider.notifier).currentUser?.email;
    final packageInfo = ref.watch(_packageInfoProvider).valueOrNull;
    final versionLabel = packageInfo != null ? 'v${packageInfo.version}' : '';

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final profileAsync = ref.watch(userProfileStreamProvider(userId));

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: const BoxDecoration(color: DT.dangerSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.cloud_off_rounded, color: DT.danger, size: 26),
                  ),
                  const SizedBox(height: 14),
                  Text('Couldn\'t load your profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: DT.text)),
                  const SizedBox(height: 6),
                  Text('Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => ref.invalidate(userProfileStreamProvider(userId)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(12)),
                      child: Text('Retry',
                          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (profile) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Page title ──────────────────────────────────
                Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: DT.surface,
                              borderRadius: BorderRadius.circular(DS.md),
                              border: Border.all(color: DT.border),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 18, color: DT.text),
                          ),
                        ),
                      ),
                    Text(
                      'Profile',
                      style: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Identity card ────────────────────────────────
                GestureDetector(
                  onTap: profile != null ? () => _showEditProfile(profile) : null,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DT.surface,
                      borderRadius: BorderRadius.circular(DS.cardRadius),
                      border: Border.all(color: DT.border),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: _showImagePicker,
                          child: Stack(
                            children: [
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: DT.accentSoft,
                                  image: profile?.profileImageUrl != null
                                      ? DecorationImage(image: NetworkImage(profile!.profileImageUrl!), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: profile?.profileImageUrl == null
                                    ? Center(
                                        child: Text(
                                          _initials(profile?.name ?? userEmail ?? '?'),
                                          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: DT.accentDeep),
                                        ),
                                      )
                                    : null,
                              ),
                              if (_isUploadingImage)
                                Container(
                                  width: 64, height: 64,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)),
                                  child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                                ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(color: DT.text, shape: BoxShape.circle, border: Border.all(color: DT.surface, width: 2)),
                                  child: const Icon(Icons.camera_alt_rounded, size: 11, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.name ?? 'Set your name',
                                style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userEmail ?? profile?.email ?? 'No email',
                                style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary),
                              ),
                              if (profile?.phoneNumber?.isNotEmpty == true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  profile!.phoneNumber!,
                                  style: GoogleFonts.manrope(fontSize: 12, color: DT.textTertiary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: DT.textTertiary),
                      ],
                    ),
                  ),
                ),

                // ── Email migration banner ───────────────────────
                if (profile?.email == null && userEmail != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _migrateEmail(userId, userEmail),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: DT.warningSoft,
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                        border: Border.all(color: DT.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: DT.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tap to sync email to your profile for group features.',
                              style: GoogleFonts.manrope(fontSize: 12, color: DT.warning, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: DT.warning),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Settings card ────────────────────────────────
                _SectionLabel(label: 'SETTINGS'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: DT.surface,
                    borderRadius: BorderRadius.circular(DS.cardRadius),
                    border: Border.all(color: DT.border),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.help_outline_rounded,
                        iconBg: DT.accentSoft,
                        iconColor: DT.accentDeep,
                        label: 'How DuitKita works',
                        onTap: _showHelp,
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.security_outlined,
                        iconBg: DT.catDebtsSoft,
                        iconColor: DT.catDebts,
                        label: 'Security & privacy',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon'))),
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.notifications_outlined,
                        iconBg: DT.catBillsSoft,
                        iconColor: DT.catBills,
                        label: 'Notifications',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon'))),
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.sports_soccer_rounded,
                        iconBg: const Color(0xFFFFEBEE),
                        iconColor: const Color(0xFFD32F2F),
                        label: 'Show JDT Matches tab',
                        onTap: () {},
                        showChevron: false,
                        trailing: Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: profile?.showJdtMatches ?? false,
                            onChanged: (value) async {
                              if (profile == null) return;
                              await ref.read(profileServiceProvider).updateUserProfile(
                                    profile.copyWith(showJdtMatches: value),
                                  );
                            },
                            activeThumbColor: const Color(0xFFD32F2F),
                            activeTrackColor: const Color(0xFFEF9A9A),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        iconBg: DT.surfaceAlt,
                        iconColor: DT.textSecondary,
                        label: 'About DuitKita',
                        onTap: () => _showAbout(context, versionLabel),
                        showChevron: true,
                        trailing: Text(versionLabel, style: GoogleFonts.manrope(fontSize: 12, color: DT.textTertiary)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Sign out ─────────────────────────────────────
                GestureDetector(
                  onTap: _confirmSignOut,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: DT.dangerSoft,
                      borderRadius: BorderRadius.circular(DS.cardRadius),
                      border: Border.all(color: DT.danger.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, size: 18, color: DT.danger),
                        const SizedBox(width: 8),
                        Text('Sign out', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.danger)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  void _showAbout(BuildContext context, String versionLabel) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: DT.accentSoft, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 30, color: DT.accentDeep),
              ),
              const SizedBox(height: 16),
              Text('DuitKita', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: DT.text)),
              const SizedBox(height: 4),
              Text('Version $versionLabel', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
              const SizedBox(height: 12),
              Text(
                'Track group contributions, loans, and recurring bills — all in one place.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  width: double.infinity,
                  decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('Close', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool showChevron;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.showChevron = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.text)),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
          if (showChevron) const Icon(Icons.chevron_right_rounded, size: 18, color: DT.textTertiary),
        ],
      ),
    ),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(height: 1, margin: const EdgeInsets.only(left: 66), color: DT.border);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.textTertiary, letterSpacing: 0.8),
  );
}

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PhotoOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: DT.accentSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, size: 28, color: DT.accentDeep),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: DT.accentDeep)),
        ],
      ),
    ),
  );
}


class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.border),
      ),
      child: Center(child: Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text))),
    ),
  );
}

class _FilledBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FilledBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
    ),
  );
}
