/// The three window classes the shell lays out for, from narrow to wide.
enum WindowClass {
  /// Phones: the page fills the screen, with a bottom bar.
  compact,

  /// Small tablets and narrow windows: a rail, and the page fills the area
  /// beside it.
  medium,

  /// Big tablets and desktop: a rail, the map, and the page in a side panel.
  expanded,
}

/// Layout sizes that are not part of the Lal Sabuj tokens (spacing and radii
/// are `Space` and `Radii`).
abstract final class Layout {
  /// From this width up the window is [WindowClass.medium].
  static const double mediumBreakpoint = 600;

  /// From this width up the window is [WindowClass.expanded]. Below it the
  /// map and a side panel would not both fit.
  static const double expandedBreakpoint = 840;

  /// Widest a single-column form or card list grows on a big window.
  static const double formMaxWidth = 480;

  /// The side panel next to the map never gets narrower than this, so a
  /// vehicle card still fits.
  static const double sidePanelMinWidth = 320;

  /// The side panel stops growing here; the map takes the rest.
  static const double sidePanelMaxWidth = 400;

  /// The map beside the side panel never gets narrower than this.
  static const double mapMinWidth = 360;

  /// Width of the line between the rail, the map and the panel.
  static const double dividerWidth = 1;

  /// The window class for a window this wide.
  static WindowClass windowClassOf(double width) {
    if (width < mediumBreakpoint) return WindowClass.compact;
    if (width < expandedBreakpoint) return WindowClass.medium;
    return WindowClass.expanded;
  }

  /// True when [areaWidth] (the window without the rail) holds the map at
  /// [mapMinWidth], a divider and the side panel at [sidePanelMinWidth].
  ///
  /// Usually true from the expanded breakpoint up, but a wide rail (long
  /// labels, large text) can leave less. Then the expanded layout shows the
  /// medium content instead of shrinking the map or the panel.
  static bool mapAndPanelFit(double areaWidth) =>
      areaWidth >= mapMinWidth + dividerWidth + sidePanelMinWidth;

  /// Width of the side panel when the map, a divider and the panel share
  /// [areaWidth]: half of what the divider leaves, but no more than leaves
  /// the map [mapMinWidth], and at most [sidePanelMaxWidth]. Only for an
  /// area where [mapAndPanelFit], so it is never below [sidePanelMinWidth].
  static double sidePanelWidth(double areaWidth) {
    assert(mapAndPanelFit(areaWidth), 'no room for the map and the panel');
    final shared = areaWidth - dividerWidth;
    final half = shared / 2;
    final leavingMapRoom = shared - mapMinWidth;
    final width = half < leavingMapRoom ? half : leavingMapRoom;
    return width < sidePanelMaxWidth ? width : sidePanelMaxWidth;
  }
}
