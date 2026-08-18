import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';

/// One column of a collection, and how to read it off an item.
///
/// FR-UX-04: a listing declares its columns once, and the same declaration
/// produces the cards a compact window shows and the table a wider one does.
class CollectionColumn<T> {
  const CollectionColumn({
    required this.label,
    required this.cell,
    this.onCard = true,
  });

  final String label;

  /// What this column shows for [item]. A widget rather than a string so a
  /// column can be a chip or an icon where that reads better.
  final Widget Function(T item) cell;

  /// Whether the column also appears on the card. A card with every column is
  /// a table in disguise, so a listing may keep some columns to the table.
  final bool onCard;
}

/// Renders a collection as cards on a compact window and as a table otherwise.
///
/// Paging is the API's, so this takes the page it was handed and reports which
/// page was asked for next; it never slices the list itself.
class AdaptiveCollection<T> extends StatelessWidget {
  const AdaptiveCollection({
    required this.items,
    required this.columns,
    required this.title,
    required this.pageNumber,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
    this.subtitle,
    this.onTap,
    this.busy = false,
    this.reservesFloatingAction = false,
    super.key,
  });

  final List<T> items;
  final List<CollectionColumn<T>> columns;

  /// The item's headline, which is the card's title and the table's first cell.
  final String Function(T item) title;
  final String Function(T item)? subtitle;
  final void Function(T item)? onTap;

  final int pageNumber;
  final int totalPages;
  final int totalItems;
  final ValueChanged<int> onPageChanged;

  /// Disables the paging controls while a page is in flight, so a fast tap
  /// cannot queue two requests.
  final bool busy;

  /// Whether the screen hosting this collection shows a floating action
  /// button. Both sit in the bottom-right corner, and the button is drawn over
  /// the pager — which would leave the next-page control unreachable.
  final bool reservesFloatingAction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Expanded(
        child: context.breakpoint == Breakpoint.compact
            ? _cards(context)
            : _table(context),
      ),
      Padding(
        padding: EdgeInsets.only(bottom: reservesFloatingAction ? 72 : 0),
        child: _Pager(
          pageNumber: pageNumber,
          totalPages: totalPages,
          totalItems: totalItems,
          onPageChanged: busy ? null : onPageChanged,
        ),
      ),
    ],
  );

  Widget _cards(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index];
      final onCard = columns.where((column) => column.onCard);

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap == null ? null : () => onTap!(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title(item),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle case final String Function(T) read) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    read(item),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                for (final column in onCard) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Text(
                        '${column.label}: ',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Flexible(child: column.cell(item)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _table(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columns: <DataColumn>[
          const DataColumn(label: Text('Name')),
          for (final column in columns) DataColumn(label: Text(column.label)),
        ],
        rows: <DataRow>[
          for (final item in items)
            DataRow(
              onSelectChanged: onTap == null ? null : (_) => onTap!(item),
              cells: <DataCell>[
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(title(item)),
                      if (subtitle case final String Function(T) read)
                        Text(
                          read(item),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                for (final column in columns) DataCell(column.cell(item)),
              ],
            ),
        ],
      ),
    ),
  );
}

/// The page controls, which say where the user is as well as moving them.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.pageNumber,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
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
