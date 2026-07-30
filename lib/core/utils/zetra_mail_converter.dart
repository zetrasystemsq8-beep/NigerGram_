/// Converts a user-facing ZetraMail address into the internal Supabase
/// auth email used for authentication.
///
/// Users type things like:
///   testing@zetramail.ng
///
/// Supabase authenticates them internally as:
///   testing@auth.zetraid.internal
///
/// The internal email is NEVER shown to the user anywhere in the UI.
class ZetraMailConverter {
  ZetraMailConverter._();

  static const String _zetraMailDomain = '@zetramail.ng';
  static const String _internalDomain = '@auth.zetraid.internal';

  /// Converts a raw ZetraMail input into the internal Supabase auth email.
  ///
  /// Accepts input with or without the `@zetramail.ng` suffix already
  /// present, and is case-insensitive / whitespace-tolerant.
  static String toInternalEmail(String rawInput) {
    final trimmed = rawInput.trim().toLowerCase();

    final String localPart;
    if (trimmed.contains('@')) {
      localPart = trimmed.split('@').first;
    } else {
      localPart = trimmed;
    }

    return '$localPart$_internalDomain';
  }

  /// Returns true if [email] is an internal ZetraID auth email
  /// (i.e. already converted).
  static bool isInternalEmail(String email) {
    return email.trim().toLowerCase().endsWith(_internalDomain);
  }

  /// Given an internal auth email (e.g. testing@auth.zetraid.internal),
  /// returns the local part only (e.g. "testing"), useful for deriving
  /// display handles without ever showing the internal domain.
  static String localPartFromInternalEmail(String internalEmail) {
    final trimmed = internalEmail.trim().toLowerCase();
    if (trimmed.contains('@')) {
      return trimmed.split('@').first;
    }
    return trimmed;
  }

  /// Builds the user-facing ZetraMail address (for display only) from a
  /// local part, e.g. "testing" -> "testing@zetramail.ng".
  static String toDisplayZetraMail(String localPart) {
    return '${localPart.trim().toLowerCase()}$_zetraMailDomain';
  }
}
