// ============================================================================
// GROUP ICON — change emoji OR upload a photo
// Paste-ready patches for the real Flutter app. Four files change.
// No new dependencies: image_picker + firebase_storage already in pubspec.
// ============================================================================
//
// ─────────────────────────────────────────────────────────────────────────
// FILE 5 · storage.rules  (deploy with: firebase deploy --only storage)
// ─────────────────────────────────────────────────────────────────────────
//
// Add this match block INSIDE `match /b/{bucket}/o { ... }`, right after the
// profile_images block and BEFORE the "Block all other paths" catch-all.
// Read: any signed-in user. Write/delete: only an admin of that group
// (verified against the group's members subcollection in Firestore).
//
//     // Group icons: members read, only group admins upload/delete
//     match /group_icons/{groupId}/{fileName} {
//       allow read: if request.auth != null;
//
//       allow create, update: if request.auth != null
//                     && request.resource.size < 10 * 1024 * 1024
//                     && request.resource.contentType.matches('image/.*')
//                     && firestore.get(/databases/(default)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.isAdmin == true;
//
//       allow delete: if request.auth != null
//                     && firestore.get(/databases/(default)/documents/groups/$(groupId)/members/$(request.auth.uid)).data.isAdmin == true;
//     }
//
// Note: firestore.get() in Storage rules requires the default database and
// counts as one Firestore read per upload — negligible for this use.
//
// Firestore: two new fields on the group doc — `iconEmoji` (String) and
// `iconUrl` (String, Firebase Storage download URL). They are mutually
// exclusive: setting one clears the other. Existing groups with neither
// fall back to the 🏠 default. No migration needed.
//
// ─────────────────────────────────────────────────────────────────────────
// FILE 1 · lib/models/group_model.dart
// ─────────────────────────────────────────────────────────────────────────
//
// (a) Add two fields near the other final fields:
//
//        final String? iconEmoji; // chosen emoji, e.g. '🏠'
//        final String? iconUrl;   // uploaded photo (Storage URL)
//
// (b) Add to the constructor param list:
//
//        this.iconEmoji,
//        this.iconUrl,
//
// (c) Add inside GroupModel.fromMap(...):
//
//        iconEmoji: data['iconEmoji'],
//        iconUrl: data['iconUrl'],
//
// (d) Add inside toMap():
//
//        'iconEmoji': iconEmoji,
//        'iconUrl': iconUrl,
//
// (e) Add to copyWith signature + body (optional — writes go through the
//     service, but keep it consistent):
//
//        String? iconEmoji,
//        String? iconUrl,
//        ...
//        iconEmoji: iconEmoji ?? this.iconEmoji,
//        iconUrl: iconUrl ?? this.iconUrl,
//
//
// ─────────────────────────────────────────────────────────────────────────
// FILE 2 · lib/services/storage_service.dart
// ─────────────────────────────────────────────────────────────────────────
//
// Add this method inside class StorageService (mirrors uploadProfileImage):

  Future<String> uploadGroupImage({
    required String groupId,
    required File file,
  }) async {
    try {
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        throw Exception('File too large. Maximum size is 10MB.');
      }
      final extension = file.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw Exception('Invalid file type. Allowed: jpg, jpeg, png');
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'icon_$timestamp.$extension';
      final path = 'group_icons/$groupId/$filename';

      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: 'image/$extension');
      final uploadTask = await ref.putFile(file, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload group image: $e');
    }
  }

  // Best-effort delete of a previously uploaded group icon. Safe to ignore errors.
  Future<void> deleteGroupImage(String iconUrl) async {
    try {
      await _storage.refFromURL(iconUrl).delete();
    } catch (_) {/* file may already be gone */}
  }

