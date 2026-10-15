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
}
