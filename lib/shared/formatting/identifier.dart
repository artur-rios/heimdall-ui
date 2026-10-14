final RegExp _identifier = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Whether [value], once trimmed, is an identifier (a UUID) the API addresses
/// records by.
bool isIdentifier(String value) => _identifier.hasMatch(value.trim());

/// [value] trimmed and lowercased — the form the API returns identifiers in.
String normaliseIdentifier(String value) => value.trim().toLowerCase();
