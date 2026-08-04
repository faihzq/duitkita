# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run app (debug)
flutter run

# Build release AAB — this is what Google Play accepts (not an APK)
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info

# Build release APK (split per ABI, obfuscated) — sideloading / direct install only
flutter build apk --release --split-per-abi --shrink --obfuscate --split-debug-info=build/debug-info

# Lint
flutter analyze

# Tests
flutter test
flutter test test/widget_test.dart  # single file
```

## Architecture

### State Management — Riverpod
All state is managed via `flutter_riverpod`. Patterns used:
- `StreamProvider.family` for Firestore real-time streams (groups, payments, members, debts)
- `StateNotifierProvider` for auth state (`authControllerProvider` → `AuthController` extends `StateNotifier<AuthState>`)
- `ConsumerWidget` / `ConsumerStatefulWidget` throughout — no `StatelessWidget`/`StatefulWidget` except in entry files

No Bloc, no GoRouter. Navigation is plain `Navigator.push/pop`. Any future work referencing "Bloc + GoRouter" should instead use the existing Riverpod + Navigator pattern.

### Routing
`MaterialApp(home: AuthWrapper())` — no named routes.

`AuthWrapper` (`lib/core/auth_wrapper.dart`) handles the cold-start auth race: it watches `authStateProvider` but also checks `FirebaseAuth.instance.currentUser` as a synchronous fallback, preventing a flash to LoginScreen on re-launch. Wrap in `KeyedSubtree(key: ValueKey(uid))` ensures widget tree fully rebuilds on auth change.

Main app shell is `MainNavigation` (`lib/screens/main_navigation.dart`) — an `IndexedStack` with 4 tabs: Home, Groups, Debts, and an optional JDT tab (shown only when `showJdtMatches` is `true` in the user's profile).

### Firebase Services (`lib/services/`)
Each domain has its own service class + Riverpod providers at the bottom of the same file:
- `AuthService` — Firebase Auth, Google Sign-In
- `GroupService` — groups collection, subcollection `members`
- `PaymentService` — payments subcollection under groups; handles auto-approve logic and `batchVerifyPayments`
- `DebtService` — peer-to-peer debts (top-level `debts` collection)
- `NotificationService` — FCM push + local notifications
- `UpdateService` — in-app update checks

### Firestore Structure
```
groups/{groupId}
  members/{userId}          ← subcollection
  payments/{paymentId}      ← subcollection

debts/{debtId}              ← top-level, peer-to-peer

users/{userId}              ← profiles
```

Payment status flow: `pending` → `confirmed` / `rejected`.

Auto-approve is a per-group flag `autoApprovePayments` on `GroupModel`. When `true`, payments submitted via `AddPaymentScreen` are created as `confirmed` immediately. The flag is resolved from the already-watched `groupAsync` in `build()` — do not use `ref.read(groupStreamProvider(...)).valueOrNull` inside an async callback, as the stream may not have emitted yet.

`updateMemberStats` in `GroupService` accepts a `count` parameter (default 1) to correctly handle multi-month payment submissions. Stats are updated at submission time only — `confirmAllPendingPayments` and `batchVerifyPayments` intentionally skip stats to avoid double-counting.

### Theming (`lib/config/app_theme.dart`)
Material 3. Primary: `#6A1B9A` (purple). Accent: `#00BFA5` (teal). Section accent colors: Groups=purple, Debts=blue `#1565C0`, Bills=orange `#E65100`, JDT=red/gold. Always use `AppTheme` constants rather than inline colors.

### Models (`lib/models/`)
Plain Dart classes with `fromMap(Map, id)` / `toMap()`. Key models: `GroupModel`, `GroupMember`, `PaymentModel`, `DebtModel`, `UserProfile`.

### Pending Redesign
`design_handoff_duitkita_redesign/` contains JSX + HTML design references for a full app redesign. Implementation has not started. New screens go in `lib/features/<feature>/` using Riverpod + Navigator (not Bloc/GoRouter despite what the design docs may imply).
