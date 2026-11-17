/// Rewrites a generated client so that every path parameter is sent as one
/// percent-encoded segment.
///
/// swagger_parser emits each client as a library of two files: the declaration
/// (`*_client.dart`) and the part retrofit builds beside it
/// (`*_client.g.dart`). Both build request paths from the raw parameter, so an
/// id holding `/`, `?` or `#` would change the endpoint a call reaches: Dio's
/// URI then resolves `..` against the rest. Two shapes are rewritten:
///
/// - retrofit's path literal: each `${name}` inside an `/api` literal becomes
///   `${_pathSegment(name)}`;
/// - the declaration's direct Dio fallback (`_xWithOptions`, which a call
///   passing `options` takes): each `name.toString()` in the path expression
///   handed to `_transport.request` becomes `_pathSegment(name)`.
///
/// The methods swagger_parser writes directly against Dio (an optional request
/// body, say) already encode their parameters with `Uri.encodeComponent` and
/// refuse `.`, `..` and the empty segment, so nothing in them changes.
///
/// Running the step twice changes nothing.
String encodePathParameters(String source) {
  final (output, wrapped) = _encode(source);

  return wrapped ? _withHelper(output) : output;
}

/// [encodePathParameters] for one client library: its [declaration] and its
/// retrofit [part], which share one library scope, so the helper is added once,
/// to the part.
({String declaration, String part}) encodeClientLibrary({
  required String declaration,
  required String part,
}) {
  final (encodedDeclaration, declarationWrapped) = _encode(declaration);
  final (encodedPart, partWrapped) = _encode(part);

  return (
    declaration: encodedDeclaration,
    part: declarationWrapped || partWrapped
        ? _withHelper(encodedPart)
        : encodedPart,
  );
}

(String, bool) _encode(String source) {
  var wrapped = false;

  final literals = source.replaceAllMapped(_pathLiteral, (literal) {
    final path = literal.group(1)!.replaceAllMapped(_rawParameter, (match) {
      wrapped = true;

      return '\${_pathSegment(${match.group(1)})}';
    });

    return "'$path'";
  });

  final output = literals.replaceAllMapped(_fallbackPath, (call) {
    final path = call.group(2)!.replaceAllMapped(_stringifiedParameter, (
      match,
    ) {
      wrapped = true;

      return '_pathSegment(${match.group(1)})';
    });

    return '${call.group(1)}$path';
  });

  return (output, wrapped);
}

String _withHelper(String source) =>
    source.contains(_helperSignature) ? source : '$source\n$_helper';

final RegExp _pathLiteral = RegExp(r"'(/api[^']*)'");

final RegExp _rawParameter = RegExp(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}');

/// The path argument of a direct Dio call: everything from the opening `"/api`
/// to the comma that ends the argument. A path expression holds no comma.
final RegExp _fallbackPath = RegExp(
  r'(_transport\.request<[^>]*>\(\s*)("/api[^,]*)',
);

final RegExp _stringifiedParameter = RegExp(
  r'\b([A-Za-z_][A-Za-z0-9_]*)\.toString\(\)',
);

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
