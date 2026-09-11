import 'package:flutter/material.dart';
import 'package:duitkita/services/auth_service.dart';
import 'package:duitkita/widgets/dk_toast.dart';

/// Shows a branded toast. Kept as `showSnackBar` so every existing call site
/// works unchanged; see [DkToast] for the richer forms (body copy, actions).
/// Reports without a screen context.
///
/// For results delivered after the calling screen may already be gone — the
/// case the old `final messenger = ScaffoldMessenger.of(context)` captures
/// existed to cover. Toasts mount in the app's root overlay either way, so
/// nothing is lost by not passing one.
void showAppSnackBar(String message, {bool isError = false}) =>
    showSnackBar(null, message, isError: isError);

void showSnackBar(
  BuildContext? context,
  String message, {
  bool isError = false,
}) {
  // A popped context is fine: DkToast falls back to the app's root overlay via
  // its navigatorKey, so messages reported just after Navigator.pop still show.
  if (isError) {
    DkToast.error(context, message);
  } else {
    DkToast.success(context, message);
  }
}

// Get error message from AuthError
String getAuthErrorMessage(AuthError? error) {
  switch (error) {
    case AuthError.invalidEmail:
      return 'The email address is not valid.';
    case AuthError.userDisabled:
      return 'This user has been disabled.';
    case AuthError.userNotFound:
      return 'No user found for this email.';
    case AuthError.wrongPassword:
      return 'Wrong password. If you signed up with Google, tap Continue '
          'with Google instead.';
    case AuthError.emailAlreadyInUse:
      return 'The email address is already in use.';
    // Firebase collapses "no such user" and "wrong password" into this one
    // code when email enumeration protection is on, so the message has to
    // cover both — including the case where the password was removed because
    // the account was later used with Google.
    case AuthError.invalidCredential:
      return 'Email or password is incorrect. If you signed up with Google, '
          'tap Continue with Google instead.';
    case AuthError.operationNotAllowed:
      return 'This operation is not allowed.';
    case AuthError.weakPassword:
      return 'The password is too weak.';
    case AuthError.undefined:
    default:
      return 'An unknown error occurred.';
  }
}

// Email validation
bool isValidEmail(String email) {
  // More comprehensive email regex that handles:
  // - Multiple dots before @
  // - Special characters like + and _
  // - Multiple domain segments (e.g., .co.uk)
  final emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  return emailRegExp.hasMatch(email);
}

// Password validation
bool isValidPassword(String password) {
  return password.length >= 6;
}
