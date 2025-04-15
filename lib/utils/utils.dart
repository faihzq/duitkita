import 'package:flutter/material.dart';
import 'package:duitkita/services/auth_service.dart';

// Show snackbar utility
void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
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
  final emailRegExp = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
  return emailRegExp.hasMatch(email);
}

// Password validation
bool isValidPassword(String password) {
  return password.length >= 6;
}
