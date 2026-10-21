import 'package:flutter/material.dart';

/// The page controls, which say where the user is as well as moving them.
///
/// Shared by `AdaptiveCollection` and by the sections of a screen that page a
/// list of their own, such as the owners screen.
class CollectionPager extends StatelessWidget {
  const CollectionPager({
    required this.pageNumber,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
    super.key,
  });

  final int pageNumber;
  final int totalPages;
  final int totalItems;

  /// `null` while a page is in flight, which disables both controls.
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final change = onPageChanged;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // A Wrap rather than a Row: on a narrow window the counts and the
      // controls do not fit on one line, and an overflowing pager hides the
      // control that moves the user off the page.
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        children: <Widget>[
          Text('$totalItems in total'),
          Text('Page $pageNumber of $totalPages'),
          IconButton(
            tooltip: 'Previous page',
            icon: const Icon(Icons.chevron_left),
            onPressed: (change == null || pageNumber <= 1)
                ? null
                : () => change(pageNumber - 1),
          ),
          IconButton(
            tooltip: 'Next page',
            icon: const Icon(Icons.chevron_right),
            onPressed: (change == null || pageNumber >= totalPages)
                ? null
                : () => change(pageNumber + 1),
          ),
        ],
      ),
    );
  }
}
