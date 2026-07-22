import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/models/debt_model.dart';
import 'package:duitkita/services/debt_service.dart';
import 'package:duitkita/screens/add_debt_screen.dart';
import 'package:duitkita/screens/debt_detail_screen.dart';

enum _Filter { debts, bills }

class DebtsListScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const DebtsListScreen({super.key, this.onBack});

  @override
  ConsumerState<DebtsListScreen> createState() => _DebtsListScreenState();
}

class _DebtsListScreenState extends ConsumerState<DebtsListScreen> {
  _Filter _filter = _Filter.debts;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final debtsAsync = ref.watch(allUserDebtsStreamProvider(userId));

    return Scaffold(
      backgroundColor: DT.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
                            'Debts & Bills',
                            style: GoogleFonts.manrope(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: DT.text,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          debtsAsync.when(
                            data: (debts) {
                              final active = debts.where((d) => d.isActive).toList();
                              final loans = active.where((d) => d.isDebt).length;
                              final bills = active.where((d) => d.isBill).length;
                              final monthly = active.fold<double>(0, (s, d) => s + d.monthlyPayment);
                              return Text(
                                '$loans loans · $bills bills · RM${monthly.toStringAsFixed(0)}/mo',
                                style: GoogleFonts.manrope(fontSize: 13, color: DT.textSecondary),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(AppTheme.slideRoute(const AddDebtScreen())),
                      child: Container(
                        width: 40, height: 40,
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

            // ── Summary card ──────────────────────────────────────
            SliverToBoxAdapter(
              child: debtsAsync.when(
                data: (debts) {
                  final active = debts.where((d) => d.isActive).toList();
                  if (active.isEmpty) return const SizedBox.shrink();
                  final loans = active.where((d) => d.isDebt).toList();
                  final bills = active.where((d) => d.isBill).toList();
                  final totalRemaining = loans.fold<double>(0, (s, d) => s + d.remainingBalance);
                  final totalMonthly = active.fold<double>(0, (s, d) => s + d.monthlyPayment);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [DT.headerGradientStart, DT.headerGradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(DS.cardRadius),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            _SumCell(
                              label: 'Monthly',
                              value: 'RM${totalMonthly.toStringAsFixed(0)}',
                              light: true,
                            ),
                            const VerticalDivider(color: Colors.white24, width: 1),
                            _SumCell(
                              label: '${loans.length} Loan${loans.length != 1 ? 's' : ''}',
                              value: loans.isEmpty ? '—' : 'RM${_fmt(totalRemaining)} left',
                              light: true,
                            ),
                            const VerticalDivider(color: Colors.white24, width: 1),
                            _SumCell(
                              label: '${bills.length} Bill${bills.length != 1 ? 's' : ''}',
                              value: bills.isEmpty ? '—' : 'RM${bills.fold<double>(0, (s, d) => s + d.monthlyPayment).toStringAsFixed(0)}/mo',
                              light: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Segmented control ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: DT.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DT.border),
                  ),
                  child: Row(
                    children: _Filter.values.map((f) {
                      final active = f == _filter;
                      final (label, icon, accent) = switch (f) {
                        _Filter.debts => ('Debts', Icons.account_balance_outlined, DT.catDebts),
                        _Filter.bills => ('Bills', Icons.autorenew_rounded, DT.catBills),
                      };
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, size: 16, color: active ? Colors.white : DT.textTertiary),
                                const SizedBox(width: 7),
                                Text(
                                  label,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: active ? Colors.white : DT.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────
            debtsAsync.when(
              data: (debts) {
                final active = debts.where((d) {
                  if (!d.isActive) return false;
                  return switch (_filter) {
                    _Filter.debts => d.isDebt,
                    _Filter.bills => d.isBill,
                  };
                }).toList();
                // Unpaid (this month) sort to the top.
                bool paidThisMonth(DebtModel d) =>
                    ref.watch(debtMonthPaidProvider(d.id)).valueOrNull ?? false;
                active.sort((a, b) {
                  final ap = paidThisMonth(a), bp = paidThisMonth(b);
                  if (ap == bp) return 0;
                  return ap ? 1 : -1;
                });
                final completed = debts.where((d) {
                  if (d.isActive) return false;
                  return switch (_filter) {
                    _Filter.debts => d.isDebt,
                    _Filter.bills => d.isBill,
                  };
                }).toList();

                if (active.isEmpty && completed.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(
                      filter: _filter,
                      onAdd: () => Navigator.of(context).push(AppTheme.slideRoute(const AddDebtScreen())),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        // Active items first, then "Completed" header + items
                        if (i < active.length) {
                          return _DebtCard(
                            debt: active[i],
                            onTap: () => Navigator.of(context).push(
                              AppTheme.slideRoute(DebtDetailScreen(debtId: active[i].id)),
                            ),
                          );
                        }
                        final completedIdx = i - active.length;
                        if (completedIdx == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 3, height: 16,
                                  decoration: BoxDecoration(
                                    color: DT.textTertiary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Completed (${completed.length})',
                                  style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: DT.textTertiary),
                                ),
                              ],
                            ),
                          );
                        }
                        return _DebtCard(
                          debt: completed[completedIdx - 1],
                          muted: true,
                          onTap: () => Navigator.of(context).push(
                            AppTheme.slideRoute(DebtDetailScreen(debtId: completed[completedIdx - 1].id)),
                          ),
                        );
                      },
                      childCount: active.length + (completed.isEmpty ? 0 : completed.length + 1),
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: DT.accent, strokeWidth: 2)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e', style: GoogleFonts.manrope(color: DT.textSecondary))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

// ─── Debt/Bill card ───────────────────────────────────────────────────────────

class _DebtCard extends ConsumerWidget {
  final DebtModel debt;
  final bool muted;
  final VoidCallback onTap;

  const _DebtCard({required this.debt, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paidAsync = ref.watch(debtMonthPaidProvider(debt.id));
    final isPaid = paidAsync.valueOrNull ?? false;

    final (iconColor, iconBg, typeLabel) = debt.isDebt
        ? (DT.catDebts, DT.catDebtsSoft, 'Debt')
        : (DT.catBills, DT.catBillsSoft, 'Bill');

    final catInfo = debt.categoryInfo;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: muted ? DT.surfaceAlt : DT.surface,
          borderRadius: BorderRadius.circular(DS.cardRadius),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon tile
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: muted ? DT.surfaceAlt : iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(catInfo.icon, size: 20, color: muted ? DT.textTertiary : iconColor),
                ),
                const SizedBox(width: 12),

                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              debt.title,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: muted ? DT.textTertiary : DT.text,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _TypePill(label: typeLabel, isDebt: debt.isDebt, muted: muted),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        debt.creditor.isNotEmpty
                            ? '${debt.creditor} · due ${debt.dueDay}${_daySuffix(debt.dueDay)}'
                            : 'Due ${debt.dueDay}${_daySuffix(debt.dueDay)} of month',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: muted ? DT.textTertiary : DT.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Amount + paid status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM${debt.monthlyPayment.toStringAsFixed(0)}',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: muted ? DT.textTertiary : DT.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (!muted)
                      _PaidBadge(isPaid: isPaid),
                  ],
                ),
              ],
            ),

            // Loan progress bar
            if (debt.isDebt && debt.totalAmount > 0 && !muted) ...[
              const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RM${_DebtCard._fmt(debt.totalPaid)} paid',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: DT.textSecondary),
                      ),
                      Text(
                        'RM${_DebtCard._fmt(debt.remainingBalance)} left · ${debt.monthsRemaining}mo',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: DT.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: debt.progressPercent,
                      minHeight: 4,
                      backgroundColor: DT.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

String _daySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1: return 'st';
    case 2: return 'nd';
    case 3: return 'rd';
    default: return 'th';
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _Filter filter;
  final VoidCallback onAdd;

  const _EmptyState({required this.filter, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (filter) {
      _Filter.debts => (
          Icons.account_balance_outlined,
          'No debts yet',
          'Add a debt — car, home, PTPTN — and track how much you\'ve paid down.',
        ),
      _Filter.bills => (
          Icons.receipt_outlined,
          'No bills yet',
          'Add subscriptions like Unifi, Astro, or Spotify and see what\'s due each month.',
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: DT.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: DT.border),
                ),
                child: Icon(icon, size: 36, color: DT.textTertiary),
              ),
              Positioned(
                right: -8, top: -8,
                child: Container(
                  width: 26, height: 26,
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
            title,
            style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: DT.text, letterSpacing: -0.4),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 14, color: DT.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: DT.text,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Add your first one',
                    style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          // How it works card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(DS.cardRadius),
              border: Border.all(color: DT.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOW IT WORKS',
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: DT.textSecondary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),
                ...[
                  'Add a loan or bill with your monthly payment',
                  'Mark each month as paid when done',
                  'Watch your loan balance shrink over time',
                ].asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(color: DT.accentSoft, borderRadius: BorderRadius.circular(6)),
                        child: Center(
                          child: Text('${e.key + 1}', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, color: DT.accentDeep)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value, style: GoogleFonts.manrope(fontSize: 13, color: DT.text, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _SumCell extends StatelessWidget {
  final String label;
  final String value;
  final bool light;

  const _SumCell({required this.label, required this.value, this.light = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: light ? Colors.white : DT.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: light ? Colors.white70 : DT.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TypePill extends StatelessWidget {
  final String label;
  final bool isDebt;
  final bool muted;

  const _TypePill({required this.label, required this.isDebt, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = muted
        ? (DT.surfaceAlt, DT.textTertiary)
        : isDebt
            ? (DT.catDebtsSoft, DT.catDebts)
            : (DT.catBillsSoft, DT.catBills);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  final bool isPaid;
  const _PaidBadge({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = isPaid
        ? (DT.successSoft, DT.success, 'Paid', Icons.check_circle_outline_rounded)
        : (DT.warningSoft, DT.warning, 'Due', Icons.radio_button_unchecked_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}
