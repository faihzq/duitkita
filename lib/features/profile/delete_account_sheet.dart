import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';
import 'package:duitkita/services/account_deletion_service.dart';
import 'package:duitkita/utils/utils.dart';
import 'package:duitkita/widgets/floating_field.dart';

/// In-app account deletion, as Google Play requires of any app that lets people
/// create an account.
///
/// Spells out what goes and what stays before asking to confirm, then takes a
/// typed confirmation so it cannot be triggered by a stray tap.
Future<void> showDeleteAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _DeleteAccountSheet(),
  );
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  /// Shown only once Firebase asks for a fresh sign-in.
  bool _needsPassword = false;

  static const _phrase = 'DELETE';

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _confirmed =>
      _confirm.text.trim().toUpperCase() == _phrase &&
      (!_needsPassword || _password.text.isNotEmpty);

  Future<void> _delete() async {
    if (!_confirmed || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final service = ref.read(accountDeletionServiceProvider);
    try {
      if (_needsPassword) {
        await service.reauthenticate(password: _password.text);
      }
      await service.deleteAccount();
      if (!mounted) return;
      _leaveForLogin();
    } on ReauthRequired {
      // Google can re-prompt without a password; email accounts must type one.
      if (service.signInMethod == 'google.com') {
        await _retryAfterGoogle(service);
        return;
      }
      if (mounted) {
        setState(() {
          _needsPassword = true;
          _busy = false;
          _error = 'Enter your password to confirm this is you.';
        });
      }
    } on AccountDeletionFailure catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _retryAfterGoogle(AccountDeletionService service) async {
    try {
      await service.reauthenticate();
      await service.deleteAccount();
      if (!mounted) return;
      _leaveForLogin();
    } on AccountDeletionFailure catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  /// Unwinds to AuthWrapper's home route, which is now the login screen.
  ///
  /// Popping just this sheet is not enough: ProfileScreen is a *pushed* route,
  /// so it would stay on top of the LoginScreen that AuthWrapper swaps in, and
  /// rebuild with no user — showing its "Not logged in" placeholder. Its
  /// still-mounted streams also keep querying under the deleted uid, which is
  /// where the PERMISSION_DENIED spam comes from.
  void _leaveForLogin() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    showAppSnackBar('Your account has been deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DT.dangerSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: DT.danger,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete your account',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DT.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _Bullets(
                title: 'THIS REMOVES',
                color: DT.danger,
                items: const [
                  'Your profile, username and photo',
                  'Your personal loans and bills',
                  'Your membership of every group and trip',
                  'Receipts and tickets you uploaded',
                ],
              ),
              const SizedBox(height: 14),
              _Bullets(
                title: 'THIS STAYS',
                color: DT.textSecondary,
                items: const [
                  'Payments you already made to a group, so its balance and '
                      'other members’ history stay correct',
                  'Groups and trips that other people are still on — someone '
                      'else takes over if you were the owner',
                ],
              ),

              const SizedBox(height: 18),
              Text(
                'This cannot be undone. Type $_phrase to confirm.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DT.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              FloatingField(
                controller: _confirm,
                label: 'Confirm',
                icon: Icons.keyboard_outlined,
                hint: _phrase,
                capitalization: TextCapitalization.characters,
                gap: 0,
              ),

              if (_needsPassword) ...[
                const SizedBox(height: 12),
                FloatingField(
                  controller: _password,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  gap: 0,
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 15, color: DT.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: DT.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _busy ? null : () => Navigator.of(context).pop(),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: DT.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: DT.border),
                        ),
                        child: Center(
                          child: Text(
                            'Keep my account',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: DT.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _confirmed && !_busy ? _delete : null,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                              _confirmed && !_busy
                                  ? DT.danger
                                  : DT.borderStrong,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child:
                              _busy
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    'Delete account',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
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
    );
  }
}

class _Bullets extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> items;

  const _Bullets({
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      height: 1.45,
                      color: DT.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
