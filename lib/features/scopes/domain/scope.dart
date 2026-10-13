/// A scope as the API describes one.
///
/// The generated output makes every field nullable because one shape serves
/// several endpoints. Here the fields the interface renders are non-nullable
/// with defined fallbacks, so no screen has to decide what an absent name means.
class Scope {
  const Scope({
    required this.id,
    required this.name,
    required this.description,
    this.googleSignInEnabled = false,
    this.selfRegistrationEnabled = false,
    this.emailVerificationUrl,
    this.passwordResetUrl,
    this.defaultLegalBasis,
    this.privacyNoticeUri,
    this.isDeleted = false,
    this.ownerIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;

  /// Whether people may sign in to this scope with Google. UI-15 toggles it,
  /// on UI-31's screen.
  final bool googleSignInEnabled;

  /// Whether people may create their own account in this scope (UC-47).
  /// UI-31 toggles it.
  final bool selfRegistrationEnabled;

  /// Where this scope's verification and sign-up confirmation emails link to,
  /// or `null` for Heimdall's default. UI-31 sets it.
  final String? emailVerificationUrl;

  /// Where this scope's password-reset emails link to, or `null` for
  /// Heimdall's default. UI-31 sets it.
  final String? passwordResetUrl;

  /// The lawful basis the scope processes its users' data on, as the API's
  /// `LegalBases` value, or `null` for the deployment default (NFR-23).
  ///
  /// Nothing here shows or edits it. It is carried because the API replaces
  /// it on every update — a value left out of the request is cleared — so an
  /// edit to the name or description has to send it back unchanged.
  final int? defaultLegalBasis;

  /// Where the scope publishes its own privacy notice, or `null` if it has
  /// none. Carried for the same reason as [defaultLegalBasis].
  final String? privacyNoticeUri;

  /// Whether the scope has been logically deleted. The listing shows these only
  /// when the user asks for them.
  final bool isDeleted;

  final List<String> ownerIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get ownerCount => ownerIds.length;

  /// Whether either email link overrides Heimdall's default.
  bool get hasCustomEmailLinks =>
      emailVerificationUrl != null || passwordResetUrl != null;

  /// This scope, with the privacy settings of [other].
  ///
  /// The update, Google Sign-In, self-registration and email-links endpoints
  /// answer with outputs that do not carry those settings, so the record the
  /// API returns from them is merged with the one already known rather than
  /// read as having none.
  Scope withPrivacySettingsOf(Scope other) => Scope(
    id: id,
    name: name,
    description: description,
    googleSignInEnabled: googleSignInEnabled,
    selfRegistrationEnabled: selfRegistrationEnabled,
    emailVerificationUrl: emailVerificationUrl,
    passwordResetUrl: passwordResetUrl,
    defaultLegalBasis: other.defaultLegalBasis,
    privacyNoticeUri: other.privacyNoticeUri,
    isDeleted: isDeleted,
    ownerIds: ownerIds,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// This scope, with the self-registration state of [other].
  ///
  /// The Google Sign-In endpoint's output does not carry it, so its answer is
  /// merged with the scope already known rather than read as "closed".
  Scope withSelfRegistrationOf(Scope other) => Scope(
    id: id,
    name: name,
    description: description,
    googleSignInEnabled: googleSignInEnabled,
    selfRegistrationEnabled: other.selfRegistrationEnabled,
    emailVerificationUrl: emailVerificationUrl,
    passwordResetUrl: passwordResetUrl,
    defaultLegalBasis: defaultLegalBasis,
    privacyNoticeUri: privacyNoticeUri,
    isDeleted: isDeleted,
    ownerIds: ownerIds,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
