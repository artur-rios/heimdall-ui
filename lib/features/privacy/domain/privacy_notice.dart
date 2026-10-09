/// Where the bundled privacy notice lives.
///
/// It is a verbatim copy of the Heimdall API's
/// `docs/requirements/Privacy Notice.md`, refreshed with
/// `dart run tool/refresh_privacy_notice.dart`. The API owns the text; this
/// application only shows it.
const String privacyNoticeAsset = 'assets/privacy/privacy_notice.md';

/// The directory the notice is published from, which its links to sibling
/// documents are relative to.
final Uri _noticeDirectory = Uri.parse(
  'https://github.com/artur-rios/heimdall-api/blob/main/docs/requirements/',
);

final RegExp _frontMatter = RegExp(r'^---\r?\n[\s\S]*?\r?\n---\r?\n(\r?\n)*');

/// [source] without the Hugo front matter the API's docs site reads.
///
/// Stripped here rather than in the copy, so the asset stays byte for byte the
/// API's file and a refresh can never quietly drift from it.
String privacyNoticeBody(String source) =>
    source.replaceFirst(_frontMatter, '');

/// The address a link in the notice points at.
///
/// The notice links to the documents beside it in the API repository with
/// relative paths, which mean nothing inside this application, so they are
/// resolved against the directory it is published from. Absolute and `mailto:`
/// links are already complete and pass through unchanged.
Uri resolvePrivacyNoticeLink(String href) => _noticeDirectory.resolve(href);
