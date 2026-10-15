import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ids/public_id.dart';
import '../scope/scope_source.dart';
import '../storage/token_store.dart';

/// The browser the application was opened in, as far as start-up needs it.
///
/// Behind an interface so nothing outside the platform files touches the
/// browser, and so every rule below is tested without one.
abstract interface class EntryBrowser {
  /// The address the page was opened at.
  Uri get address;

  /// Replaces the current history entry's address, without navigating.
  void replaceAddress(Uri address);

  /// Keeps the target scope in this tab's session storage, under
  /// [scopeStorageKey].
  void keepScope(String scopeId);

  /// Removes [key] from the origin's local storage.
  void forgetLocal(String key);
}

/// What the address the application was opened at carried, once taken out of
/// it.
class EntryLink {
  const EntryLink({this.resetToken, this.verificationToken});

  /// The token of a `/password-reset?token=…` link.
  final String? resetToken;

  /// The token of a `/verify-email?token=…` link.
  final String? verificationToken;
}

/// The query parameter a calling application names the target scope with.
const String scopeParameter = 'scope';

/// Reads what the entry address carries and takes it out of the address bar.
///
/// - `?scope=<PublicId>` on any route is the calling application's target
///   scope. A caller on another origin cannot write the UI's session storage,
///   so it hands the scope over in the URL and the UI copies it there itself.
///   A value that is not a `PublicId` is ignored. Either way the parameter
///   leaves the address.
/// - `?token=…` on `/password-reset` or `/verify-email` is a credential. It is
///   kept in memory for the screen, and leaves the address, so it is not left
///   in the history entry or sent as the Referer of every later request.
/// - The session token builds before per-tab sessions kept in local storage,
///   and the raw key it was encrypted with beside it, are removed.
///
/// The route is the address's last non-empty segment, so a build served under
/// a sub-path, or a link with a trailing slash, is read the same way. The rest of the query and the fragment are
/// kept, and the address is replaced only when something was taken out of it.
EntryLink takeEntryLink(EntryBrowser browser) {
  for (final key in SecureTokenStore.legacyWebEntries) {
    browser.forgetLocal(key);
  }

  final address = browser.address;
  final query = Map<String, List<String>>.of(address.queryParametersAll);
  // The last segment that is not empty: go_router opens `/password-reset/`
  // as `/password-reset`, so a trailing slash must not hide the route.
  final route = address.pathSegments.lastWhere(
    (segment) => segment.isNotEmpty,
    orElse: () => '',
  );

  final scope = query.remove(scopeParameter);
  final scopeId = scope == null || scope.isEmpty ? null : scope.first;
  if (scopeId != null && isPublicId(scopeId)) {
    browser.keepScope(scopeId);
  }

  String? resetToken;
  String? verificationToken;
  final takesToken = route == 'password-reset' || route == 'verify-email';
  final token = takesToken ? query.remove('token') : null;
  if (token != null && token.isNotEmpty) {
    if (route == 'password-reset') {
      resetToken = token.first;
    } else {
      verificationToken = token.first;
    }
  }

  if (scope != null || token != null) {
    browser.replaceAddress(
      Uri(
        scheme: address.scheme,
        userInfo: address.userInfo,
        host: address.host,
        port: address.hasPort ? address.port : null,
        path: address.path,
        queryParameters: query.isEmpty ? null : query,
        fragment: address.hasFragment ? address.fragment : null,
      ),
    );
  }

  return EntryLink(
    resetToken: resetToken,
    verificationToken: verificationToken,
  );
}

/// Holds what start-up took from the entry address until it has been used.
///
/// A link token is single-use. Once the API has taken it, a later visit to
/// the same screen in this tab (back and forward, say) must not offer or send
/// it again, so each screen forgets its token when it is done with it.
class EntryLinkController extends Notifier<EntryLink> {
  EntryLinkController([this._taken = const EntryLink()]);

  final EntryLink _taken;

  @override
  EntryLink build() => _taken;

  /// The reset token has set a password.
  void forgetResetToken() {
    if (state.resetToken != null) {
      state = EntryLink(verificationToken: state.verificationToken);
    }
  }

  /// The API has answered the verification token, either way.
  void forgetVerificationToken() {
    if (state.verificationToken != null) {
      state = EntryLink(resetToken: state.resetToken);
    }
  }
}

/// What start-up took from the entry address. Overridden at start-up with
/// the platform's answer; nothing was taken off the web.

final NotifierProvider<EntryLinkController, EntryLink> entryLinkProvider =
    NotifierProvider<EntryLinkController, EntryLink>(EntryLinkController.new);