//
// ─────────────────────────────────────────────────────────────────────────
// FILE 3 · lib/services/group_service.dart
// ─────────────────────────────────────────────────────────────────────────
//
// Add this method inside class GroupService. It writes emoji + photo
// together so they stay mutually exclusive — FieldValue.delete() removes
// whichever one isn't being set.

  // Set the group icon. Pass emoji OR iconUrl (not both). Passing neither
  // clears both (reset to default).
  Future<void> setGroupIcon({
    required String groupId,
    String? emoji,
    String? iconUrl,
  }) async {
    try {
      await _groups.doc(groupId).update({
        'updatedAt': DateTime.now(),
        'iconEmoji': emoji ?? FieldValue.delete(),
        'iconUrl': iconUrl ?? FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Failed to update group icon: $e');
    }
  }

//
// ─────────────────────────────────────────────────────────────────────────
// FILE 4 · lib/features/groups/group_settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────
//
// 4a. ADD IMPORTS at the top (dart:io + File is already imported):
//
//        import 'package:image_picker/image_picker.dart';
//        import 'package:duitkita/services/storage_service.dart';
//
// 4b. REPLACE the identity-hero call site in build() with this (adds the
//     icon fields + a dedicated onTapIcon handler; keeps the name tap → edit):
//
//        _IdentityCard(
//          name: group.name,
//          description: group.description,
//          emoji: group.iconEmoji ?? '🏠',
//          iconUrl: group.iconUrl,
//          colorSoft: DT.catGroupsSoft,
//          editable: isAdmin,
//          onTapIcon: () => _pickGroupIcon(group),
//          onTapName: () => _editGroup(group),
//        ),
//
// 4c. ADD this method inside _GroupSettingsScreenState (near _editGroup):

  Future<void> _pickGroupIcon(GroupModel group) async {
    final action = await showModalBottomSheet<_IconResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GroupIconSheet(
        currentEmoji: group.iconEmoji ?? '🏠',
        hasPhoto: group.iconUrl != null,
      ),
    );
    if (action == null || !mounted) return;

    // Pick an emoji ---------------------------------------------------------
    if (action.emoji != null) {
      setState(() => _busy = true);
      try {
        final old = group.iconUrl;
        await ref.read(groupServiceProvider).setGroupIcon(groupId: widget.groupId, emoji: action.emoji);
        if (old != null) ref.read(storageServiceProvider).deleteGroupImage(old);
        if (mounted) _snack('Group icon updated');
      } catch (e) {
        if (mounted) _snack('Error: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // Remove the photo / reset to default ----------------------------------
    if (action.remove) {
      setState(() => _busy = true);
      try {
        final old = group.iconUrl;
        await ref.read(groupServiceProvider).setGroupIcon(groupId: widget.groupId, emoji: '🏠');
        if (old != null) ref.read(storageServiceProvider).deleteGroupImage(old);
        if (mounted) _snack('Photo removed');
      } catch (e) {
        if (mounted) _snack('Error: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // Upload a photo --------------------------------------------------------
    if (action.pickPhoto) {
      try {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (picked == null || !mounted) return;
        setState(() => _busy = true);
        final old = group.iconUrl;
        final url = await ref.read(storageServiceProvider).uploadGroupImage(
          groupId: widget.groupId,
          file: File(picked.path),
        );
        await ref.read(groupServiceProvider).setGroupIcon(groupId: widget.groupId, iconUrl: url);
        if (old != null) ref.read(storageServiceProvider).deleteGroupImage(old);
        if (mounted) _snack('Group photo updated');
      } catch (e) {
        if (mounted) _snack('Error: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

//
// 4d. REPLACE the existing _IdentityCard class with this version (renders a
//     photo when set, otherwise the emoji; separate tap targets for icon vs name):

class _IdentityCard extends StatelessWidget {
  final String name;
  final String description;
  final String emoji;
  final String? iconUrl;
  final Color colorSoft;
  final bool editable;
  final VoidCallback onTapIcon;
  final VoidCallback onTapName;

  const _IdentityCard({
    required this.name,
    required this.description,
    required this.emoji,
    required this.iconUrl,
    required this.colorSoft,
    required this.editable,
    required this.onTapIcon,
    required this.onTapName,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    decoration: BoxDecoration(
      color: DT.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: DT.border),
    ),
    child: Column(children: [
      GestureDetector(
        onTap: editable ? onTapIcon : null,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 86, height: 86,
            decoration: BoxDecoration(color: colorSoft, borderRadius: BorderRadius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: (iconUrl != null && iconUrl!.isNotEmpty)
                ? Image.network(iconUrl!, width: 86, height: 86, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Text(emoji, style: const TextStyle(fontSize: 46))))
                : Center(child: Text(emoji, style: const TextStyle(fontSize: 46))),
          ),
          if (editable)
            Positioned(
              right: -2, bottom: -2,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(10), border: Border.all(color: DT.surface, width: 3)),
                child: Icon(iconUrl != null ? Icons.photo_camera_outlined : Icons.edit_outlined, size: 13, color: Colors.white),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: editable ? onTapName : null,
        child: Text(name, textAlign: TextAlign.center,
          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4)),
      ),
      if (description.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(description, textAlign: TextAlign.center,
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500, color: DT.textSecondary)),
      ],
    ]),
  );
}

//
// 4e. ADD these two classes anywhere in the file (bottom is fine):

// Result object the icon sheet pops with.
class _IconResult {
  final String? emoji;
  final bool pickPhoto;
  final bool remove;
  const _IconResult({this.emoji, this.pickPhoto = false, this.remove = false});
}

const _kGroupEmojis = [
  '🏠', '👨‍👩‍👧‍👦', '💰', '🎓', '🕌', '✈️', '🚗', '🏥',
  '🎁', '🍽️', '⚽', '🏢', '🌴', '🐱', '🎉', '📚',
];

class _GroupIconSheet extends StatelessWidget {
  final String currentEmoji;
  final bool hasPhoto;
  const _GroupIconSheet({required this.currentEmoji, required this.hasPhoto});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: DT.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewInsetsOf(context).bottom + 20),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: DT.borderStrong, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Group icon', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: DT.text)),
          const SizedBox(height: 2),
          Text('Pick an emoji or upload a photo', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary)),
        ]),
      ),
      const SizedBox(height: 16),

      // Upload / change photo
      GestureDetector(
        onTap: () => Navigator.pop(context, const _IconResult(pickPhoto: true)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: DT.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: DT.border)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: DT.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.photo_camera_outlined, size: 20, color: DT.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hasPhoto ? 'Change photo' : 'Upload a photo', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
              Text('Square images look best', style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary)),
            ])),
            const Icon(Icons.chevron_right_rounded, size: 18, color: DT.textTertiary),
          ]),
        ),
      ),
      if (hasPhoto)
        GestureDetector(
          onTap: () => Navigator.pop(context, const _IconResult(remove: true)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
            child: Text('Remove photo', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.danger)),
          ),
        ),

      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text('EMOJI', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.textTertiary, letterSpacing: 0.5)),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1),
        itemCount: _kGroupEmojis.length,
        itemBuilder: (_, i) {
          final e = _kGroupEmojis[i];
          final active = !hasPhoto && e == currentEmoji;
          return GestureDetector(
            onTap: () => Navigator.pop(context, _IconResult(emoji: e)),
            child: Container(
              decoration: BoxDecoration(
                color: active ? DT.catGroupsSoft : DT.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? DT.accent : Colors.transparent, width: 2),
              ),
              child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
            ),
          );
        },
      ),
    ]),
  );
}
