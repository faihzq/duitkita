import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duitkita/config/design_tokens.dart';

/// Borderless card field with a floating label that lifts on focus/fill — the
/// single field style used across the whole app (forms, dialogs, and auth).
///
/// Form extras: [prefixText], [maxLines], [maxLength] + [showCounter], [optional].
/// Auth extras: [isPassword] (visibility toggle), [error]/[helper] text,
/// [leadingOverride] (e.g. a 🇲🇾 +60 prefix), [onChanged].
class FloatingField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? prefixText;
  final bool optional;
  final int maxLines;
  final int? maxLength;
  final bool showCounter;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool isPassword;
  final String? error;
  final String? helper;
  final Widget? leadingOverride;
  final ValueChanged<String>? onChanged;

  /// Space below the field. Defaults to 12; pass 0 when the caller manages
  /// spacing itself (e.g. the auth screens).
  final double gap;

  const FloatingField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.prefixText,
    this.optional = false,
    this.maxLines = 1,
    this.maxLength,
    this.showCounter = false,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.inputFormatters,
    this.isPassword = false,
    this.error,
    this.helper,
    this.leadingOverride,
    this.onChanged,
    this.gap = 12,
  });

  @override
  State<FloatingField> createState() => _FloatingFieldState();
}

class _FloatingFieldState extends State<FloatingField> {
  final _focus = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_onText);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _focus.dispose();
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final active = focused || widget.controller.text.isNotEmpty;
    final multiline = widget.maxLines > 1;
    final hasError = widget.error != null;
    final borderColor = hasError ? DT.danger : (focused ? DT.text : DT.border);
    final iconColor =
        hasError ? DT.danger : (active ? DT.text : DT.textTertiary);

    return Padding(
      padding: EdgeInsets.only(bottom: widget.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow:
                  (focused && !hasError)
                      ? [
                        BoxShadow(
                          color: DT.primary.withValues(alpha: 0.08),
                          blurRadius: 8,
                          spreadRadius: 4,
                        ),
                      ]
                      : null,
            ),
            child: Row(
              crossAxisAlignment:
                  multiline
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: multiline ? 12 : 0),
                  child:
                      widget.leadingOverride ??
                      Icon(widget.icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: GoogleFonts.manrope(
                                fontSize: active ? 10 : 14,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w500,
                                color:
                                    active
                                        ? (focused ? DT.text : DT.textSecondary)
                                        : DT.textTertiary,
                                letterSpacing: active ? 0.4 : 0,
                              ),
                              child: Text(
                                active
                                    ? '${widget.label.toUpperCase()}${widget.optional ? ' · OPTIONAL' : ''}'
                                    : '${widget.label}${widget.optional ? ' · optional' : ''}',
                              ),
                            ),
                          ),
                          if (widget.showCounter &&
                              widget.maxLength != null &&
                              active)
                            Text(
                              '${widget.controller.text.length}/${widget.maxLength}',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: DT.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        keyboardType: widget.keyboardType,
                        textCapitalization: widget.capitalization,
                        inputFormatters: widget.inputFormatters,
                        maxLines: widget.maxLines,
                        maxLength: widget.maxLength,
                        obscureText: widget.isPassword && _obscure,
                        onChanged: widget.onChanged,
                        buildCounter:
                            widget.maxLength == null
                                ? null
                                : (
                                  _, {
                                  required int currentLength,
                                  required bool isFocused,
                                  int? maxLength,
                                }) => null,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DT.text,
                          letterSpacing: -0.1,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.only(top: 2),
                          prefixText: widget.prefixText,
                          prefixStyle: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: DT.textTertiary,
                          ),
                          hintText: focused ? widget.hint : null,
                          hintStyle: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: DT.textTertiary,
                          ),
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
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                        color: DT.textSecondary,
                      ),
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
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasError ? DT.danger : DT.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
