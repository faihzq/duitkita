import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/core/notification_route.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/features/home/home_screen.dart';
import 'package:duitkita/features/groups/groups_list_screen.dart';
import 'package:duitkita/features/debts/debts_list_screen.dart';
import 'package:duitkita/features/profile/profile_screen.dart';
import 'package:duitkita/features/add_entry/add_entry_sheet.dart';
import 'package:duitkita/features/groups/group_detail_screen.dart';
import 'package:duitkita/features/jdt/jdt_matches_screen.dart';
import 'package:duitkita/screens/debt_detail_screen.dart';
import 'package:duitkita/services/match_service.dart';
import 'package:duitkita/services/notification_service.dart';
import 'package:duitkita/services/update_service.dart';
import 'package:duitkita/services/profile_service.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  bool _checkedUpdate = false;

  @override
  void initState() {
    super.initState();
    NotificationService.tapped.addListener(_onNotificationTapped);
  }

  @override
  void dispose() {
    NotificationService.tapped.removeListener(_onNotificationTapped);
    super.dispose();
  }

  // Handled in build, once the profile says whether the JDT tab exists.
  void _onNotificationTapped() {
    if (mounted) setState(() {});
  }

  /// Takes the user to what a tapped notification is about: the group, the
  /// bill, or the JDT tab on that team (the matches screen on its own when the
  /// tab is turned off). The matching tab is selected underneath, so Back
  /// lands somewhere sensible.
  void _openFromNotification(Map<String, dynamic> data, bool showJdt) {
    if (!mounted || NotificationService.tapped.value != data) return;
    NotificationService.tapped.value = null;
    final route = notificationRoute(data);
    if (route == null) return;

    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r.isFirst);
    switch (route) {
      case GroupRoute(:final groupId):
        setState(() => _currentIndex = 1);
        navigator.push(
          AppTheme.slideRoute(GroupDetailScreen(groupId: groupId)),
        );
      case DebtRoute(:final debtId):
        setState(() => _currentIndex = 2);
        navigator.push(AppTheme.slideRoute(DebtDetailScreen(debtId: debtId)));
      case MatchRoute(:final teamId):
        ref.read(selectedFootballTeamProvider.notifier).state =
            FootballTeam.fromId(teamId) ?? FootballTeam.jdt;
        if (showJdt) {
          setState(() => _currentIndex = 3);
        } else {
          navigator.push(
            MaterialPageRoute(builder: (_) => const JdtMatchesScreen()),
          );
        }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedUpdate) {
      _checkedUpdate = true;
      _onReady();
    }
  }

  Future<void> _onReady() async {
    // Accounts predating usernames get one derived from their name or email, so
    // they can be found by handle without having to visit Profile first. It is
    // a no-op once set, and never blocks startup.
    final user = ref.read(authControllerProvider.notifier).currentUser;
    if (user != null) {
      final profiles = ref.read(profileServiceProvider);
      // The profile has to exist before a handle can be written onto it, so
      // repair a missing document first (see ProfileService.ensureProfile).
      unawaited(
        profiles
            .ensureProfile(user)
            .then((_) => profiles.ensureUsername(user.uid)),
      );
    }

    // Reminders and activity notifications are now sent server-side by Cloud
    // Functions (see functions/index.js), so no local scheduling here.
    if (!mounted) return;
    await UpdateService.checkForUpdate(context);
  }

  void _openAddEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final profileAsync =
        userId != null ? ref.watch(userProfileStreamProvider(userId)) : null;
    final showJdt = profileAsync?.valueOrNull?.showJdtMatches ?? false;

    final tap = NotificationService.tapped.value;
    if (tap != null && (profileAsync?.hasValue ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openFromNotification(tap, showJdt),
      );
    }

    final screens = <Widget>[
      HomeScreen(onTabChange: (i) => setState(() => _currentIndex = i)),
      GroupsListScreen(onBack: () => setState(() => _currentIndex = 0)),
      DebtsListScreen(onBack: () => setState(() => _currentIndex = 0)),
      if (showJdt) const JdtMatchesScreen() else const ProfileScreen(),
    ];

    // Clamp if JDT was removed while selected
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return PopScope(
      canPop: safeIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        backgroundColor: DT.bg,
        body: IndexedStack(index: safeIndex, children: screens),
        // ── Centre FAB ─────────────────────────────────────────
        floatingActionButton: SizedBox(
          width: 52,
          height: 52,
          child: FloatingActionButton(
            onPressed: _openAddEntry,
            backgroundColor: DT.text,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        // ── Bottom nav ─────────────────────────────────────────
        bottomNavigationBar: _BottomNav(
          currentIndex: safeIndex,
          showJdt: showJdt,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

// ─── Custom bottom nav (supports center FAB slot) ─────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool showJdt;
  final void Function(int) onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.showJdt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: DT.surface,
      elevation: 0,
      padding: EdgeInsets.zero,
      notchMargin: 8,
      shape: const AutomaticNotchedShape(
        RoundedRectangleBorder(),
        StadiumBorder(),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DT.border)),
        ),
        height: 60,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.group_outlined,
              activeIcon: Icons.group_rounded,
              label: 'Groups',
              index: 1,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            // Centre gap for FAB
            const Expanded(child: SizedBox()),
            _NavItem(
              icon: Icons.account_balance_outlined,
              activeIcon: Icons.account_balance_rounded,
              label: 'Debts',
              index: 2,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            if (showJdt)
              _NavItem(
                icon: Icons.sports_soccer_outlined,
                activeIcon: Icons.sports_soccer_rounded,
                label: 'JDT',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              )
            else
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 22,
              color: active ? DT.text : DT.textTertiary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? DT.text : DT.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
