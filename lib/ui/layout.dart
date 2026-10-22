/// Layout sizes that are not part of the Lal Sabuj tokens (spacing and radii
/// are `Space` and `Radii`).
abstract final class Layout {
  /// Below this width the app uses the phone layout with a bottom bar. From
  /// this width up it uses a navigation rail and a side panel.
  static const double phoneBreakpoint = 600;

  /// Widest a single-column form or card list grows on a big window.
  static const double formMaxWidth = 480;

  /// The side panel next to the map never gets narrower than this, so a
  /// vehicle card still fits on a small tablet.
  static const double sidePanelMinWidth = 320;

  /// The side panel stops growing here; the map takes the rest.
  static const double sidePanelMaxWidth = 400;

  /// True when a window this wide uses the phone layout.
  static bool isPhone(double width) => width < phoneBreakpoint;

  /// Width of the side panel when the map and the panel share [areaWidth]
  /// (the window without the rail): half of it, within the min and max.
  static double sidePanelWidth(double areaWidth) =>
      (areaWidth / 2).clamp(sidePanelMinWidth, sidePanelMaxWidth);
}
