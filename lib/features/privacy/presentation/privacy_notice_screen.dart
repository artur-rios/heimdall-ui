import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/layout/breakpoints.dart';
import '../domain/privacy_notice.dart';

/// The public privacy notice, at `/privacy` — the page Google's consent screen
/// links to as the application's privacy policy.
///
/// It shows the Heimdall API's own notice, bundled verbatim, so there is one
/// text and the version on screen is the version in force.
class PrivacyNoticeScreen extends StatefulWidget {
  const PrivacyNoticeScreen({this.openLink = launchUrl, super.key});

  /// The widest the text runs, so lines stay readable on a wide window.
  static const double maxContentWidth = 760;

  /// Opens a link from the notice — the browser, or the mail client for the
  /// contact address.
  final Future<bool> Function(Uri uri) openLink;

  @override
  State<PrivacyNoticeScreen> createState() => _PrivacyNoticeScreenState();
}

class _PrivacyNoticeScreenState extends State<PrivacyNoticeScreen> {
  Future<String>? _notice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notice ??= DefaultAssetBundle.of(context)
        .loadString(privacyNoticeAsset)
        .then(privacyNoticeBody);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = context.breakpoint == Breakpoint.compact;
    final padding = compact ? 16.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        // Opened from Google's consent screen, this is the first page, and a
        // back button with nowhere to go would be a dead end — so it opens the
        // application instead.
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Privacy notice'),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _notice,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Text(
                    'The privacy notice could not be loaded.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final notice = snapshot.data;

            if (notice == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: PrivacyNoticeScreen.maxContentWidth,
                  ),
                  child: MarkdownBody(
                    data: notice,
                    selectable: true,
                    styleSheet: _styleSheet(theme, compact: compact),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        widget.openLink(resolvePrivacyNoticeLink(href));
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The renderer's defaults, adjusted to the notice and to both themes.
  MarkdownStyleSheet _styleSheet(ThemeData theme, {required bool compact}) {
    final scheme = theme.colorScheme;

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      // The default is a fixed blue, whatever the theme.
      a: TextStyle(color: scheme.primary),
      // Room above each numbered section, which otherwise sits on the last
      // line of the one before.
      h2Padding: const EdgeInsets.only(top: 16),
      // The notice's tables have empty header rows (`| | |`). Ruling only
      // between rows turns that row into a rule above the table rather than an
      // empty box.
      tableBorder: TableBorder(
        horizontalInside: BorderSide(color: scheme.outlineVariant),
        bottom: BorderSide(color: scheme.outlineVariant),
      ),
      // Three columns share a phone's width; the default 16 a side leaves the
      // middle one a few words a line.
      tableCellsPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
