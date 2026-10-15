/// Rewrites a generated client so that every path parameter is sent as one
/// percent-encoded segment.
///
/// retrofit interpolates a `@Path` parameter into the path as it is, so an id
/// holding `/`, `?` or `#` would change the endpoint a call reaches: Dio's URI
/// then resolves `..` against the rest. Each `${name}` inside an `/api` path
/// literal becomes `${_pathSegment(name)}`, and the helper is added once to
/// the file. Running the step twice changes nothing.
String encodePathParameters(String source) {
  var wrapped = false;

  final output = source.replaceAllMapped(_pathLiteral, (literal) {
    final path = literal.group(1)!.replaceAllMapped(_rawParameter, (match) {
      wrapped = true;

      return '\${_pathSegment(${match.group(1)})}';
    });

    return "'$path'";
  });

  if (!wrapped || output.contains(_helperSignature)) {
    return output;
  }

  return '$output\n$_helper';
}

final RegExp _pathLiteral = RegExp(r"'(/api[^']*)'");

final RegExp _rawParameter = RegExp(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}');

const String _helperSignature = 'String _pathSegment(String value)';

const String _helper =
    '''
/// A path parameter as one percent-encoded segment.
///
/// Added by tool/generate_api_client.dart. `.`, `..` and the empty string
/// cannot be one segment of a URI at all, since the URI would drop or climb a
/// segment, so they are refused before anything is sent.
$_helperSignature {
  if (value.isEmpty || value == '.' || value == '..') {
    throw ArgumentError.value(value, 'value', 'is not a path segment');
  }

  return Uri.encodeComponent(value);
}
''';
