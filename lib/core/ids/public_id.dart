/// Whether [value] is a `PublicId`: a GUID in its 8-4-4-4-12 hexadecimal form.
///
/// Every record the API names is addressed by one, so anything else in an id's
/// place is a link to nothing. Checking it before it is used keeps a decoded
/// path such as `../../persons/<id>` from ever becoming part of a request.
bool isPublicId(String value) => _publicId.hasMatch(value);

final RegExp _publicId = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
