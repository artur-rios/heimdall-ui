import 'package:flutter/widgets.dart';

/// The three window classes the interface adapts to.
///
/// The boundaries follow Material's own window size classes, so a layout that
/// behaves here behaves the same in any other Material application.
enum Breakpoint { compact, medium, expanded }

Breakpoint breakpointFor(double width) => switch (width) {
  < 600 => Breakpoint.compact,
  <= 1024 => Breakpoint.medium,
  _ => Breakpoint.expanded,
};

extension BreakpointContext on BuildContext {
  Breakpoint get breakpoint => breakpointFor(MediaQuery.sizeOf(this).width);
}
