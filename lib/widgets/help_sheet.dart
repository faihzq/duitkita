import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';

/// The "How DuitKita works" guide, shown from the Profile row and the home "?"
/// button. [onShowIntro] is invoked when the user taps "Show intro" (the sheet
/// closes itself first, then the caller decides how to present the walkthrough).
void showHelpSheet(BuildContext context, {required VoidCallback onShowIntro}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => HelpSheet(onShowIntro: onShowIntro),
  );
}

class HelpSheet extends StatelessWidget {
  final VoidCallback onShowIntro;
  const HelpSheet({super.key, required this.onShowIntro});

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        icon: Icons.group_outlined,
        iconColor: DT.catGroups,
        iconBg: DT.catGroupsSoft,
        title: 'Groups',
        steps: [
          'Create a group — monthly fund or one-off split',
          'Invite members by email',
          'Members pay → admins approve',
          'Track who\'s paid and split shared expenses',
        ],
      ),
      (
        icon: Icons.account_balance_outlined,
        iconColor: DT.catDebts,
        iconBg: DT.catDebtsSoft,
        title: 'Loans',
        steps: [
          'Add a loan with its monthly payment',
          'Mark each month as paid',
          'Watch your balance shrink to zero',
          'Get reminded before the due date',
        ],
      ),
      (
        icon: Icons.receipt_outlined,
        iconColor: DT.catBills,
        iconBg: DT.catBillsSoft,
        title: 'Bills',
        steps: [
          'Add bills & subscriptions (Unifi, Astro, Spotify…)',
          'Set a due date for each',
          'Tick when paid each month',
          'Auto-rolls over every month',
        ],
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: DT.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      child: Text(
                        'How DuitKita works',
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: DT.text,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: DT.border),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: DT.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Quick guide to the three things DuitKita does.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: DT.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  ...sections.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(DS.cardRadius),
                          border: Border.all(color: DT.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: s.iconBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    s.icon,
                                    size: 18,
                                    color: s.iconColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  s.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: DT.text,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...s.steps.asMap().entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: s.iconBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${e.key + 1}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: s.iconColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        e.value,
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          color: DT.text,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Footer action
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            onShowIntro();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: DT.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: DT.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.rocket_launch_outlined,
                                  size: 16,
                                  color: DT.text,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Show intro',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: DT.text,
                                  ),
                                ),
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
        ],
      ),
    );
  }
}
