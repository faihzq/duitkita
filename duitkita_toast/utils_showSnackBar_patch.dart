// ─── Drop-in replacement for the old showSnackBar in lib/utils/utils.dart ───
//
// 1. Add the new file: lib/widgets/dk_toast.dart  (from dk_toast.dart)
// 2. At the top of utils.dart, add:
//        import 'package:duitkita/widgets/dk_toast.dart';
// 3. Replace the old showSnackBar body with the version below.
//
// Every existing call site keeps working unchanged:
//    showSnackBar(context, 'Debt added!');
//    showSnackBar(context, 'Network error', isError: true);

void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (isError) {
    DkToast.error(context, message);
  } else {
    DkToast.success(context, message);
  }
}

// ─── New richer call sites you can start using anywhere ───
//
// Success with a body line + inline action:
//   DkToast.success(context, 'Debt added',
//       message: 'RM 45.00 to Weekend Trip.',
//       actionLabel: 'View', onAction: () => openTrip());
//
// Error with retry:
//   DkToast.error(context, "Couldn't create group",
//       message: 'Check your connection and try again.',
//       actionLabel: 'Retry', onAction: _create);
//
// Undo pattern:
//   DkToast.info(context, 'Reminder sent to Aisha',
//       actionLabel: 'Undo', onAction: _undoReminder);
//
// Warning:
//   DkToast.warning(context, 'Low balance', message: 'You owe RM 120 total.');
