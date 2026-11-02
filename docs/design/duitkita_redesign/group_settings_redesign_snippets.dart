// ============================================================================
// Group Settings redesign — drop-in Flutter widgets
// Paste into lib/features/groups/group_settings_screen.dart
// Uses your existing DT / DS tokens, GoogleFonts.manrope, and the
// _Card / _SectionLabel / _Divider / _SettingRow / _ToggleRow already in
// that file. These add the pieces the redesign introduces.
// ============================================================================
//
// INTEGRATION (inside the ListView in _GroupSettingsScreenState.build,
// replacing the current "Hero group card"):
//
//   _IdentityCard(
//     name: group.name,
//     description: group.description,
//     emoji: '🏠',                       // or group.emoji if you add one
//     colorSoft: DT.catGroupsSoft,
//     editable: isAdmin,
//     onTapEdit: () => _editGroup(group),
//   ),
//
//   const SizedBox(height: DS.xl),
//   _SectionLabel('Contribution'),
//   const SizedBox(height: DS.sm),
//   _Card(children: [
//     _ValueRow(label: 'Monthly amount', value: 'RM ${group.monthlyAmount.toStringAsFixed(0)}', onTap: () => _editGroup(group)),
//     _Divider(),
//     _ValueRow(label: 'Reminder day',  value: _ordinal(group.reminderDay), onTap: () => _setReminderDay(group)),
//     _Divider(),
//     const _ValueRow(label: 'Currency', value: '🇲🇾 MYR · RM', last: true),
//   ]),
//
//   const SizedBox(height: DS.xl),
//   _SectionLabel('Members'),
//   const SizedBox(height: DS.sm),
//   _MembersPreviewRow(
//     members: members,                   // List<GroupMember>
//     adminCount: members.where((m) => m.isAdmin).length,
//     onTap: () => Navigator.of(context).push(
//       AppTheme.slideRoute(ManageMembersScreen(groupId: widget.groupId, groupName: group.name)),
//     ),
//   ),
//
//   const SizedBox(height: DS.xl),
//   _SectionLabel('Data & sharing'),
//   const SizedBox(height: DS.sm),
//   _Card(children: [
//     _SettingRow(icon: Icons.download_outlined, iconBg: DT.infoSoft, iconColor: DT.info,
//       label: 'Export to CSV', subtitle: 'Payments + expenses for this group', onTap: _exportCsv),
//     _Divider(),
//     _SettingRow(icon: Icons.ios_share_rounded, iconBg: DT.primarySoft, iconColor: DT.primary,
//       label: 'Share invite link', subtitle: 'Anyone with the link can request to join', onTap: _shareInvite, last: true),
//   ]),
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/models/group_member.dart';

// ─── Centered identity hero ─────────────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  final String name;
  final String description;
  final String emoji;
  final Color colorSoft;
  final bool editable;
  final VoidCallback onTapEdit;

  const _IdentityCard({
    required this.name,
    required this.description,
    required this.emoji,
    required this.colorSoft,
    required this.editable,
    required this.onTapEdit,
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
        onTap: editable ? onTapEdit : null,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 86, height: 86,
            decoration: BoxDecoration(color: colorSoft, borderRadius: BorderRadius.circular(26)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 46))),
          ),
          if (editable)
            Positioned(
              right: -2, bottom: -2,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: DT.text, borderRadius: BorderRadius.circular(10), border: Border.all(color: DT.surface, width: 3)),
                child: const Icon(Icons.edit_outlined, size: 13, color: Colors.white),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      Text(name, textAlign: TextAlign.center,
        style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4)),
      if (description.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(description, textAlign: TextAlign.center,
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500, color: DT.textSecondary)),
      ],
    ]),
  );
}

// ─── Label + right-aligned value row (for the Contribution card) ────────────
class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;
  const _ValueRow({required this.label, required this.value, this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: DT.textSecondary)),
        const Spacer(),
        Text(value, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 18, color: DT.textTertiary),
        ],
      ]),
    ),
  );
}

// ─── Members preview row with avatar stack ──────────────────────────────────
class _MembersPreviewRow extends StatelessWidget {
  final List<GroupMember> members;
  final int adminCount;
  final VoidCallback onTap;
  const _MembersPreviewRow({required this.members, required this.adminCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = members.take(4).toList();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(DS.cardRadius), border: Border.all(color: DT.border)),
        child: Row(children: [
          // Overlapping avatar stack
          SizedBox(
            width: 32.0 + (preview.length - 1) * 24.0,
            height: 32,
            child: Stack(children: [
              for (int i = 0; i < preview.length; i++)
                Positioned(
                  left: i * 24.0,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: DT.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: DT.surface, width: 2)),
                    child: Center(child: Text(
                      _initials(preview[i].userName),
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: DT.text),
                    )),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Manage ${members.length} member${members.length == 1 ? '' : 's'}',
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: DT.text)),
            const SizedBox(height: 2),
            Text('$adminCount admin${adminCount == 1 ? '' : 's'} · ${members.length - adminCount} member${members.length - adminCount == 1 ? '' : 's'}',
              style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary)),
          ])),
          const Icon(Icons.chevron_right_rounded, size: 18, color: DT.textTertiary),
        ]),
      ),
    );
  }

  String _initials(String name) =>
    name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
}
