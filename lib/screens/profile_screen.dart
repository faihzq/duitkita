// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/user_profile.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/widgets/custom_text_field.dart';
import 'package:duitkita/utils/utils.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  bool _hasLoadedInitialData = false;

  @override
  void initState() {
    super.initState();
    // Reset state when screen loads
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
        // Reset controllers when canceling edit
        final userId =
            ref.read(authControllerProvider.notifier).currentUser?.uid;
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

    setState(() {
      _isLoading = true;
    });

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
          setState(() {
            _isEditing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to update profile: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================
  // EMAIL MIGRATION METHOD - ADD THIS
  // ==========================================
  Future<void> _migrateEmail() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.email == null) {
      if (mounted) {
        showSnackBar(context, 'No email found to migrate', isError: true);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update Firestore with email from Firebase Auth
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'email': currentUser.email});

      if (mounted) {
        showSnackBar(context, 'Email added to profile successfully!');
        // Refresh the profile data to show updated email
        ref.invalidate(userProfileStreamProvider(currentUser.uid));
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to add email: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final userEmail =
        ref.watch(authControllerProvider.notifier).currentUser?.email;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(
          child: Text('You need to be logged in to view your profile'),
        ),
      );
    }

    final profileAsync = ref.watch(userProfileStreamProvider(userId));

    // Load initial data into controllers when profile data is available
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  userEmail ?? 'No email',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                _isEditing ? _buildEditForm() : _buildProfileInfo(profile),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading profile: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasLoadedInitialData = false;
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildProfileInfo(UserProfile? profile) {
    // Check if email is missing in profile
    final needsEmailMigration = profile?.email == null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Full Name', profile?.name ?? 'Not set'),
            const Divider(),
            _buildInfoRow('Email', profile?.email ?? 'Not set in profile'),
            const Divider(),
            _buildInfoRow('Phone Number', profile?.phoneNumber ?? 'Not set'),
            const Divider(),
            _buildInfoRow(
              'Member Since',
              profile?.createdAt != null
                  ? '${profile!.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}'
                  : 'Unknown',
            ),

            // ==========================================
            // MIGRATION BUTTON - SHOWS ONLY IF EMAIL IS MISSING
            // ==========================================
            if (needsEmailMigration) ...[
              const Divider(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Action Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Email is not in your profile. Click below to add it for member management features.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _migrateEmail,
                        icon: const Icon(Icons.sync),
                        label: const Text('Add Email to Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ==========================================
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        CustomTextField(controller: _nameController, labelText: 'Full Name'),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _phoneController,
          labelText: 'Phone Number',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
      ],
    );
  }
}
