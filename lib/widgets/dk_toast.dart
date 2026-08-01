import 'package:flutter/material.dart';
import 'package:duitkita/config/design_tokens.dart';

/// DuitKita branded toast system.
///
/// Renders a soft surface card with a status chip, title, optional message,
/// an optional inline action, and a slim auto-dismiss progress bar.
/// Toasts stack (newest at the bottom, max 3) and auto-dismiss.
///
/// Basic:      DkToast.success(context, 'Debt added');
/// With body:  DkToast.error(context, "Couldn't create group",
///                message: 'Check your connection and try again.',
///                actionLabel: 'Retry', onAction: _retry);
enum DkToastType { success, danger, warning, info }

class DkToast {
  DkToast._();

  static const Duration _defaultDuration = Duration(seconds: 4);
  static const int _maxStack = 3;
  static final List<_DkToastEntry> _entries = <_DkToastEntry>[];

  // ── Public API ─────────────────────────────────────────────────────────────
  static void success(BuildContext context, String title,
          {String? message,
          String? actionLabel,
          VoidCallback? onAction,
          Duration? duration}) =>
      show(context, DkToastType.success, title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration);

  static void error(BuildContext context, String title,
          {String? message,
          String? actionLabel,
          VoidCallback? onAction,
          Duration? duration}) =>
      show(context, DkToastType.danger, title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration);

  static void warning(BuildContext context, String title,
          {String? message,
          String? actionLabel,
          VoidCallback? onAction,
          Duration? duration}) =>
      show(context, DkToastType.warning, title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration);

  static void info(BuildContext context, String title,
          {String? message,
          String? actionLabel,
          VoidCallback? onAction,
          Duration? duration}) =>
      show(context, DkToastType.info, title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration);

  static void show(
    BuildContext context,
    DkToastType type,
    String title, {
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = _DkToastEntry(
      type: type,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration ?? _defaultDuration,
    );

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (ctx) => _DkToastHost(entry: entry, onDismiss: () {
        _entries.remove(entry);
        overlayEntry.remove();
        _relayout();
      }),
    );
    entry.overlayEntry = overlayEntry;

    // Enforce the stack limit — drop the oldest.
    if (_entries.length >= _maxStack) {
      _entries.first.requestDismiss();
    }
    _entries.add(entry);
    overlay.insert(overlayEntry);
    _relayout();
  }

  static void _relayout() {
    for (var i = 0; i < _entries.length; i++) {
      _entries[i].setIndex(_entries.length - 1 - i);
    }
  }
}

class _DkToastEntry {
  _DkToastEntry({
    required this.type,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    required this.duration,
  });

  final DkToastType type;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  OverlayEntry? overlayEntry;
  final ValueNotifier<int> indexFromBottom = ValueNotifier<int>(0);
  VoidCallback? _dismiss;

  void setIndex(int i) => indexFromBottom.value = i;
  void bindDismiss(VoidCallback d) => _dismiss = d;
  void requestDismiss() => _dismiss?.call();
}

class _Palette {
  const _Palette(this.fg, this.soft);
  final Color fg;
  final Color soft;
}

_Palette _paletteFor(DkToastType t) {
  switch (t) {
    case DkToastType.success:
      return const _Palette(DT.success, DT.successSoft);
    case DkToastType.danger:
      return const _Palette(DT.danger, DT.dangerSoft);
    case DkToastType.warning:
      return const _Palette(DT.warning, DT.warningSoft);
    case DkToastType.info:
      return const _Palette(DT.info, DT.infoSoft);
  }
}

IconData _iconFor(DkToastType t) {
  switch (t) {
    case DkToastType.success:
      return Icons.check_rounded;
    case DkToastType.danger:
      return Icons.error_outline_rounded;
    case DkToastType.warning:
      return Icons.warning_amber_rounded;
    case DkToastType.info:
      return Icons.info_outline_rounded;
  }
}

class _DkToastHost extends StatefulWidget {
  const _DkToastHost({required this.entry, required this.onDismiss});
  final _DkToastEntry entry;
  final VoidCallback onDismiss;

  @override
  State<_DkToastHost> createState() => _DkToastHostState();
}

class _DkToastHostState extends State<_DkToastHost>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _timer = AnimationController(vsync: this, duration: widget.entry.duration);
    widget.entry.bindDismiss(_dismiss);
    _enter.forward();
    _timer.forward().whenCompleteOrCancel(() {
      if (_timer.isCompleted) _dismiss();
    });
  }

  Future<void> _dismiss() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer.stop();
    await _enter.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _enter.dispose();
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final pal = _paletteFor(widget.entry.type);
    final e = widget.entry;

    return AnimatedBuilder(
      animation: Listenable.merge([_enter, e.indexFromBottom]),
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_enter.value);
        final idx = e.indexFromBottom.value;
        // Stack: each older toast lifts up ~74px and scales/fades back slightly.
        final bottom =
            media.padding.bottom + 16 + idx * 74.0;
        final scale = (1 - idx * 0.05) * (0.98 + 0.02 * t);
        final opacity = (idx >= DkToast._maxStack ? 0.0 : 1.0) * t;

        return Positioned(
          left: 16,
          right: 16,
          bottom: bottom + (1 - t) * 14,
          child: IgnorePointer(
            ignoring: idx != 0,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _card(pal),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(_Palette pal) {
    final e = widget.entry;
    final hasMsg = e.message != null && e.message!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DT.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F0B1F3A),
                blurRadius: 24,
                offset: Offset(0, 6)),
            BoxShadow(
                color: Color(0x0F0B1F3A),
                blurRadius: 6,
                offset: Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: pal.soft,
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(_iconFor(e.type), size: 19, color: pal.fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(top: hasMsg ? 0 : 6, bottom: hasMsg ? 0 : 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.title,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                letterSpacing: -0.2,
                                color: DT.text),
                          ),
                          if (hasMsg) ...[
                            const SizedBox(height: 2),
                            Text(
                              e.message!,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  color: DT.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (e.actionLabel != null) ...[
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: e.actionLabel!,
                      onTap: () {
                        e.onAction?.call();
                        _dismiss();
                      },
                    ),
                  ],
                ],
              ),
            ),
            // Auto-dismiss progress bar.
            SizedBox(
              height: 3,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: pal.soft)),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _timer,
                      builder: (context, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (1 - _timer.value).clamp(0.0, 1.0),
                          child: ColoredBox(color: pal.fg),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: DT.accentDeep),
        ),
      ),
    );
  }
}
