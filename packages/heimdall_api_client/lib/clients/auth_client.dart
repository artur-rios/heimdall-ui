// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/confirm_two_factor_auth_command.dart';
import '../models/confirm_two_factor_auth_command_output_data_output.dart';
import '../models/disable_two_factor_auth_command.dart';
import '../models/disable_two_factor_auth_command_output_data_output.dart';
import '../models/enable_two_factor_auth_command.dart';
import '../models/enable_two_factor_auth_command_output_data_output.dart';
import '../models/google_sign_in_command.dart';
import '../models/google_sign_in_command_output_data_output.dart';
import '../models/google_sign_out_command_output_data_output.dart';
import '../models/login_command.dart';
import '../models/login_command_output_data_output.dart';
import '../models/password_recovery_command.dart';
import '../models/password_recovery_command_output_data_output.dart';
import '../models/regenerate_recovery_codes_command.dart';
import '../models/regenerate_recovery_codes_command_output_data_output.dart';
import '../models/resend_verification_email_command_output_data_output.dart';
import '../models/reset_password_command.dart';
import '../models/reset_password_command_output_data_output.dart';
import '../models/verify_email_command.dart';
import '../models/verify_email_command_output_data_output.dart';
import '../models/verify_two_factor_auth_command.dart';
import '../models/verify_two_factor_auth_command_output_data_output.dart';

part 'auth_client.g.dart';

@RestApi()
abstract class AuthClient {
  factory AuthClient(Dio dio, {String? baseUrl}) = _AuthClient;

  /// Authenticates a person by email and password and returns a token (UC-11, FR-AU-01…07). A.
  /// `User` also sends the `PublicId` of their scope; a `ScopeAdmin` or.
  /// `SystemAdmin` sends credentials only. Open to anonymous callers — this is where a.
  /// caller gets the token every other endpoint requires. Every rejection (AF-11a…AF-11e).
  /// answers 401 alike, so the endpoint cannot be used to enumerate accounts.
  ///
  /// **Anonymous** — no bearer token required.
  @POST('/api/auth/login')
  Future<LoginCommandOutputDataOutput> authLogin({@Body() LoginCommand? body});

  /// Requests a password reset link (UC-12, FR-PR-01/02). A `User` also sends the.
  /// `PublicId` of their scope; a `ScopeAdmin` or `SystemAdmin` sends the email.
  /// alone. Open to anonymous callers — someone who has lost their password cannot hold a.
  /// token.
  ///
  /// Answers 200 with the same message whether or not the address belongs to anyone (AF-12a),.
  /// so the endpoint cannot be used to enumerate accounts. The only rejection is a malformed.
  /// request (400, NFR-10), which says nothing about who is registered.
  ///
  /// **Anonymous** — no bearer token required.
  @POST('/api/auth/password-recovery')
  Future<PasswordRecoveryCommandOutputDataOutput> authPasswordRecovery({
    @Body() PasswordRecoveryCommand? body,
  });

  /// Sets a new password from the reset token mailed by UC-12 (UC-13, FR-PR-03/04). Open to.
  /// anonymous callers for the same reason: the token is the only credential someone who has.
  /// lost their password can present.
  ///
  /// Unlike the two endpoints above, each rejection is named — unknown (AF-13c), expired.
  /// (AF-13a), and spent (AF-13b) tokens all answer 400 with their own message, as does a.
  /// malformed request (AF-13d). Nothing is disclosed by the distinction: the token identifies.
  /// no account to a caller who does not already hold it.
  ///
  /// **Anonymous** — no bearer token required.
  @POST('/api/auth/password-reset')
  Future<ResetPasswordCommandOutputDataOutput> authResetPassword({
    @Body() ResetPasswordCommand? body,
  });

  /// Confirms an email address from the verification token mailed at person creation (UC-14,.
  /// FR-EV-03). Open to anonymous callers: the person reaches this from a link in their mail.
  /// client, where they hold no bearer token — and the point of the link is that they have not.
  /// proved anything yet.
  ///
  /// Each rejection is named, as UC-13's are — unknown (AF-14c), expired (AF-14a), and spent.
  /// (AF-14b) tokens all answer 400 with their own message, as does a request carrying no token.
  /// at all. An address that was already verified answers 200: UC-14 defines no alternative flow.
  /// for it, and the link did what it promised.
  ///
  /// **Anonymous** — no bearer token required.
  @POST('/api/auth/verify-email')
  Future<VerifyEmailCommandOutputDataOutput> authVerifyEmail({
    @Body() VerifyEmailCommand? body,
  });

