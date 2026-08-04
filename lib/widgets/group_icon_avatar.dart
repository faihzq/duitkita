import 'package:flutter/material.dart';

/// Renders a group's icon: the uploaded photo if there is one, otherwise the
/// chosen emoji, otherwise whatever [fallback] the caller supplies (initials,
/// a house glyph, …). Set via Group settings → identity card.
class GroupIconAvatar extends StatelessWidget {
  final String? iconEmoji;
  final String? iconUrl;
  final double size;
  final double radius;
  final Color background;
  final Widget fallback;

  const GroupIconAvatar({
    super.key,
    required this.iconEmoji,
    required this.iconUrl,
    required this.size,
    required this.radius,
    required this.background,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = iconUrl != null && iconUrl!.isNotEmpty;
    final hasEmoji = iconEmoji != null && iconEmoji!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child:
          hasPhoto
              ? Image.network(
                iconUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => hasEmoji ? _emoji() : fallback,
              )
              : hasEmoji
              ? _emoji()
              : fallback,
    );
  }

  Widget _emoji() => Text(iconEmoji!, style: TextStyle(fontSize: size * 0.5));
}
