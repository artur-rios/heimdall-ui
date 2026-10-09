import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/privacy/domain/privacy_notice.dart';

void main() {
  test('GivenHugoFrontMatter_WhenTheBodyIsTaken_ThenTheFrontMatterIsGone', () {
    // Given
    const source =
        '---\n'
        'title: "Privacy Notice"\n'
        'weight: 47\n'
        '---\n'
        '\n'
        '# Privacy Notice — Heimdall API\n';

    // When
    final body = privacyNoticeBody(source);

    // Then
    expect(body, '# Privacy Notice — Heimdall API\n');
  });

  test('GivenNoFrontMatter_WhenTheBodyIsTaken_ThenItIsUnchanged', () {
    // Given
    const source = '# Privacy Notice\n\n---\n\nA rule, not front matter.\n';

    // When
    final body = privacyNoticeBody(source);

    // Then
    expect(body, source);
  });

  test(
    'GivenWindowsLineEndings_WhenTheBodyIsTaken_ThenTheFrontMatterIsGone',
    () {
      // Given
      const source =
          '---\r\ntitle: "Privacy Notice"\r\n---\r\n\r\n# Notice\r\n';

      // When
      final body = privacyNoticeBody(source);

      // Then
      expect(body, '# Notice\r\n');
    },
  );

  test(
    'GivenASiblingDocumentLink_WhenResolved_ThenItPointsAtTheApiRepository',
    () {
      // Given
      const href = 'Data%20Protection%20Document.md';

      // When
      final uri = resolvePrivacyNoticeLink(href);

      // Then
      expect(
        uri.toString(),
        'https://github.com/artur-rios/heimdall-api/blob/main/docs/requirements/'
        'Data%20Protection%20Document.md',
      );
    },
  );

  test('GivenAnAbsoluteLink_WhenResolved_ThenItIsUnchanged', () {
    // Given
    const href = 'https://www.gov.br/anpd/';

    // When
    final uri = resolvePrivacyNoticeLink(href);

    // Then
    expect(uri.toString(), href);
  });

  test('GivenAMailtoLink_WhenResolved_ThenItIsUnchanged', () {
    // Given
    const href = 'mailto:arturdev@duck.com';

    // When
    final uri = resolvePrivacyNoticeLink(href);

    // Then
    expect(uri.toString(), href);
  });
}