  /// Retires the caller's outstanding verification links and mails a fresh one (UC-15,.
  /// FR-EV-04), for someone whose first link expired, was lost, or never arrived. The one.
  /// authenticated endpoint on this controller — and the reason it takes no request body: the.
  /// person is read from the bearer token, so a caller can only ever ask for their own link.
  ///
  /// No `RoleRequirement`: the authorization matrix grants email verification to all three.
  /// roles and withholds it from anonymous callers, which is exactly what authentication alone.
  /// enforces. An address that is already verified answers 400 (AF-15a) — unlike UC-14's.
  /// idempotent success, since a link mailed to a verified address could do nothing when clicked.
  /// A token naming a person who no longer exists answers 404: it was validated, but there is no.
  /// address left to send to.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @POST('/api/auth/resend-verification')
  Future<ResendVerificationEmailCommandOutputDataOutput>
  authResendVerification();

  /// Signs a Google account up or in against a scope and returns a token (UC-25,.
  /// FR-GO-03…FR-GO-13). The caller sends the ID token they obtained from Google and the.
  /// `PublicId` of the scope they are entering; the first call for a given Google account.
  /// in a given scope creates the Google User, every later one authenticates it. Open to.
  /// anonymous callers for the same reason `login` is — this is where a Google User gets.
  /// the token every other endpoint requires.
  ///
  /// Both 401 flows answer alike (AF-25a, AF-25d), as UC-11's do, so an anonymous caller cannot.
  /// use the endpoint to learn which Google accounts a scope has registered or which were.
  /// deleted. AF-25b answers 403 for a missing, deleted, and disabled scope alike — a scope is.
  /// not enumerable through here either. Only AF-25c (409) is named, and it discloses nothing:.
  /// the caller has already proved the address is theirs.
  ///
  /// **Anonymous** — no bearer token required.
  @POST('/api/auth/google')
  Future<GoogleSignInCommandOutputDataOutput> authGoogleSignIn({
    @Body() GoogleSignInCommand? body,
  });

  /// Ends the caller's Google-authenticated session (UC-26, FR-GO-18). Takes no request body for.
  /// the reason `resend-verification` does not: the Google User is read from the bearer.
  /// token, so a caller can only ever sign themselves out.
  ///
  /// No `RoleRequirement`, deliberately. The authorization matrix grants Google sign-out to.
  /// a Google User acting on themselves and marks it not-applicable for both administrator roles.
  /// — who can never be Google Users (FR-GO-04) — so the rule is "the caller is a live Google.
  /// User", which is data the attribute cannot see and the handler checks. It also keeps the.
  /// endpoint to the two answers UC-26 defines: 200, or 401 for every rejection. A missing or.
  /// malformed token is the other half of AF-26a and never reaches here — authentication answers.
  /// it with the same 401.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @POST('/api/auth/google/sign-out')
  Future<GoogleSignOutCommandOutputDataOutput> authGoogleSignOut();

  /// Begins opting the caller into two-factor authentication (UC-36, FR-2F-01…FR-2F-03),.
  /// selecting an authenticator-app method, an email method, or both. Setup stays inactive until.
  /// confirmed by UC-37. The person acted on is always the caller themselves — read from the.
  /// bearer token, the same as M:ArturRios.Heimdall.WebApi.Controllers.AuthController.ResendVerification.
  ///
  /// No `RoleRequirement`: the authorization matrix grants two-factor setup to all three.
  /// person roles (`User`, `ScopeAdmin`, `SystemAdmin`) and withholds it from.
  /// anonymous callers, which is exactly what authentication alone enforces. AF-36b (Google User,.
  /// 403) is not a role the attribute can see — a Google-issued token names a.
  /// `GoogleUser`, not a `Person` — so the handler enforces it by resolving the caller.
  /// against the `Person` table itself.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @POST('/api/auth/2fa/enable')
  Future<EnableTwoFactorAuthCommandOutputDataOutput> authEnableTwoFactorAuth({
    @Body() EnableTwoFactorAuthCommand? body,
  });

  /// Confirms the caller's pending two-factor authentication setup (UC-37, FR-2F-04/05), proving.
  /// control of every method selected in UC-36 — an `appCode` if `AppEnabled`, an.
  /// `emailCode` if `EmailEnabled`, both if both. On success, activates the.
  /// configuration and returns ten recovery codes in plaintext, exactly once. The person acted on.
  /// is always the caller themselves — read from the bearer token, the same as.
  /// M:ArturRios.Heimdall.WebApi.Controllers.AuthController.EnableTwoFactorAuth(ArturRios.Heimdall.Command.Input.EnableTwoFactorAuthCommand).
  ///
  /// No `RoleRequirement`, for the same reason M:ArturRios.Heimdall.WebApi.Controllers.AuthController.EnableTwoFactorAuth(ArturRios.Heimdall.Command.Input.EnableTwoFactorAuthCommand) has none:.
  /// the authorization matrix grants confirmation to all three person roles and withholds it from.
  /// anonymous callers, which authentication alone already enforces. AF-37a's 404 covers both "no.
  /// setup was ever initiated" and "the caller is a Google User" alike — a Google-issued token.
  /// names a `GoogleUser`, never a row this lookup could find.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @POST('/api/auth/2fa/confirm')
  Future<ConfirmTwoFactorAuthCommandOutputDataOutput> authConfirmTwoFactorAuth({
    @Body() ConfirmTwoFactorAuthCommand? body,
  });

