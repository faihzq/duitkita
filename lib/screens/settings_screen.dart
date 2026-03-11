import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/user_profile.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/screens/kyc_verification_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  bool _hasLoadedInitialData = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _hasLoadedInitialData = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId != null) {
      _hasLoadedInitialData = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
        if (userId != null) {
          final profileAsync = ref.read(userProfileStreamProvider(userId));
          profileAsync.whenData((profile) {
            if (profile != null && mounted) {
              _nameController.text = profile.name ?? '';
              _phoneController.text = profile.phoneNumber ?? '';
            }
          });
        }
      }
    });
  }

  Future<void> _updateProfile() async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final profileService = ref.read(profileServiceProvider);
      final currentProfile = await profileService.getUserProfile(userId);

      if (currentProfile != null) {
        final updatedProfile = currentProfile.copyWith(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );
        await profileService.updateUserProfile(updatedProfile);

        if (mounted) {
          showSnackBar(context, 'Profile updated successfully');
          setState(() => _isEditing = false);
        }
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to update profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _migrateEmail() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      if (mounted) showSnackBar(context, 'No email found to migrate', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'email': currentUser.email});

      if (mounted) {
        showSnackBar(context, 'Email added to profile successfully!');
        ref.invalidate(userProfileStreamProvider(currentUser.uid));
      }
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to add email: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Change Profile Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary, size: 28),
                ),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Use your camera', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppTheme.accent, size: 28),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select an existing photo', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final file = File(picked.path);
      final storageService = StorageService();
      final imageUrl = await storageService.uploadProfileImage(
        userId: userId,
        file: file,
      );

      final profileService = ref.read(profileServiceProvider);
      final currentProfile = await profileService.getUserProfile(userId);
      if (currentProfile != null) {
        final updatedProfile = currentProfile.copyWith(profileImageUrl: imageUrl);
        await profileService.updateUserProfile(updatedProfile);
      }

      if (mounted) showSnackBar(context, 'Profile photo updated!');
    } catch (e) {
      if (mounted) showSnackBar(context, 'Failed to update photo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout, color: AppTheme.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authController = ref.read(authControllerProvider.notifier);
    ref.invalidate(authControllerProvider);
    await authController.signOut();

    if (mounted) {
      showSnackBar(context, 'Logged out successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final userEmail = ref.watch(authControllerProvider.notifier).currentUser?.email;

    if (userId == null) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_outlined, size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                const Text('You need to be logged in', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final profileAsync = ref.watch(userProfileStreamProvider(userId));

    profileAsync.whenData((profile) {
      if (profile != null && !_hasLoadedInitialData && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _nameController.text = profile.name ?? '';
              _phoneController.text = profile.phoneNumber ?? '';
              _hasLoadedInitialData = true;
            });
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: profileAsync.when(
        data: (profile) => CustomScrollView(
          slivers: [
            // Profile header
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusXLarge)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      children: [
                        // Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall + 2),
                                    ),
                                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                              ],
                            ),
                            if (!_isEditing)
                              GestureDetector(
                                onTap: _toggleEditMode,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Avatar
                        GestureDetector(
                          onTap: _showImagePickerOptions,
                          child: Stack(
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                                  image: profile?.profileImageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(profile!.profileImageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: profile?.profileImageUrl == null
                                    ? Center(
                                        child: Text(
                                          (profile?.name ?? userEmail ?? '?').isNotEmpty
                                              ? (profile?.name ?? userEmail ?? '?')[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      )
                                    : null,
                              ),
                              if (_isUploadingImage)
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                  child: const Center(
                                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                                  ),
                                ),
                              if (!_isUploadingImage)
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 14, color: AppTheme.primary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile?.name ?? 'No name set',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail ?? 'No email',
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isEditing)
                    _buildEditForm()
                  else ...[
                    _buildProfileInfo(profile),
                    const SizedBox(height: 24),
                    _buildAppSettings(),
                  ],
                ]),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 16),
                Text('Error loading profile: $error', style: const TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _hasLoadedInitialData = false),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(UserProfile? profile) {
    final needsEmailMigration = profile?.email == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Profile Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        ),

        // Info card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildInfoTile(Icons.person_outline, 'Full Name', profile?.name ?? 'Not set'),
              _buildDivider(),
              _buildInfoTile(Icons.email_outlined, 'Email', profile?.email ?? 'Not set in profile'),
              _buildDivider(),
              _buildInfoTile(Icons.phone_outlined, 'Phone', profile?.phoneNumber ?? 'Not set'),
              _buildDivider(),
              _buildInfoTile(
                Icons.calendar_today_outlined, 'Member Since',
                profile?.createdAt != null
                    ? '${profile!.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}'
                    : 'Unknown',
              ),
            ],
          ),
        ),

        // Email migration banner
        if (needsEmailMigration) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Action Required', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Email is not in your profile. Add it for member management features.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _migrateEmail,
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Add Email to Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('App Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        ),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildActionTile(
                icon: Icons.verified_user_outlined,
                iconColor: AppTheme.success,
                title: 'KYC Verification',
                subtitle: 'Complete your profile verification',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const KycVerificationScreen(),
                    ),
                  );
                },
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.notifications_outlined,
                iconColor: AppTheme.accent,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () {
                  showSnackBar(context, 'Coming soon!');
                },
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppTheme.primary,
                title: 'Privacy & Security',
                subtitle: 'Manage your privacy settings',
                onTap: () {
                  showSnackBar(context, 'Coming soon!');
                },
              ),
              _buildDivider(),
              _buildJdtToggle(),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.help_outline,
                iconColor: Colors.blue,
                title: 'Help & Support',
                subtitle: 'Get help or contact support',
                onTap: () {
                  showSnackBar(context, 'Coming soon!');
                },
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.info_outline,
                iconColor: Colors.grey,
                title: 'About',
                subtitle: 'App version and information',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'DuitKita',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2024 DuitKita\nFamily Finance Management',
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Logout Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, size: 22),
            label: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildJdtToggle() {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final profileAsync = ref.watch(userProfileStreamProvider(userId));
    final showJdt = profileAsync.valueOrNull?.showJdtMatches ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: AppTheme.jdtRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.sports_soccer_outlined, color: AppTheme.jdtRed, size: 20),
      ),
      title: const Text('JDT Matches', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      subtitle: const Text('Show on dashboard & navbar', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
      trailing: Switch.adaptive(
        value: showJdt,
        activeTrackColor: AppTheme.jdtRed.withValues(alpha: 0.5),
        activeThumbColor: AppTheme.jdtRed,
        onChanged: (value) async {
          try {
            final profileService = ref.read(profileServiceProvider);
            final currentProfile = await profileService.getUserProfile(userId);
            if (currentProfile != null) {
              final updated = currentProfile.copyWith(showJdtMatches: value);
              await profileService.updateUserProfile(updated);
            }
          } catch (e) {
            if (mounted) showSnackBar(context, 'Failed to update setting: $e', isError: true);
          }
        },
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 68, endIndent: 16, color: Colors.grey.shade100);
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Edit Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        ),

        TextField(
          controller: _nameController,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          decoration: AppTheme.styledInput(
            label: 'Full Name',
            prefixIcon: Icons.person_outline,
            hint: 'Enter your full name',
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          decoration: AppTheme.styledInput(
            label: 'Phone Number',
            prefixIcon: Icons.phone_outlined,
            hint: 'Enter your phone number',
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _updateProfile,
            icon: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 22),
            label: Text(_isLoading ? '' : 'Save Changes',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _toggleEditMode,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

}
