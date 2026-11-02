// ============================================================================
// auth_widgets.dart — shared UI for login & signup (DuitKita prototype design)
// NEW FILE: create at lib/screens/auth_widgets.dart
// Imported by both login_screen.dart and signup_screen.dart. No new deps.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';

// Floating snackbar for auth errors.
SnackBar errorSnack(String msg) => SnackBar(
      content: Text(msg, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
      backgroundColor: DT.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

// Compact navy gradient hero with brand mark + decorative glow circles.
class AuthHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? leading; // e.g. a back button on signup
  const AuthHero({super.key, required this.title, required this.subtitle, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DT.headerGradientStart, DT.headerGradientEnd],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(top: -40, right: -50, child: _glowCircle(200, 0.16)),
          Positioned(bottom: -60, left: -30, child: _glowCircle(160, 0.10)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.screenPad, DS.lg, DS.screenPad, DS.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: DS.xs)],
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Colors.white, DT.accent],
                          ),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            size: 18, color: DT.primary),
                      ),
                      const SizedBox(width: 10),
                      Text('DuitKita', style: GoogleFonts.manrope(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                        letterSpacing: -0.4)),
                    ],
                  ),
                  const SizedBox(height: DS.xxl),
                  Text(title, style: GoogleFonts.manrope(
                    fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white,
                    letterSpacing: -0.6, height: 1.15)),
                  const SizedBox(height: DS.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(subtitle, style: GoogleFonts.manrope(
                      fontSize: 14, height: 1.45,
                      color: Colors.white.withValues(alpha: 0.75))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, double opacity) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            DT.accent.withValues(alpha: opacity),
            DT.accent.withValues(alpha: 0),
          ]),
        ),
      );
}

// Floating-label text field with focus ring, matching the prototype.
class FloatingField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final bool isPassword;
  final String? error;
  final String? helper;
  final Widget? leadingOverride; // e.g. 🇲🇾 +60 prefix
  final ValueChanged<String>? onChanged;

  const FloatingField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.isPassword = false,
    this.error,
    this.helper,
    this.leadingOverride,
    this.onChanged,
  });

  @override
  State<FloatingField> createState() => _FloatingFieldState();
}

class _FloatingFieldState extends State<FloatingField> {
  final _focus = FocusNode();
  bool _focused = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    final filled = widget.controller.text.isNotEmpty;
    final active = _focused || filled;
    final borderColor = hasError ? DT.danger : (_focused ? DT.text : DT.border);
    final iconColor = hasError ? DT.danger : (active ? DT.text : DT.textTertiary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: DT.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: (_focused && !hasError)
                ? [const BoxShadow(color: DT.primarySoft, blurRadius: 0, spreadRadius: 4)]
                : null,
          ),
          child: Row(
            children: [
              widget.leadingOverride ??
                  Icon(widget.prefixIcon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 150),
                      style: GoogleFonts.manrope(
                        fontSize: active ? 10 : 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: active ? 0.4 : 0,
                        color: active
                            ? (_focused ? DT.text : DT.textSecondary)
                            : DT.textTertiary,
                      ),
                      child: Text(active ? widget.label.toUpperCase() : widget.label),
                    ),
                    TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      keyboardType: widget.keyboardType,
                      textCapitalization: widget.textCapitalization,
                      obscureText: widget.isPassword && _obscure,
                      onChanged: (v) { setState(() {}); widget.onChanged?.call(v); },
                      style: GoogleFonts.manrope(
                        fontSize: 15, fontWeight: FontWeight.w600, color: DT.text,
                        letterSpacing: -0.1),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.only(top: 2, bottom: 6),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isPassword)
                GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18, color: DT.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        if (hasError || widget.helper != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                if (hasError) ...[
                  const Icon(Icons.error_outline, size: 12, color: DT.danger),
                  const SizedBox(width: 4),
                ],
                Text(
                  hasError ? widget.error! : widget.helper!,
                  style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: hasError ? DT.danger : DT.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Dark pill primary button with trailing arrow + loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: (loading || !enabled) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: DT.text,
          foregroundColor: Colors.white,
          disabledBackgroundColor: DT.border,
          disabledForegroundColor: DT.textTertiary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.cardRadius)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: GoogleFonts.manrope(
                    fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

// "Your data is encrypted..." reassurance card.
class TrustCard extends StatelessWidget {
  const TrustCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: DT.accentDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your data is encrypted and stored in Malaysia. We never share it with third parties.',
              style: GoogleFonts.manrope(
                fontSize: 11.5, height: 1.4,
                fontWeight: FontWeight.w500, color: DT.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
