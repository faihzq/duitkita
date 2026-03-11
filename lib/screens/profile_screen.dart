import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/user_profile.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/storage_service.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/utils/utils.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Change Profile Picture',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadImage(ImageSource.camera);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary, size: 28),
                            ),
                            const SizedBox(height: 10),
                            const Text('Camera', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadImage(ImageSource.gallery);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.photo_library_outlined, color: AppTheme.primary, size: 28),
                            ),
                            const SizedBox(height: 10),
                            const Text('Gallery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          ],
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
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final userId = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppTheme.primary,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() => _isUploadingImage = true);

      final storageService = ref.read(storageServiceProvider);
      final imageUrl = await storageService.uploadProfileImage(
        userId: userId,
        file: File(croppedFile.path),
      );

      final profileService = ref.read(profileServiceProvider);
      final currentProfile = await profileService.getUserProfile(userId);

      if (currentProfile != null) {
        final updatedProfile = currentProfile.copyWith(profileImageUrl: imageUrl);
        await profileService.updateUserProfile(updatedProfile);
      }

      if (mounted) {
        showSnackBar(context, 'Profile picture updated');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to update profile picture: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
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

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final userEmail = ref.watch(authControllerProvider.notifier).currentUser?.email;

    if (userId == null) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceBg,
        appBar: AppBar(title: const Text('Profile'), backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
        body: const Center(child: Text('You need to be logged in to view your profile')),
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
                        // Top bar
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                              ),
                            ),
                            const Expanded(
                              child: Text('Profile', textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                            GestureDetector(
                              onTap: _toggleEditMode,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_isEditing ? Icons.close : Icons.edit_outlined, color: Colors.white, size: 22),
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
                                width: 90, height: 90,
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
                                          (profile?.name ?? userEmail ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      )
                                    : null,
                              ),
                              if (_isUploadingImage)
                                Container(
                                  width: 90, height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                  child: const Center(
                                    child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                                  ),
                                ),
                              if (!_isUploadingImage)
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 16, color: AppTheme.primary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile?.name ?? 'No name set',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail ?? 'No email',
                          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
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
                  else
                    _buildProfileInfo(profile),
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
      children: [
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

  Widget _buildDivider() {
    return Divider(height: 1, indent: 68, endIndent: 16, color: Colors.grey.shade100);
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