  /// Completes a 2FA-gated login (UC-38, FR-2F-09) by redeeming the challenge token AF-11g.
  /// issued at login, together with an app/email code or a recovery code, for the full.
  /// authentication token. Open to anonymous callers — the caller holds no bearer token yet,.
  /// only the challenge token, which is submitted here as a plain request body field, exactly.
  /// like M:ArturRios.Heimdall.WebApi.Controllers.AuthController.ResetPassword(ArturRios.Heimdall.Command.Input.ResetPasswordCommand)'s token, never as an `Authorization` header.
  ///
  /// AF-38a (invalid/expired challenge token) and AF-38b/AF-38c (wrong code, or a reused.
  /// recovery code) all answer the same 401 with the same message, so this endpoint cannot be.
  /// used to distinguish a forged challenge from an expired one, or a wrong code from a.
  /// recovery code that was already spent. ArturRios.Heimdall.WebApi.Security.MfaPendingGuardFilter is what keeps a.
  /// challenge token from working anywhere else (FR-2F-10) — it never applies here, since this.
  /// action never reads the challenge token as a bearer credential in the first place.
  ///
  /// **Anonymous** — no bearer token required.
  @POST('/api/auth/2fa/verify')
  Future<VerifyTwoFactorAuthCommandOutputDataOutput> authVerifyTwoFactorAuth({
    @Body() VerifyTwoFactorAuthCommand? body,
  });

  /// Turns off the caller's own two-factor authentication (UC-39, FR-2F-11), requiring both the.
  /// caller's current password and a valid second factor — an app/email code or a recovery.
  /// code — exactly as hard to satisfy as a login. On success, permanently removes the.
  /// `TWO_FACTOR_AUTH` row and its recovery codes. The person acted on is always the.
  /// caller themselves — read from the bearer token, the same as M:ArturRios.Heimdall.WebApi.Controllers.AuthController.EnableTwoFactorAuth(ArturRios.Heimdall.Command.Input.EnableTwoFactorAuthCommand).
  ///
  /// No `RoleRequirement`, for the same reason M:ArturRios.Heimdall.WebApi.Controllers.AuthController.EnableTwoFactorAuth(ArturRios.Heimdall.Command.Input.EnableTwoFactorAuthCommand) has none:.
  /// the authorization matrix grants disabling two-factor authentication to all three person.
  /// roles and withholds it from anonymous callers, which authentication alone already enforces.
  /// AF-39a (404, not active) and AF-39b/AF-39c (401, wrong password / wrong second factor) are.
  /// kept as the three separate flows the Use Case Specification Document defines them as —.
  /// unlike UC-38's AF-38b/AF-38c, which the spec collapses into one message, UC-39 lists the.
  /// password mismatch and the second-factor mismatch as distinct conditions, so they are not.
  /// merged here.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @POST('/api/auth/2fa/disable')
  Future<DisableTwoFactorAuthCommandOutputDataOutput> authDisableTwoFactorAuth({
    @Body() DisableTwoFactorAuthCommand? body,
  });

  /// Invalidates the caller's current recovery codes and issues a fresh set of ten (UC-40,.
  /// FR-2F-12), requiring a valid second factor — an app/email code or one of the caller's.
  /// remaining recovery codes — verified exactly as M:ArturRios.Heimdall.WebApi.Controllers.AuthController.VerifyTwoFactorAuth(ArturRios.Heimdall.Command.Input.VerifyTwoFactorAuthCommand) verifies.
  /// one. On success, every existing `TWO_FACTOR_RECOVERY_CODE` row for the caller is.
  /// removed, including any still unused, and replaced with ten new ones. The person acted on is.
  /// always the caller themselves — read from the bearer token, the same as.
  /// M:ArturRios.Heimdall.WebApi.Controllers.AuthController.EnableTwoFactorAuth(ArturRios.Heimdall.Command.Input.EnableTwoFactorAuthCommand).
  ///
  /// No `RoleRequirement`, for the same reason M:ArturRios.Heimdall.WebApi.Controllers.AuthController.EnableTwoFactorAuth(ArturRios.Heimdall.Command.Input.EnableTwoFactorAuthCommand) has none:.
  /// the authorization matrix grants regenerating recovery codes to all three person roles and.
  /// withholds it from anonymous callers, which authentication alone already enforces. AF-40a.
  /// (404, not active) and AF-40b (401, second factor invalid) reuse UC-39's "not active" and.
  /// UC-38's "factor invalid" messages rather than inventing new ones.
  ///
  /// **Any authenticated caller** — the handler decides who may act, so no role is required at the door.
  @POST('/api/auth/2fa/recovery-codes/regenerate')
  Future<RegenerateRecoveryCodesCommandOutputDataOutput>
  authRegenerateRecoveryCodes({@Body() RegenerateRecoveryCodesCommand? body});
}
