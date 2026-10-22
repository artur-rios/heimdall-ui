import 'package:flutter/material.dart';

class TileIcon extends StatelessWidget {
  const TileIcon({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: foreground ?? scheme.onPrimaryContainer),
    );
  }
}
