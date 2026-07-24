import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/utils/utils.dart';

class ManageMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const ManageMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends ConsumerState<ManageMembersScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final uid = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (uid == null) return;
    final ok = await ref.read(groupServiceProvider).isUserAdmin(widget.groupId, uid);
    if (mounted) setState(() => _isAdmin = ok);
  }

  Future<void> _addMember() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !isValidEmail(email)) {
      _snack('Please enter a valid email', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final profileService = ref.read(profileServiceProvider);
      final userId = await profileService.getUserIdByEmail(email);
      if (userId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showInviteDialog(email);
        return;
      }
      final profile = await profileService.getUserProfile(userId);
      await ref.read(groupServiceProvider).addMemberToGroup(
        groupId: widget.groupId,
        userId: userId,
        userName: profile?.name ?? 'Unknown',
        userEmail: email,
      );
      if (mounted) {
        _snack('Member added successfully');
        _emailCtrl.clear();
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInviteDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(DS.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: DT.warningSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_off_outlined, color: DT.warning, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text('User Not Found', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: DT.text))),
            ]),
            const SizedBox(height: 12),
            Text.rich(TextSpan(
              style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.5),
              children: [
                const TextSpan(text: 'No account found for '),
                TextSpan(text: email, style: const TextStyle(fontWeight: FontWeight.w700, color: DT.text)),
                const TextSpan(text: '.\n\nWould you like to send them an invitation?'),
              ],
            )),
            const SizedBox(height: DS.xl),
            GestureDetector(
              onTap: () { Navigator.pop(ctx); _sendInvite(email); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: DT.accent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Send Invite', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.textSecondary))),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _sendInvite(String email) async {
    final msg = 'Hey! I\'m inviting you to join "${widget.groupName}" on DuitKita - '
        'our family app for tracking monthly payments and expenses.\n\n'
        'Download: https://appdistribution.firebase.dev/i/24015162eba1d1f9\n\n'
        'Sign up with $email and let me know so I can add you!';
    await SharePlus.instance.share(ShareParams(text: msg, subject: 'Join ${widget.groupName} on DuitKita'));
  }

  void _shareInvite() {
    final msg = 'Join "${widget.groupName}" on DuitKita! Track monthly payments with family.\n\n'
        'Download: https://appdistribution.firebase.dev/i/24015162eba1d1f9';
    SharePlus.instance.share(ShareParams(text: msg, subject: 'Join ${widget.groupName} on DuitKita'));
  }

  Future<void> _removeMember(String userId, String userName) async {
    final currentUid = ref.read(authControllerProvider.notifier).currentUser?.uid;
    if (userId == currentUid) { _snack('You cannot remove yourself', isError: true); return; }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: DT.surface,
        child: Padding(
          padding: const EdgeInsets.all(DS.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_remove_outlined, color: DT.danger, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text('Remove Member', style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: DT.text))),
            ]),
            const SizedBox(height: 12),
            Text('Remove $userName from this group?', style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary, height: 1.4)),
            const SizedBox(height: DS.xl),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: DT.danger, borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Remove', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: Center(child: Text('Cancel', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: DT.textSecondary))),
            ),
          ]),
        ),
      ),
    );

    if (ok != true) return;
    try {
      await ref.read(groupServiceProvider).removeMemberFromGroup(groupId: widget.groupId, userId: userId);
      if (mounted) _snack('Member removed');
    } catch (e) {
      if (mounted) _snack('Failed: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
      backgroundColor: isError ? DT.danger : DT.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final membersAsync = ref.watch(groupMembersStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.lg, 10, DS.lg, 0),
            child: Row(children: [
              _IconBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(child: Text('Members', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4))),
              if (_isAdmin)
                _IconBtn(icon: Icons.person_add_outlined, onTap: _shareInvite),
            ]),
          ),

          // ── Add member input (admin only) ────────────────────────
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, 0),
              child: Container(
                padding: const EdgeInsets.all(DS.md),
                decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Add member by email', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.text)),
                  const SizedBox(height: DS.sm),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.manrope(fontSize: 14, color: DT.text),
                        decoration: InputDecoration(
                          hintText: 'member@email.com',
                          hintStyle: GoogleFonts.manrope(fontSize: 14, color: DT.textTertiary),
                          prefixIcon: const Icon(Icons.email_outlined, size: 18, color: DT.textSecondary),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: DT.bg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: DT.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: DT.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: DT.accent, width: 1.5)),
                        ),
                        onSubmitted: (_) => _isLoading ? null : _addMember(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isLoading ? null : _addMember,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: DT.accent, borderRadius: BorderRadius.circular(12)),
                        child: _isLoading
                            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                            : const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),

          // ── Members list ─────────────────────────────────────────
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
              error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.textSecondary))),
              data: (members) {
                if (members.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(padding: const EdgeInsets.all(DS.xl), decoration: BoxDecoration(color: DT.primarySoft, shape: BoxShape.circle), child: const Icon(Icons.people_outline, size: 40, color: DT.textSecondary)),
                      const SizedBox(height: DS.lg),
                      Text('No members yet', style: GoogleFonts.manrope(fontSize: 15, color: DT.textSecondary)),
                    ]),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(DS.lg, DS.md, DS.lg, DS.xxxl),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final isMe = m.userId == currentUid;
                    return Container(
                      padding: const EdgeInsets.all(DS.md),
                      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(DS.cardRadius)),
                      child: Row(children: [
                        // Avatar
                        _MemberAvatar(userId: m.userId, name: m.userName, isAdmin: m.isAdmin),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text(m.userName, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text), overflow: TextOverflow.ellipsis)),
                              if (m.isAdmin) ...[
                                const SizedBox(width: 6),
                                _Chip(label: 'Admin', bg: DT.primarySoft, fg: DT.primary),
                              ],
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                _Chip(label: 'You', bg: DT.accentSoft, fg: DT.accentDeep),
                              ],
                            ]),
                            if (m.userEmail != null) ...[
                              const SizedBox(height: 2),
                              Text(m.userEmail!, style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary), overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 2),
                            Text('RM${m.totalPaid.toStringAsFixed(2)} · ${m.paymentCount} payments', style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                        if (_isAdmin && !isMe && !m.isAdmin)
                          GestureDetector(
                            onTap: () => _removeMember(m.userId, m.userName),
                            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: DT.dangerSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_remove_outlined, size: 18, color: DT.danger)),
                          ),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _MemberAvatar extends ConsumerWidget {
  final String userId;
  final String name;
  final bool isAdmin;
  const _MemberAvatar({required this.userId, required this.name, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrl = ref.watch(userProfileStreamProvider(userId)).valueOrNull?.profileImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 44, height: 44,
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initialsTile())
            : _initialsTile(),
      ),
    );
  }

  Widget _initialsTile() {
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      color: isAdmin ? DT.primarySoft : DT.accentSoft,
      child: Center(child: Text(
        initials.isNotEmpty ? initials : '?',
        style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: isAdmin ? DT.primary : DT.accentDeep),
      )),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: DT.surface, border: Border.all(color: DT.border), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 20, color: DT.text),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DS.chipRadius)),
    child: Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
  );
}
