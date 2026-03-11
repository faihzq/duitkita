import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duitkita/config/app_theme.dart';
import 'package:duitkita/controllers/auth_controller.dart';
import 'package:duitkita/screens/home_screen.dart';
import 'package:duitkita/screens/groups_list_screen.dart';
import 'package:duitkita/screens/debts_list_screen.dart';
import 'package:duitkita/screens/jdt_matches_screen.dart';
import 'package:duitkita/services/update_service.dart';
import 'package:duitkita/services/notification_service.dart';
import 'package:duitkita/services/profile_service.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;
  bool _checkedUpdate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedUpdate) {
      _checkedUpdate = true;
      _onReady();
    }
  }

  Future<void> _onReady() async {
    await UpdateService.checkForUpdate(context);
    await NotificationService.scheduleGroupReminders();
    await NotificationService.checkAndNotifyUnpaid();
    await NotificationService.checkNewGroupMembership();
    await NotificationService.checkRecentPaymentsForAdmin();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider.notifier).currentUser?.uid;
    final profileAsync = userId != null ? ref.watch(userProfileStreamProvider(userId)) : null;
    final showJdt = profileAsync?.valueOrNull?.showJdtMatches ?? false;

    final screens = <Widget>[
      const HomeScreen(),
      const GroupsListScreen(),
      const DebtsListScreen(),
      if (showJdt) const JdtMatchesScreen(),
    ];

    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.group_outlined),
        activeIcon: Icon(Icons.group),
        label: 'Groups',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.account_balance_outlined),
        activeIcon: Icon(Icons.account_balance),
        label: 'Debts',
      ),
      if (showJdt)
        const BottomNavigationBarItem(
          icon: Icon(Icons.sports_soccer_outlined),
          activeIcon: Icon(Icons.sports_soccer),
          label: 'JDT',
        ),
    ];

    // Clamp index if JDT tab was removed while selected
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return PopScope(
      canPop: safeIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textHint,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          elevation: 0,
          items: navItems,
        ),
      ),
    ),
    );
  }
}
