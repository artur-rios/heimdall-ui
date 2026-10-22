import 'package:flutter/material.dart';

/// One search box of [ListFilters]: the field's label and icon, and the
/// controller the screen keeps so the box can show the filter a listing still
/// has between visits.
class ListSearchField {
  const ListSearchField({
    required this.controller,
    required this.label,
    this.icon = Icons.search,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
}

/// The search boxes and the include-deleted switch every filterable listing
/// opens with.
///
/// A single box searches by its arrow button or Enter. Several boxes — the API
/// filters people by name and by email separately, and collapsing them would
/// mean guessing which one the user meant — share one Search button instead.
///
/// The switch is a [SwitchListTile], so its label is part of the tap target and
/// the switch is announced as "Include deleted" rather than as an unnamed
/// switch followed by a separate text stop (#161).
class ListFilters extends StatelessWidget {
  const ListFilters({
    required this.fields,
    required this.includeDeleted,
    required this.onSearch,
    required this.onIncludeDeletedChanged,
    super.key,
  }) : assert(fields.length > 0, 'a listing needs a search field');

  final List<ListSearchField> fields;
  final bool includeDeleted;
  final VoidCallback onSearch;
  final ValueChanged<bool> onIncludeDeletedChanged;

  @override
  Widget build(BuildContext context) {
    final single = fields.length == 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final field in fields)
            SizedBox(
              width: single ? 320 : 260,
              child: TextField(
                controller: field.controller,
                decoration: InputDecoration(
                  labelText: field.label,
                  prefixIcon: Icon(field.icon),
                  suffixIcon: single
                      ? IconButton(
                          tooltip: 'Search',
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: onSearch,
                        )
                      : null,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
          if (!single)
            FilledButton.tonal(
              onPressed: onSearch,
              child: const Text('Search'),
            ),
          SizedBox(
            width: 220,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include deleted'),
              value: includeDeleted,
              onChanged: onIncludeDeletedChanged,
            ),
          ),
        ],
      ),
    );
  }
}
