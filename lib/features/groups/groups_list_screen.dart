import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/screens/create_group_screen.dart';
import 'package:duitkita/features/groups/group_detail_screen.dart';

enum _Filter { all, active, pending, settled }

class GroupsListScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const GroupsListScreen({super.key, this.onBack});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final groupsAsync = ref.watch(userGroupsStreamProvider(userId));
    final adminGroupIds = ref.watch(adminGroupIdsStreamProvider(userId)).valueOrNull ?? {};
    final allGroups = groupsAsync.valueOrNull ?? [];

    // Pre-fetch payment statuses for all groups (drives filter + badge)
    final statusMap = <String, String>{};
    for (final g in allGroups) {
      statusMap[g.id] = ref.watch(
        groupMonthPaymentStatusProvider((groupId: g.id, userId: userId)),
      ).valueOrNull ?? 'unpaid';
    }

    // Sort: admin groups first, then by updatedAt
    final sorted = List.of(allGroups)
      ..sort((a, b) {
        final aAdmin = adminGroupIds.contains(a.id);
        final bAdmin = adminGroupIds.contains(b.id);
        if (aAdmin != bAdmin) return aAdmin ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    // Apply filter
    final groups = sorted.where((g) {
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.active:
          return g.monthlyAmount > 0;
        case _Filter.pending:
          return statusMap[g.id] == 'pending';
        case _Filter.settled:
          return statusMap[g.id] == 'confirmed';
      }
    }).toList();

    final totalMonthly = allGroups.fold<double>(0, (s, g) => s + g.monthlyAmount);

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Large header ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DS.xl, 8, DS.xl, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.onBack != null) ...[
                      GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(color: DT.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: DT.border)),
                          child: const Icon(Icons.arrow_back_rounded, size: 18, color: DT.text),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Groups',
                            style: GoogleFonts.manrope(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: DT.text,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (allGroups.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${allGroups.length} active · RM${totalMonthly.toStringAsFixed(0)}/mo',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: DT.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        AppTheme.slideRoute(const CreateGroupScreen()),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DT.border),
                        ),
                        child: const Icon(Icons.add_rounded, size: 20, color: DT.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Filter chips ────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(DS.xl, 8, DS.xl, 0),
                  children: _Filter.values.map((f) {
                    final active = f == _filter;
                    final label = switch (f) {
                      _Filter.all => 'All',
                      _Filter.active => 'Active',
                      _Filter.pending => 'Pending',
                      _Filter.settled => 'Settled',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? DT.text : DT.surface,
                            borderRadius: BorderRadius.circular(DS.chipRadius),
                            border: Border.all(color: active ? DT.text : DT.border),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : DT.text,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── List / empty state ──────────────────────────────
            if (groupsAsync.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
              )
            else if (groups.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  filterActive: _filter != _Filter.all,
                  onCreateGroup: () => Navigator.of(context).push(
                    AppTheme.slideRoute(const CreateGroupScreen()),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(DS.xl, 14, DS.xl, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GroupCard(
                        group: groups[i],
                        userId: userId,
                        isAdmin: adminGroupIds.contains(groups[i].id),
                        status: statusMap[groups[i].id] ?? 'unpaid',
                        colorIndex: i,
                        onTap: () => Navigator.of(context).push(
                          AppTheme.slideRoute(GroupDetailScreen(groupId: groups[i].id)),
                        ),
                      ),
                    ),
                    childCount: groups.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Group card ───────────────────────────────────────────────────────────────

class _GroupCard extends ConsumerWidget {
  final dynamic group;
  final String userId;
  final bool isAdmin;
  final String status;
  final int colorIndex;
  final VoidCallback onTap;

  static const _tileColors = [
    DT.catGroups,
    DT.catDebts,
    DT.catBills,
    Color(0xFF7C3AED), // violet
  ];

  static const _tileSoftColors = [
    DT.catGroupsSoft,
    DT.catDebtsSoft,
    DT.catBillsSoft,
    Color(0xFFEDE9FE),
  ];

  const _GroupCard({
    required this.group,
    required this.userId,
    required this.isAdmin,
    required this.status,
    required this.colorIndex,
    required this.onTap,
  });

  String _initials(String name) {
    final w = name.trim().split(RegExp(r'\s+'));
    if (w.length >= 2) return '${w[0][0]}${w[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMonthly = (group.monthlyAmount as double) > 0;
    final tileColor = _tileColors[colorIndex % _tileColors.length];
    final tileSoft = _tileSoftColors[colorIndex % _tileSoftColors.length];

    // Paid count for progress bar (monthly groups only)
    final paidCount = isMonthly
        ? ref.watch(groupMonthPaidCountProvider(group.id as String)).valueOrNull ?? 0
        : 0;
    final memberCount = group.memberCount as int;
    final paidPct = memberCount > 0 ? (paidCount / memberCount).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DS.cardRadius),
          border: Border.all(color: DT.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tile with initials
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tileSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _initials(group.name as String),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tileColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name as String,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: DT.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (isAdmin)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: DT.catGroupsSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Admin',
                            style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: DT.catGroups),
                          ),
                        ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: DT.textTertiary),
                    ],
                  ),

                  // Description
                  if ((group.description as String).isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      group.description as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(fontSize: 12, color: DT.textSecondary),
                    ),
                  ],

                  const SizedBox(height: 10),

                  if (isMonthly) ...[
                    // X/Y paid + amount/mo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$paidCount/$memberCount paid',
                              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: DT.textSecondary),
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(status: status),
                          ],
                        ),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'RM${(group.monthlyAmount as double).toStringAsFixed(0)}',
                                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.2),
                              ),
                              TextSpan(
                                text: '/mo',
                                style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: DT.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: paidPct,
                        minHeight: 4,
                        backgroundColor: DT.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(tileColor),
                      ),
                    ),
                  ] else ...[
                    // One-off group
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: DT.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'One-off split',
                            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.accentDeep),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$memberCount members',
                          style: GoogleFonts.manrope(fontSize: 11, color: DT.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status pill ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'confirmed' => (DT.successSoft, DT.success, 'Paid'),
      'pending'   => (DT.warningSoft, DT.warning, 'Pending'),
      'rejected'  => (DT.dangerSoft,  DT.danger,  'Rejected'),
      _           => (DT.surfaceAlt,  DT.textTertiary, 'Not paid'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool filterActive;
  final VoidCallback onCreateGroup;

  const _EmptyState({required this.filterActive, required this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: DT.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DT.border),
                ),
                child: const Icon(Icons.group_outlined, size: 38, color: DT.textTertiary),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: DT.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            filterActive ? 'No groups match' : 'No groups yet',
            style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4),
          ),
          const SizedBox(height: 8),
          Text(
            filterActive
                ? 'Try a different filter above.'
                : 'Start a group with family, housemates, or your travel squad. Split monthly bills, track who paid, and settle up without the awkwardness.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 14, color: DT.textSecondary, height: 1.5),
          ),
          if (!filterActive) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onCreateGroup,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: BoxDecoration(
                  color: DT.text,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Create your first group',
                      style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DT.surface,
                border: Border.all(color: DT.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW IT WORKS',
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: DT.textSecondary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  ...['Set a monthly amount', 'Add members by phone or email', 'Admin approves payments']
                      .asMap()
                      .entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(color: DT.accentSoft, borderRadius: BorderRadius.circular(6)),
                                child: Center(
                                  child: Text('${e.key + 1}', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: DT.accentDeep)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(e.value, style: GoogleFonts.manrope(fontSize: 13, color: DT.text, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
