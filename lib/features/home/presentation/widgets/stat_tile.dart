import 'package:flutter/material.dart';

import 'tile_icon.dart';

/// One figure: what it counts, the number, and a line about it.
///
/// Laid out beside its icon when there is room, and under it on a phone,
/// where two tiles share a row.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.caption,
    this.onTap,
    this.tooltip,
    this.iconBackground,
    this.iconForeground,
    this.valueColor,
  }) : loading = false;

  const StatTile.loading({required this.label, required this.icon, super.key})
    : value = '',
      caption = '',
      onTap = null,
      tooltip = null,
      iconBackground = null,
      iconForeground = null,
      valueColor = null,
      loading = true;

  final String label;
  final IconData icon;
  final String value;
  final String caption;
  final VoidCallback? onTap;

  /// Said on hover, when the figure needs explaining — one that could not be
  /// read, say.
  final String? tooltip;
  final Color? iconBackground;
  final Color? iconForeground;
  final Color? valueColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget figure = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: valueColor,
      ),
    );

    if (tooltip case final message?) {
      figure = Tooltip(message: message, child: figure);
    }

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: LinearProgressIndicator(),
          )
        else
          figure,
        if (caption.isNotEmpty)
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    final iconBox = TileIcon(
      icon: icon,
      background: iconBackground,
      foreground: iconForeground,
    );
    final chevron = onTap == null
        ? null
        : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 200
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[iconBox, const Spacer(), ?chevron],
                      ),
                      const SizedBox(height: 12),
                      text,
                    ],
                  )
                : Row(
                    children: <Widget>[
                      iconBox,
                      const SizedBox(width: 16),
                      Expanded(child: text),
                      ?chevron,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
