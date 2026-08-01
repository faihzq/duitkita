import 'package:flutter/material.dart';
import 'package:duitkita/services/auth_service.dart';
import 'package:duitkita/widgets/dk_toast.dart';

/// Shows a branded toast. Kept as `showSnackBar` so every existing call site
/// works unchanged; see [DkToast] for the richer forms (body copy, actions).
void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  // Toasts mount into the root overlay rather than a ScaffoldMessenger, so a
  // context that has just been popped has nothing to attach to. Several call
  // sites report success immediately after Navigator.pop.
  if (!context.mounted) return;

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
      return 'Wrong password provided.';
    case AuthError.emailAlreadyInUse:
      return 'The email address is already in use.';
    case AuthError.invalidCredential:
      return 'The credentials are invalid.';
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
