import 'package:flutter/material.dart';

/// Lays the tiles out in as many columns as the width allows, never letting a
/// tile shrink below [minTileWidth].
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.minTileWidth = 150});

  final List<Widget> children;
  final double minTileWidth;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fit = ((constraints.maxWidth + _gap) / (minTileWidth + _gap))
          .floor();
      final columns = fit.clamp(1, 3);
      final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;

      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: <Widget>[
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
