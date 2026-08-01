import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/services/profile_service.dart';
import 'package:duitkita/services/group_service.dart';
import 'package:duitkita/services/payment_service.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/services/expense_service.dart';
import 'package:duitkita/features/groups/group_detail_screen.dart';
import 'package:duitkita/features/expenses/expense_list_screen.dart';
import 'package:duitkita/features/payments/pending_payments_review_screen.dart';
import 'package:duitkita/features/profile/profile_screen.dart';
import 'package:duitkita/features/onboarding/onboarding_screen.dart';
import 'package:duitkita/features/trips/trips_list_screen.dart';
import 'package:duitkita/widgets/group_icon_avatar.dart';
import 'package:duitkita/widgets/help_sheet.dart';

class HomeScreen extends ConsumerWidget {
  final void Function(int)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.notifier).currentUser;
    if (user == null) return const SizedBox.shrink();

    final profile = ref.watch(userProfileStreamProvider(user.uid)).valueOrNull;
    final groups =
        ref.watch(userGroupsStreamProvider(user.uid)).valueOrNull ?? [];
    final debts =
        ref.watch(userDebtsStreamProvider(user.uid)).valueOrNull ?? [];

    final fullName =
        profile?.name ??
        user.displayName ??
        user.email?.split('@').first ??
        'there';
    final firstName = fullName.split(' ').first;
    final profileImageUrl = profile?.profileImageUrl;

    // Monthly totals
    final groupMonthly = groups.fold<double>(0, (s, g) => s + g.monthlyAmount);
    final debtMonthly = debts
        .where((d) => d.isDebt)
        .fold<double>(0, (s, d) => s + d.monthlyPayment);
    final billMonthly = debts
        .where((d) => d.isBill)
        .fold<double>(0, (s, d) => s + d.monthlyPayment);
    final totalMonthly = groupMonthly + debtMonthly + billMonthly;

    // Paid this month (confirmed groups + paid debts/bills)
    double paidThisMonth = 0;
    for (final g in groups) {
      final status =
          ref
              .watch(
                groupMonthPaymentStatusProvider((
                  groupId: g.id,
                  userId: user.uid,
                )),
              )
              .valueOrNull;
      if (status == 'confirmed') paidThisMonth += g.monthlyAmount;
    }
    for (final d in debts) {
      final paid = ref.watch(debtMonthPaidProvider(d.id)).valueOrNull ?? false;
      if (paid) paidThisMonth += d.monthlyPayment;
    }

    final remaining = totalMonthly - paidThisMonth;
    final progressPct =
        totalMonthly > 0 ? (paidThisMonth / totalMonthly).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Greeting header ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DS.xl, 12, DS.xl, 4),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              ),
                          child: _Avatar(
                            name: fullName,
                            imageUrl: profileImageUrl,
                            size: 42,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: DT.textSecondary,
                                ),
                              ),
                              Text(
                                firstName,
                                style: GoogleFonts.manrope(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: DT.text,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _HelpButton(
                          onTap: () => _showHelp(context, ref, user.uid),
                        ),
                        const SizedBox(width: 12),
                        _NotificationBell(userId: user.uid),
                      ],
                    ),
                  ),

                  // ── Hero balance card ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DS.xl, 14, DS.xl, 0),
                    child: _HeroCard(
                      totalMonthly: totalMonthly,
                      paidThisMonth: paidThisMonth,
                      remaining: remaining,
                      progressPct: progressPct,
                    ),
                  ),

                  // ── First-time tooltip ───────────────────────────
                  if (totalMonthly > 0)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(DS.xl, 10, DS.xl, 0),
                      child: _HomeHeroTip(),
                    ),

                  // ── Quick actions ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DS.xl, 20, DS.xl, 0),
                    child: _QuickActions(
                      context: context,
                      userId: user.uid,
                      onTabChange: onTabChange,
                    ),
                  ),

                  // ── Up next ──────────────────────────────────────
                  if (groups.isNotEmpty || debts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DS.xl,
                        DS.xxl,
                        DS.xl,
                        0,
                      ),
                      child: _UpNextSection(
                        userId: user.uid,
                        groups: groups,
                        debts: debts,
                        context: context,
                        onTabChange: onTabChange,
                      ),
                    ),

                  // ── Breakdown ────────────────────────────────────
                  if (totalMonthly > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DS.xl,
                        DS.xxl,
                        DS.xl,
                        0,
                      ),
                      child: _BreakdownCard(
                        context: context,
                        groups: groups,
                        debts: debts,
                        groupMonthly: groupMonthly,
                        debtMonthly: debtMonthly,
                        billMonthly: billMonthly,
                        onTabChange: onTabChange,
                      ),
                    ),

                  // ── Admin pending review ─────────────────────────
                  _AdminPendingSection(userId: user.uid, context: context),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Selamat pagi,';
    if (h >= 12 && h < 18) return 'Selamat petang,';
    return 'Selamat malam,';
  }

  static void _showHelp(BuildContext context, WidgetRef ref, String userId) {
    showHelpSheet(
      context,
      onShowIntro:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder:
                  (_) => OnboardingScreen(
                    onDone: () => Navigator.of(context).pop(),
                  ),
            ),
          ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const _Avatar({required this.name, this.imageUrl, required this.size});

  static const _palette = [
    [Color(0xFF5B6FFF), Color(0xFFECEFFF)],
    [Color(0xFF00C2A8), Color(0xFFE0F7F2)],
    [Color(0xFFF59E0B), Color(0xFFFEF3DC)],
    [Color(0xFFEF4444), Color(0xFFFDECEC)],
    [Color(0xFF3B82F6), Color(0xFFE8F0FE)],
    [Color(0xFF8B5CF6), Color(0xFFF1EBFE)],
    [Color(0xFF10B981), Color(0xFFE5F7EF)],
    [Color(0xFFEC4899), Color(0xFFFCE7F3)],
  ];

  @override
  Widget build(BuildContext context) {
    final initials =
        (name.trim().isEmpty ? '?' : name.trim())
            .split(RegExp(r'\s+'))
            .take(2)
            .map((s) => s.isNotEmpty ? s[0] : '')
            .join()
            .toUpperCase();

    int h = 0;
    for (final ch in name.codeUnits) {
      h = (h * 31 + ch) & 0xFFFFFFFF;
    }
    final pair = _palette[h % _palette.length];
    final fg = pair[0];
    final bg = pair[1];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        image:
            imageUrl != null
                ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child:
          imageUrl == null
              ? Center(
                child: Text(
                  initials,
                  style: GoogleFonts.manrope(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.3,
                  ),
                ),
              )
              : null,
    );
  }
}

