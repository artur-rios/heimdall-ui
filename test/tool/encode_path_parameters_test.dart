import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/encode_path_parameters.dart';

void main() {
  const generated = r"""
class _ScopeClient implements ScopeClient {
  Future<void> one({required String id}) async {
    final _options = Options().compose(
      _dio.options,
      '/api/scopes/${id}/owners/${personId}',
    );
  }

  Future<void> two() async {
    final _options = Options().compose(_dio.options, '/api/scopes');
  }
}

// dart format on
""";

  test('GivenAGeneratedPath_WhenEncoded_ThenEachParameterIsWrapped', () {
    // Given / When
    final output = encodePathParameters(generated);

    // Then
    expect(
      output,
      contains(
        r"'/api/scopes/${_pathSegment(id)}/owners/${_pathSegment(personId)}'",
      ),
    );
    expect(output, contains("'/api/scopes'"));
    expect(output, contains('String _pathSegment(String value)'));
  });

  // The generator runs from a clean tree, but running the step twice must not
  // wrap a parameter twice or add a second helper.
  test('GivenAnEncodedSource_WhenEncodedAgain_ThenItIsUnchanged', () {
    // Given
    final once = encodePathParameters(generated);

    // When
    final twice = encodePathParameters(once);

    // Then
    expect(twice, once);
  });

  test('GivenNoPathParameters_WhenEncoded_ThenTheSourceIsUnchanged', () {
    // Given
    const source = r"""
final _options = Options().compose(_dio.options, '/api/health');
""";

    // When
    final output = encodePathParameters(source);

    // Then
    expect(output, source);
  });

  // swagger_parser's direct Dio fallback, which a call passing `options`
  // takes, builds the path by concatenation.
  const declaration = r'''
abstract class ScopeClient {
  Future<void> _oneWithOptions({required String id}) async {
    final response = await _transport.request<dynamic>(
      "/api/scopes/" + id.toString() + "/owners/" + personId.toString(),
      options: _options,
      queryParameters: <String, Object?>{if (q != null) "Q": q.toString()},
    );
  }

  Future<void> _twoWithOptions() async {
    final response = await _transport.request<dynamic>(
      "/api/scopes",
      options: _options,
    );
  }
}
''';

  test('GivenAFallbackPath_WhenEncoded_ThenEachParameterIsWrapped', () {
    // Given / When
    final output = encodePathParameters(declaration);

    // Then
    expect(
      output,
      contains(
        '"/api/scopes/" + _pathSegment(id) + "/owners/" + '
        '_pathSegment(personId),',
      ),
    );
    expect(output, contains('"/api/scopes",'));
    // A query value is not a path segment.
    expect(output, contains('"Q": q.toString()'));
  });

  test('GivenAClientLibrary_WhenEncoded_ThenThePartAloneGetsTheHelper', () {
    // Given / When
    final output = encodeClientLibrary(
      declaration: declaration,
      part: generated,
    );

    // Then
    expect(output.declaration, contains('_pathSegment(personId)'));
    expect(output.declaration, isNot(contains(_helper)));
    expect(output.part, contains(r'${_pathSegment(personId)}'));
    expect(_helper.allMatches(output.part), hasLength(1));
  });

  // The declaration's paths alone still need the helper, and it can only go in
  // the part: the two files are one library.
  test(
    'GivenOnlyTheDeclarationHasParameters_WhenEncoded_ThenThePartGetsIt',
    () {
      // Given
      const part = r"""
final _options = Options().compose(_dio.options, '/api/scopes');
""";

      // When
      final output = encodeClientLibrary(declaration: declaration, part: part);

      // Then
      expect(output.part, contains(_helper));
    },
  );

  test('GivenAnEncodedClientLibrary_WhenEncodedAgain_ThenItIsUnchanged', () {
    // Given
    final once = encodeClientLibrary(declaration: declaration, part: generated);

    // When
    final twice = encodeClientLibrary(
      declaration: once.declaration,
      part: once.part,
    );

    // Then
    expect(twice.declaration, once.declaration);
    expect(twice.part, once.part);
  });

  // swagger_parser's own direct methods encode their parameters already.
  test('GivenADirectMethodPath_WhenEncoded_ThenItIsUnchanged', () {
    // Given
    const source = r"""
    final response = await _transport.request<dynamic>(
      "/api/scopes/" + Uri.encodeComponent(scopeId) + "/credentials",
      options: _options,
    );
""";

    // When
    final output = encodePathParameters(source);

    // Then
    expect(output, source);
  });
}

const String _helper = 'String _pathSegment(String value)';
