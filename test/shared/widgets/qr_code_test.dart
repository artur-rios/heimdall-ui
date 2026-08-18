import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';
import 'package:heimdall_ui/shared/widgets/qr_code.dart';

/// An `otpauth://` URI of the shape the API returns.
const _uri =
    'otpauth://totp/Heimdall:ada@example.com?secret=JBSWY3DPEHPK3PXP'
    '&issuer=Heimdall';

void main() {
  Future<void> pump(
    WidgetTester tester,
    String data, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? buildLightTheme(),
        home: Scaffold(
          body: Center(child: QrCodeView(data: data)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('GivenAnOtpAuthUri_WhenAsked_ThenItCanBeRendered', () {
    // Given / When
    final renderable = QrCodeView.canRender(_uri);

    // Then
    expect(renderable, isTrue);
  });

  // AF-09e — the caller needs an answer rather than an exception, so it can
  // fall back to the secret instead of breaking the setup.
  test('GivenEmptyData_WhenAsked_ThenItCannotBeRendered', () {
    // Given / When
    final renderable = QrCodeView.canRender('');

    // Then
    expect(renderable, isFalse);
  });

  test('GivenDataTooLongForASymbol_WhenAsked_ThenItCannotBeRendered', () {
    // Given
    final huge = 'x' * 10000;

    // When
    final renderable = QrCodeView.canRender(huge);

    // Then
    expect(renderable, isFalse);
  });

  testWidgets('GivenAnOtpAuthUri_WhenRendered_ThenItOccupiesItsSize', (
    tester,
  ) async {
    // Given / When
    await pump(tester, _uri);

    // Then
    expect(tester.getSize(find.byType(QrCodeView)), const Size(200, 200));
  });

  // Nothing drawn and nothing thrown: the caller shows the secret instead, and
  // the layout does not keep a hole where a code would have been.
  testWidgets('GivenUnencodableData_WhenRendered_ThenItTakesNoSpace', (
    tester,
  ) async {
    // Given / When
    await pump(tester, '');

    // Then
    expect(tester.getSize(find.byType(QrCodeView)), Size.zero);
  });

  // The modules are painted in plain black on white whatever the theme: a
  // scanner reads contrast, not the colour scheme.
  testWidgets('GivenTheDarkTheme_WhenRendered_ThenItStillPaints', (
    tester,
  ) async {
    // Given / When
    await pump(tester, _uri, theme: buildDarkTheme());

    // Then
    expect(tester.getSize(find.byType(QrCodeView)), const Size(200, 200));
  });
}