// ─── Help button ──────────────────────────────────────────────────────────────

class _HelpButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HelpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DT.border),
        ),
        child: const Icon(Icons.help_outline_rounded, size: 20, color: DT.text),
      ),
    );
  }
}

// ─── Notification bell ────────────────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  final String userId;
  const _NotificationBell({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberNotifs =
        ref
            .watch(userPaymentNotificationsProvider(userId))
            .valueOrNull
            ?.length ??
        0;
    final adminGroupIds =
        (ref.watch(adminGroupIdsStreamProvider(userId)).valueOrNull ?? {})
            .toList();
    final paymentService = ref.watch(paymentServiceProvider);

    return StreamBuilder<List<dynamic>>(
      stream:
          adminGroupIds.isNotEmpty
              ? paymentService.getPendingPaymentsForGroupsStream(adminGroupIds)
              : Stream.value([]),
      builder: (context, snapshot) {
        final adminCount = snapshot.data?.length ?? 0;
        final total = memberNotifs + adminCount;
        return GestureDetector(
          onTap: () => _showNotifications(context, ref, userId),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DT.border),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: DT.text,
                  ),
                ),
                if (total > 0)
                  Positioned(
                    top: 8,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: DT.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: DT.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotifications(BuildContext context, WidgetRef ref, String userId) {
    final groups = ref.read(userGroupsStreamProvider(userId)).valueOrNull ?? [];
    final groupNameMap = {for (var g in groups) g.id: g.name};
    final adminGroupIds =
        (ref.read(adminGroupIdsStreamProvider(userId)).valueOrNull ?? {})
            .toList();
    final memberNotifs =
        ref.read(userPaymentNotificationsProvider(userId)).valueOrNull ?? [];
    final paymentService = ref.read(paymentServiceProvider);
    final expenseService = ref.read(expenseServiceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder:
                (ctx, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: DT.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            color: DT.borderStrong,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Notifications',
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: DT.text,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: DT.border),
                      if (adminGroupIds.isNotEmpty) ...[
                        StreamBuilder<List<dynamic>>(
                          stream: paymentService
                              .getPendingPaymentsForGroupsStream(adminGroupIds),
                          builder: (context, snapshot) {
                            final pending = snapshot.data ?? [];
                            if (pending.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _notifHeader(
                                  'Pending Payments',
                                  pending.length,
                                  DT.warning,
                                ),
                                ...pending.map(
                                  (p) => _notifTile(
                                    context: context,
                                    icon: Icons.hourglass_top_rounded,
                                    color: DT.warning,
                                    title:
                                        '${p.userName} — RM${p.amount.toStringAsFixed(2)}',
                                    subtitle:
                                        groupNameMap[p.groupId] ??
                                        'Unknown group',
                                    time: p.createdAt,
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.of(context).push(
                                        AppTheme.slideRoute(
                                          PendingPaymentsReviewScreen(
                                            groupId: p.groupId,
                                            groupName:
                                                groupNameMap[p.groupId] ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        StreamBuilder<List<dynamic>>(
                          stream: expenseService
                              .getPendingExpensesForGroupsStream(adminGroupIds),
                          builder: (context, snapshot) {
                            final pending = snapshot.data ?? [];
                            if (pending.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _notifHeader(
                                  'Pending Expenses',
                                  pending.length,
                                  DT.danger,
                                ),
                                ...pending.map(
                                  (e) => _notifTile(
                                    context: context,
                                    icon: Icons.receipt_long_outlined,
                                    color: DT.danger,
                                    title:
                                        '${e.title} — RM${e.amount.toStringAsFixed(2)}',
                                    subtitle:
                                        '${e.requestedByName} · ${groupNameMap[e.groupId] ?? ''}',
                                    time: e.createdAt,
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.of(context).push(
                                        AppTheme.slideRoute(
                                          ExpenseListScreen(
                                            groupId: e.groupId,
                                            groupName:
                                                groupNameMap[e.groupId] ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      if (memberNotifs.isNotEmpty) ...[
                        _notifHeader(
                          'Payment Updates',
                          memberNotifs.length,
                          DT.catGroups,
                        ),
                        ...memberNotifs.map((p) {
                          const months = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec',
                          ];
                          final isConfirmed = p.paymentStatus == 'confirmed';
                          return _notifTile(
                            context: context,
                            icon:
                                isConfirmed ? Icons.check_circle : Icons.cancel,
                            color: isConfirmed ? DT.success : DT.danger,
                            title:
                                '${months[p.month - 1]} ${p.year} — ${isConfirmed ? 'Confirmed' : 'Rejected'}',
                            subtitle:
                                groupNameMap[p.groupId] ?? 'Unknown group',
                            time: p.verifiedAt ?? p.createdAt,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                AppTheme.slideRoute(
                                  GroupDetailScreen(groupId: p.groupId),
                                ),
                              );
                            },
                          );
                        }),
                      ],
                      if (memberNotifs.isEmpty && adminGroupIds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.notifications_none,
                                  size: 48,
                                  color: DT.textTertiary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No notifications',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    color: DT.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
          ),
    );
  }

  static Widget _notifHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DT.text,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _notifTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required DateTime time,
    required VoidCallback onTap,
  }) {
    final diff = DateTime.now().difference(time);
    final label =
        diff.inMinutes < 60
            ? '${diff.inMinutes}m ago'
            : diff.inHours < 24
            ? '${diff.inHours}h ago'
            : '${diff.inDays}d ago';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DT.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: DT.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              label,
              style: GoogleFonts.manrope(fontSize: 11, color: DT.textTertiary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: DT.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final double totalMonthly;
  final double paidThisMonth;
  final double remaining;
  final double progressPct;

  const _HeroCard({
    required this.totalMonthly,
    required this.paidThisMonth,
    required this.remaining,
    required this.progressPct,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progressPct * 100).round();
    final onTrack = progressPct >= 0.4;
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DT.headerGradientStart, DT.headerGradientEnd],
        ),
        borderRadius: BorderRadius.circular(DS.heroRadius),
      ),
      child: Stack(
        children: [
          // Decorative radial glow
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    DT.accent.withValues(alpha: 0.19),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label + status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTHLY COMMITMENTS · ${months[now.month - 1].toUpperCase()}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          totalMonthly > 0 ? 'RM ${_fmt(totalMonthly)}' : '—',
                          style: GoogleFonts.manrope(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1.2,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalMonthly > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            onTrack
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            size: 12,
                            color: onTrack ? DT.accent : DT.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            onTrack ? 'On track' : 'Catch up',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: onTrack ? DT.accent : DT.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (totalMonthly > 0) ...[
                const SizedBox(height: 18),
                // Paid / Remaining labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paid RM ${_fmt(paidThisMonth, decimals: 0)}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      'RM ${_fmt(remaining, decimals: 0)} left',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(DT.accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$pct% of monthly commitments cleared',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v, {int decimals = 2}) {
    final s = v.toStringAsFixed(decimals);
    final parts = s.split('.');
    final intPart = parts[0];
    final result = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) result.write(',');
      result.write(intPart[i]);
    }
    if (parts.length > 1) result.write('.${parts[1]}');
    return result.toString();
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final BuildContext context;
  final String userId;
  final void Function(int)? onTabChange;
  const _QuickActions({
    required this.context,
    required this.userId,
    this.onTabChange,
  });

  @override
  Widget build(BuildContext _) {
    final actions = [
      _Action(
        Icons.add_rounded,
        'Add expense',
        DT.accentSoft,
        DT.accentDeep,
        () {
          onTabChange?.call(1);
        },
      ),
      _Action(Icons.map_rounded, 'Trips', DT.catDebtsSoft, DT.catDebts, () {
        Navigator.of(
          context,
        ).push(AppTheme.slideRoute(const TripsListScreen()));
      }),
      _Action(
        Icons.group_add_rounded,
        'New group',
        DT.catGroupsSoft,
        DT.catGroups,
        () {
          onTabChange?.call(1);
        },
      ),
      _Action(
        Icons.pie_chart_outline_rounded,
        'Insights',
        DT.catBillsSoft,
        DT.catBills,
        () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _InsightsSheet(userId: userId),
          );
        },
      ),
    ];

    return Row(
      children:
          actions
              .map(
                (a) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 0),
                    child: _ActionTile(action: a),
                  ),
                ),
              )
              .toList()
            ..insertBetween(const SizedBox(width: 10)),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.bg, this.fg, this.onTap);
}

class _ActionTile extends StatelessWidget {
  final _Action action;
  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: action.bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(action.icon, size: 18, color: action.fg),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DT.text,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _ListInsertBetween<T extends Widget> on List<T> {
  List<Widget> insertBetween(Widget separator) {
    if (length <= 1) return this;
    final result = <Widget>[];
    for (int i = 0; i < length; i++) {
      result.add(this[i]);
      if (i < length - 1) result.add(separator);
    }
    return result;
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DT.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ─── Up Next section ──────────────────────────────────────────────────────────

class _UpNextSection extends ConsumerWidget {
  final String userId;
  final List<dynamic> groups;
  final List<dynamic> debts;
  final BuildContext context;
  final void Function(int)? onTabChange;

  const _UpNextSection({
    required this.userId,
    required this.groups,
    required this.debts,
    required this.context,
    this.onTabChange,
  });

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    // Collect up-next items: unpaid groups + unpaid debts/bills
    final items = <_UpNextItemData>[];

    // Settled groups have hit their goal and closed, so there is nothing left
    // to pay. Filtering here rather than inside the loop matters: taking the
    // first three groups first would let three settled ones crowd out a fourth
    // that still needs paying.
    final owing = groups.where((g) => g.isSettled != true);

    for (final g in owing) {
      final status =
          ref
              .watch(
                groupMonthPaymentStatusProvider((
                  groupId: g.id,
                  userId: userId,
                )),
              )
              .valueOrNull;
      if (status != 'confirmed') {
        items.add(
          _UpNextItemData(
            icon: Icons.group_outlined,
            iconBg: DT.catGroupsSoft,
            iconColor: DT.catGroups,
            iconEmoji: g.iconEmoji,
            iconUrl: g.iconUrl,
            title: g.name,
            subtitle: 'Group · monthly contribution',
            amount: g.monthlyAmount,
            ctaLabel: 'Pay',
            muted: false,
            onTap:
                () => Navigator.of(
                  context,
                ).push(AppTheme.slideRoute(GroupDetailScreen(groupId: g.id))),
          ),
        );
      }
      if (items.length >= 3) break;
    }

    for (final d in debts.where((d) => d.isDebt).take(2)) {
      if (items.length >= 3) break;
      final paid = ref.watch(debtMonthPaidProvider(d.id)).valueOrNull ?? false;
      if (!paid) {
        items.add(
          _UpNextItemData(
            icon: Icons.account_balance_outlined,
            iconBg: DT.catDebtsSoft,
            iconColor: DT.catDebts,
            title: d.title,
            subtitle: 'Loan payment',
            amount: d.monthlyPayment,
            ctaLabel: 'Pay',
            muted: false,
            onTap: () => onTabChange?.call(2),
          ),
        );
      }
    }

    for (final b in debts.where((d) => d.isBill).take(2)) {
      if (items.length >= 3) break;
      final paid = ref.watch(debtMonthPaidProvider(b.id)).valueOrNull ?? false;
      if (!paid) {
        items.add(
          _UpNextItemData(
            icon: Icons.receipt_outlined,
            iconBg: DT.catBillsSoft,
            iconColor: DT.catBills,
            title: b.title,
            subtitle: 'Bill · due this month',
            amount: b.monthlyPayment,
            ctaLabel: 'Pay',
            muted: false,
            onTap: () => onTabChange?.call(2),
          ),
        );
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Up next'),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _UpNextCard(item: item),
          ),
        ),
      ],
    );
  }
}

class _UpNextItemData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final double amount;
  final String ctaLabel;
  final bool muted;
  final VoidCallback onTap;

  /// Group icon, when this row is a group. Falls back to [icon] otherwise.
  final String? iconEmoji;
  final String? iconUrl;

  const _UpNextItemData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.ctaLabel,
    required this.muted,
    required this.onTap,
    this.iconEmoji,
    this.iconUrl,
  });
}

class _UpNextCard extends StatelessWidget {
  final _UpNextItemData item;
  const _UpNextCard({required this.item});

  @override
  Widget build(BuildContext context) {
    // The whole row is the target, not just the pill — the pill is a 60×22
    // hit area, and the obvious thing to tap is the item itself.
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(DS.cardPad),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DS.cardRadius),
          border: Border.all(color: DT.border),
        ),
        child: Row(
          children: [
            GroupIconAvatar(
              iconEmoji: item.iconEmoji,
              iconUrl: item.iconUrl,
              size: 40,
              radius: 12,
              background: item.iconBg,
              fallback: Icon(item.icon, size: 20, color: item.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: DT.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM ${item.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: DT.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                // No detector of its own — the card already handles the tap, so
                // this stays a label rather than a competing hit target.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.muted ? DT.surfaceAlt : DT.text,
                    borderRadius: BorderRadius.circular(8),
                    border: item.muted ? Border.all(color: DT.border) : null,
                  ),
                  child: Text(
                    item.ctaLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.muted ? DT.text : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Breakdown card ───────────────────────────────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  final BuildContext context;
  final List<dynamic> groups;
  final List<dynamic> debts;
  final double groupMonthly;
  final double debtMonthly;
  final double billMonthly;
  final void Function(int)? onTabChange;

  const _BreakdownCard({
    required this.context,
    required this.groups,
    required this.debts,
    required this.groupMonthly,
    required this.debtMonthly,
    required this.billMonthly,
    this.onTabChange,
  });

  @override
  Widget build(BuildContext _) {
    final activeGroups = groups.length;
    final activeDebts = debts.where((d) => d.isDebt).length;
    final activeBills = debts.where((d) => d.isBill).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Where your money goes'),
        Container(
          padding: const EdgeInsets.all(DS.cardPad),
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(DS.cardRadius),
            border: Border.all(color: DT.border),
          ),
          child: Column(
            children: [
              if (activeGroups > 0) ...[
                _BreakdownRow(
                  icon: Icons.group_outlined,
                  iconBg: DT.catGroupsSoft,
                  iconColor: DT.catGroups,
                  label: 'Groups',
                  sub: '$activeGroups active',
                  amount: groupMonthly,
                  onTap: () => onTabChange?.call(1),
                ),
                if (activeDebts > 0 || activeBills > 0)
                  const _BreakdownDivider(),
              ],
              if (activeDebts > 0) ...[
                _BreakdownRow(
                  icon: Icons.account_balance_outlined,
                  iconBg: DT.catDebtsSoft,
                  iconColor: DT.catDebts,
                  label: 'Loans',
                  sub: '$activeDebts active',
                  amount: debtMonthly,
                  onTap: () => onTabChange?.call(2),
                ),
                if (activeBills > 0) const _BreakdownDivider(),
              ],
              if (activeBills > 0)
                _BreakdownRow(
                  icon: Icons.receipt_outlined,
                  iconBg: DT.catBillsSoft,
                  iconColor: DT.catBills,
                  label: 'Bills',
                  sub: '$activeBills subscriptions',
                  amount: billMonthly,
                  onTap: () => onTabChange?.call(2),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String sub;
  final double amount;
  final VoidCallback onTap;

  const _BreakdownRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: DT.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'RM ${_fmtComma(amount)}',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: DT.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: DT.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtComma(double v) {
    final intPart = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return buf.toString();
  }
}

class _BreakdownDivider extends StatelessWidget {
  const _BreakdownDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: DT.border,
    );
  }
}

// ─── First-time tooltip ───────────────────────────────────────────────────────

class _HomeHeroTip extends StatefulWidget {
  const _HomeHeroTip();

  @override
  State<_HomeHeroTip> createState() => _HomeHeroTipState();
}

class _HomeHeroTipState extends State<_HomeHeroTip> {
  static const _prefKey = 'tip_home_hero_dismissed';
  bool _loaded = false;
  bool _dismissed = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = prefs.getBool(_prefKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CustomPaint(
                size: const Size(12, 8),
                painter: _TipArrowPainter(),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DT.text,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'This card shows everything you owe this month — groups, loans, and bills combined.',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DT.surface,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Text(
                      'Got it',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DT.surface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = DT.text;
    final path =
        Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(0, size.height)
          ..lineTo(size.width, size.height)
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Admin pending section ────────────────────────────────────────────────────

class _AdminPendingSection extends ConsumerWidget {
  final String userId;
  final BuildContext context;

  const _AdminPendingSection({required this.userId, required this.context});

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsStreamProvider(userId));
    final adminGroupIds =
        (ref.watch(adminGroupIdsStreamProvider(userId)).valueOrNull ?? {})
            .toList();
    if (adminGroupIds.isEmpty) return const SizedBox.shrink();

    final groups = groupsAsync.valueOrNull ?? [];
    final groupNameMap = {for (var g in groups) g.id: g.name};
    final paymentService = ref.watch(paymentServiceProvider);
    final expenseService = ref.watch(expenseServiceProvider);

    return Column(
      children: [
        // Pending payments
        StreamBuilder<List<dynamic>>(
          stream: paymentService.getPendingPaymentsForGroupsStream(
            adminGroupIds,
          ),
          builder: (_, snapshot) {
            final payments = snapshot.data ?? [];
            if (payments.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(DS.xl, DS.xxl, DS.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'Pending Payments',
                    action: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: DT.warningSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${payments.length}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: DT.warning,
                        ),
                      ),
                    ),
                  ),
                  ...payments
                      .take(5)
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AdminTile(
                            icon: Icons.hourglass_top_rounded,
                            iconColor: DT.warning,
                            iconBg: DT.warningSoft,
                            title: p.userName,
                            subtitle:
                                '${groupNameMap[p.groupId] ?? 'Group'} · ${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}',
                            amount: p.amount,
                            onTap:
                                () => Navigator.of(context).push(
                                  AppTheme.slideRoute(
                                    PendingPaymentsReviewScreen(
                                      groupId: p.groupId,
                                      groupName: groupNameMap[p.groupId] ?? '',
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
        // Pending expenses
        StreamBuilder<List<dynamic>>(
          stream: expenseService.getPendingExpensesForGroupsStream(
            adminGroupIds,
          ),
          builder: (_, snapshot) {
            final expenses = snapshot.data ?? [];
            if (expenses.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(DS.xl, DS.xxl, DS.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'Pending Expenses',
                    action: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: DT.dangerSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${expenses.length}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: DT.danger,
                        ),
                      ),
                    ),
                  ),
                  ...expenses
                      .take(5)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AdminTile(
                            icon: Icons.receipt_long_outlined,
                            iconColor: DT.danger,
                            iconBg: DT.dangerSoft,
                            title: e.title,
                            subtitle:
                                '${e.requestedByName} · ${groupNameMap[e.groupId] ?? ''}',
                            amount: e.amount,
                            onTap:
                                () => Navigator.of(context).push(
                                  AppTheme.slideRoute(
                                    ExpenseListScreen(
                                      groupId: e.groupId,
                                      groupName: groupNameMap[e.groupId] ?? '',
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final double amount;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DS.cardRadius),
          border: Border.all(color: iconColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: DT.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'RM${amount.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: DT.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Insights sheet ───────────────────────────────────────────────────────────

class _InsightsSheet extends ConsumerWidget {
  final String userId;
  const _InsightsSheet({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups =
        ref.watch(userGroupsStreamProvider(userId)).valueOrNull ?? [];
    final debts = ref.watch(userDebtsStreamProvider(userId)).valueOrNull ?? [];

    final now = DateTime.now();
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthLabel = '${monthNames[now.month - 1]} ${now.year}';

    final groupMonthly = groups.fold<double>(0, (s, g) => s + g.monthlyAmount);
    final debtMonthly = debts
        .where((d) => d.isDebt)
        .fold<double>(0, (s, d) => s + d.monthlyPayment);
    final billMonthly = debts
        .where((d) => d.isBill)
        .fold<double>(0, (s, d) => s + d.monthlyPayment);
    final totalMonthly = groupMonthly + debtMonthly + billMonthly;

    double paidGroups = 0;
    final groupStatuses = <String, String>{};
    for (final g in groups) {
      final status =
          ref
              .watch(
                groupMonthPaymentStatusProvider((
                  groupId: g.id,
                  userId: userId,
                )),
              )
              .valueOrNull ??
          'unpaid';
      groupStatuses[g.id] = status;
      if (status == 'confirmed') paidGroups += g.monthlyAmount;
    }

    double paidDebts = 0, paidBills = 0;
    final debtPaid = <String, bool>{};
    for (final d in debts) {
      final paid = ref.watch(debtMonthPaidProvider(d.id)).valueOrNull ?? false;
      debtPaid[d.id] = paid;
      if (paid && d.isDebt) paidDebts += d.monthlyPayment;
      if (paid && d.isBill) paidBills += d.monthlyPayment;
    }

    final totalPaid = paidGroups + paidDebts + paidBills;
    final remaining = totalMonthly - totalPaid;
    final progress =
        totalMonthly > 0 ? (totalPaid / totalMonthly).clamp(0.0, 1.0) : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder:
          (ctx, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DT.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Insights',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: DT.text,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            monthLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: DT.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: DT.primarySoft,
                        borderRadius: BorderRadius.circular(DS.chipRadius),
                      ),
                      child: Text(
                        monthLabel,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: DT.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Progress card
                Container(
                  padding: const EdgeInsets.all(DS.lg),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [DT.headerGradientStart, DT.headerGradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(DS.cardRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total paid',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            'of RM${_fmt(totalMonthly)}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM${_fmt(totalPaid)}',
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            DT.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}% cleared',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          if (remaining > 0)
                            Text(
                              'RM${_fmt(remaining)} remaining',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: DT.accent,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Category breakdown
                if (totalMonthly > 0) ...[
                  Text(
                    'Category breakdown',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(DS.lg),
                    decoration: BoxDecoration(
                      color: DT.surfaceAlt,
                      borderRadius: BorderRadius.circular(DS.cardRadius),
                      border: Border.all(color: DT.border),
                    ),
                    child: Column(
                      children: [
                        if (groupMonthly > 0)
                          _CategoryBar(
                            icon: Icons.group_rounded,
                            label: 'Groups',
                            paid: paidGroups,
                            total: groupMonthly,
                            color: DT.catGroups,
                            softColor: DT.catGroupsSoft,
                          ),
                        if (groupMonthly > 0 && debtMonthly > 0)
                          const SizedBox(height: 12),
                        if (debtMonthly > 0)
                          _CategoryBar(
                            icon: Icons.account_balance_rounded,
                            label: 'Loans',
                            paid: paidDebts,
                            total: debtMonthly,
                            color: DT.catDebts,
                            softColor: DT.catDebtsSoft,
                          ),
                        if (debtMonthly > 0 && billMonthly > 0)
                          const SizedBox(height: 12),
                        if (billMonthly > 0)
                          _CategoryBar(
                            icon: Icons.receipt_rounded,
                            label: 'Bills',
                            paid: paidBills,
                            total: billMonthly,
                            color: DT.catBills,
                            softColor: DT.catBillsSoft,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Groups
                if (groups.isNotEmpty) ...[
                  Text(
                    'Groups',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...groups.map((g) {
                    final status = groupStatuses[g.id] ?? 'unpaid';
                    final (
                      Color c,
                      Color s,
                      String lbl,
                      IconData ic,
                    ) = switch (status) {
                      'confirmed' => (
                        DT.success,
                        DT.successSoft,
                        'Paid',
                        Icons.check_circle_rounded,
                      ),
                      'pending' => (
                        DT.warning,
                        DT.warningSoft,
                        'Pending',
                        Icons.hourglass_top_rounded,
                      ),
                      _ => (
                        DT.textTertiary,
                        DT.surfaceAlt,
                        'Unpaid',
                        Icons.radio_button_unchecked_rounded,
                      ),
                    };
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.lg,
                        vertical: DS.md,
                      ),
                      decoration: BoxDecoration(
                        color: DT.surface,
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                        border: Border.all(color: DT.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: DT.catGroupsSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.group_rounded,
                              size: 18,
                              color: DT.catGroups,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: DT.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'RM${_fmt(g.monthlyAmount)}/mo',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: DT.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: s,
                              borderRadius: BorderRadius.circular(
                                DS.chipRadius,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(ic, size: 12, color: c),
                                const SizedBox(width: 4),
                                Text(
                                  lbl,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: c,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // Debts & bills
                if (debts.isNotEmpty) ...[
                  Text(
                    'Loans & Bills',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DT.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...debts.map((d) {
                    final paid = debtPaid[d.id] ?? false;
                    final (Color c, Color s, String lbl) =
                        paid
                            ? (DT.success, DT.successSoft, 'Paid')
                            : (DT.textTertiary, DT.surfaceAlt, 'Unpaid');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.lg,
                        vertical: DS.md,
                      ),
                      decoration: BoxDecoration(
                        color: DT.surface,
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                        border: Border.all(color: DT.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  d.isDebt ? DT.catDebtsSoft : DT.catBillsSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              d.isDebt
                                  ? Icons.account_balance_rounded
                                  : Icons.receipt_rounded,
                              size: 18,
                              color: d.isDebt ? DT.catDebts : DT.catBills,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: DT.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'RM${_fmt(d.monthlyPayment)}/mo',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: DT.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: s,
                              borderRadius: BorderRadius.circular(
                                DS.chipRadius,
                              ),
                            ),
                            child: Text(
                              lbl,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                if (totalMonthly == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: DT.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pie_chart_outline_rounded,
                            size: 40,
                            color: DT.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No commitments yet',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: DT.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add a group or debt to see insights',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: DT.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final buf = StringBuffer();
    for (int i = 0; i < parts[0].length; i++) {
      if (i > 0 && (parts[0].length - i) % 3 == 0) buf.write(',');
      buf.write(parts[0][i]);
    }
    buf.write('.${parts[1]}');
    return buf.toString();
  }
}

class _CategoryBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final double paid;
  final double total;
  final Color color;
  final Color softColor;

  const _CategoryBar({
    required this.icon,
    required this.label,
    required this.paid,
    required this.total,
    required this.color,
    required this.softColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: softColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DT.text,
                ),
              ),
            ),
            Text(
              'RM${paid.toStringAsFixed(0)} / RM${total.toStringAsFixed(0)}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DT.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: softColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
