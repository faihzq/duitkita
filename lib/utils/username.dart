/// Username rules, kept pure so they can be tested and reused by both the
/// profile editor and the "add someone" lookups.
library;

/// Lower bound keeps handles typeable; upper bound keeps them renderable in the
/// avatar rows and member lists.
const int kUsernameMinLength = 3;
const int kUsernameMaxLength = 20;

final _illegalChars = RegExp(r'[^a-z0-9_]');

/// Strips the decorative "@", trims, and lowercases. Usernames are stored and
/// compared in lower case so `@Fairul` and `@fairul` are the same person.
String normaliseUsername(String raw) {
  var value = raw.trim().toLowerCase();
  while (value.startsWith('@')) {
    value = value.substring(1);
  }
  return value.trim();
}

/// Null when acceptable, otherwise a message fit to show the user.
String? usernameError(String raw) {
  final handle = normaliseUsername(raw);
  if (handle.isEmpty) return 'Pick a username';
  if (handle.length < kUsernameMinLength) {
    return 'At least $kUsernameMinLength characters';
  }
  if (handle.length > kUsernameMaxLength) {
    return 'At most $kUsernameMaxLength characters';
  }
  if (!RegExp(r'^[a-z]').hasMatch(handle)) {
    return 'Must start with a letter';
  }
  if (_illegalChars.hasMatch(handle)) {
    return 'Letters, numbers and underscores only';
  }
  return null;
}

bool isValidUsername(String raw) => usernameError(raw) == null;

/// A starting handle derived from whatever the account already has.
///
/// Used to give existing accounts a username automatically — the feature is
/// useless until people actually have one, and asking everyone to pick would
/// leave most of them unfindable.
String suggestUsername({String? name, String? email, String? uid}) {
  for (final source in [name, email?.split('@').first]) {
    final candidate = _slug(source);
    if (candidate != null) return candidate;
  }
  // Nothing usable — fall back to something stable rather than random, so a
  // repeated run doesn't churn through handles.
  final suffix = (uid ?? '').replaceAll(_illegalChars, '');
  return 'user${suffix.isEmpty ? '' : suffix.substring(0, suffix.length.clamp(0, 8))}'
      .padRight(kUsernameMinLength, '0');
}

String? _slug(String? source) {
  if (source == null) return null;
  var value = source.toLowerCase().replaceAll(_illegalChars, '');
  if (value.length > kUsernameMaxLength) {
    value = value.substring(0, kUsernameMaxLength);
  }
  // Must start with a letter; drop leading digits/underscores rather than
  // rejecting an otherwise fine name.
  while (value.isNotEmpty && !RegExp(r'^[a-z]').hasMatch(value)) {
    value = value.substring(1);
  }
  if (value.length < kUsernameMinLength) return null;
  return value;
}

/// `base`, `base2`, `base3`… for when a handle is already taken. Keeps the
/// result inside [kUsernameMaxLength] by trimming the base, not the number.
String usernameAttempt(String base, int attempt) {
  if (attempt <= 1) return base;
  final suffix = '$attempt';
  final room = kUsernameMaxLength - suffix.length;
  final trimmed = base.length > room ? base.substring(0, room) : base;
  return '$trimmed$suffix';
}
