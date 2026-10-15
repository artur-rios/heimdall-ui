import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/entry/entry_link.dart';
import 'package:heimdall_ui/core/entry/platform_entry_link.dart';

/// A browser the start-up step can read and change, and a test can inspect.
class _FakeBrowser implements EntryBrowser {
  _FakeBrowser(String address) : address = Uri.parse(address);

  @override
  Uri address;

  final List<Uri> replaced = <Uri>[];
  final Map<String, String> session = <String, String>{};
  final List<String> forgotten = <String>[];

  @override
  void replaceAddress(Uri address) {
    replaced.add(address);
    this.address = address;
  }

  @override
  void keepScope(String scopeId) => session['heimdall.scopeId'] = scopeId;

  @override
  void forgetLocal(String key) => forgotten.add(key);
}

void main() {
  const guid = '6f1d3a00-0000-0000-0000-0000000000aa';

  // A calling application on another origin names the scope in the URL; the
  // UI keeps it in its own session storage and the address bar loses it.
  test('GivenAGuidScope_WhenTheAppStarts_ThenItIsKeptAndStripped', () {
    // Given
    final browser = _FakeBrowser('https://ui.example.com/login?scope=$guid');

    // When
    takeEntryLink(browser);

    // Then
    expect(browser.session['heimdall.scopeId'], guid);
    expect(browser.address.toString(), 'https://ui.example.com/login');
  });

  test('GivenANonGuidScope_WhenTheAppStarts_ThenItIsIgnoredAndStripped', () {
    // Given
    final browser = _FakeBrowser(
      'https://ui.example.com/login?scope=..%2Fpersons',
    );

    // When
    takeEntryLink(browser);

    // Then
    expect(browser.session, isEmpty);
    expect(browser.address.toString(), 'https://ui.example.com/login');
  });

  // The reset and verification tokens are credentials: once read they leave
  // the address bar, the history entry and every later Referer.
  test('GivenAResetLink_WhenTheAppStarts_ThenItsTokenIsTakenAndStripped', () {
    // Given
    final browser = _FakeBrowser(
      'https://ui.example.com/password-reset?token=reset-token',
    );

    // When
    final link = takeEntryLink(browser);

    // Then
    expect(link.resetToken, 'reset-token');
    expect(link.verificationToken, isNull);
    expect(browser.address.toString(), 'https://ui.example.com/password-reset');
  });

  test('GivenAVerifyLink_WhenTheAppStarts_ThenItsTokenIsTakenAndStripped', () {
    // Given
    final browser = _FakeBrowser(
      'https://ui.example.com/verify-email?token=verify-token',
    );

    // When
    final link = takeEntryLink(browser);

    // Then
    expect(link.verificationToken, 'verify-token');
    expect(link.resetToken, isNull);
    expect(browser.address.toString(), 'https://ui.example.com/verify-email');
  });

  // A build served under a sub-path (`--base-href`) has the route last.
  test('GivenASubPathResetLink_WhenTheAppStarts_ThenItsTokenIsTaken', () {
    // Given
    final browser = _FakeBrowser(
      'https://ui.example.com/heimdall/password-reset?token=t#top',
    );

    // When
    final link = takeEntryLink(browser);

    // Then
    expect(link.resetToken, 't');
    expect(
      browser.address.toString(),
      'https://ui.example.com/heimdall/password-reset#top',
    );
  });

  // go_router opens `/password-reset/` as `/password-reset`, so a link with a
  // trailing slash reaches the screen and must lose its token all the same.
  for (final route in <String>['password-reset', 'verify-email']) {
    test(
      'GivenATrailingSlashLink_WhenTheAppStarts_ThenItsTokenIsTaken $route',
      () {
        // Given
        final browser = _FakeBrowser(
          'https://ui.example.com/$route/?token=slash-token',
        );

        // When
        final link = takeEntryLink(browser);

        // Then
        expect(
          route == 'password-reset' ? link.resetToken : link.verificationToken,
          'slash-token',
        );
        expect(browser.address.toString(), 'https://ui.example.com/$route/');
      },
    );
  }

  test('GivenOtherParameters_WhenStripped_ThenTheyAreKept', () {
    // Given
    final browser = _FakeBrowser(
      'https://ui.example.com/login?from=%2Fscopes&scope=$guid',
    );

    // When
    takeEntryLink(browser);

    // Then
    expect(browser.address.path, '/login');
    expect(browser.address.queryParameters, <String, String>{
      'from': '/scopes',
    });
  });

  // Only those two screens take a token; anywhere else it is not one of ours.
  test('GivenATokenOnAnotherRoute_WhenTheAppStarts_ThenItIsLeftAlone', () {
    // Given
    final browser = _FakeBrowser('https://ui.example.com/login?token=x');

    // When
    final link = takeEntryLink(browser);

    // Then
    expect(link.resetToken, isNull);
    expect(link.verificationToken, isNull);
    expect(browser.replaced, isEmpty);
  });

  test('GivenNothingToTake_WhenTheAppStarts_ThenTheAddressIsUntouched', () {
    // Given
    final browser = _FakeBrowser('https://ui.example.com/scopes');

    // When
    takeEntryLink(browser);

    // Then
    expect(browser.replaced, isEmpty);
    expect(browser.session, isEmpty);
  });

  // Builds before per-tab sessions kept the token in local storage, beside
  // the raw key it was encrypted with. Both go, or the old token lingers
  // until it expires.
  test(
    'GivenAnyStart_WhenTheAppStarts_ThenTheLegacyTokenAndKeyAreForgotten',
    () {
      // Given
      final browser = _FakeBrowser('https://ui.example.com/');

      // When
      takeEntryLink(browser);

      // Then
      expect(
        browser.forgotten,
        unorderedEquals(<String>[
          'FlutterSecureStorage.heimdall.session.token',
          'FlutterSecureStorage',
        ]),
      );
    },
  );

  // Off the web there is no address bar and no local storage to tidy.
  test('GivenTheHostPlatform_WhenTheAppStarts_ThenNothingIsTaken', () {
    // Given / When
    final link = takePlatformEntryLink();

    // Then
    expect(link.resetToken, isNull);
    expect(link.verificationToken, isNull);
  });
}
