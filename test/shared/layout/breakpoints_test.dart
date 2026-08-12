import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/layout/breakpoints.dart';

void main() {
  test('GivenNarrowWidth_WhenClassified_ThenBreakpointIsCompact', () {
    // Given / When / Then
    expect(breakpointFor(320), Breakpoint.compact);
    expect(breakpointFor(599), Breakpoint.compact);
  });

  test('GivenMediumWidth_WhenClassified_ThenBreakpointIsMedium', () {
    // Given / When / Then
    expect(breakpointFor(600), Breakpoint.medium);
    expect(breakpointFor(1024), Breakpoint.medium);
  });

  test('GivenWideWidth_WhenClassified_ThenBreakpointIsExpanded', () {
    // Given / When / Then
    expect(breakpointFor(1025), Breakpoint.expanded);
    expect(breakpointFor(1920), Breakpoint.expanded);
  });
}
