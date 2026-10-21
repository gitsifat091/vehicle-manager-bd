/// Layout sizes that are not part of the Lal Sabuj tokens (spacing and radii
/// are `Space` and `Radii`).
abstract final class Layout {
  /// Below this width the app uses the phone layout with a bottom bar. From
  /// this width up it uses a navigation rail and a side panel.
  static const double phoneBreakpoint = 600;

  /// Widest a single-column form or card list grows on a big window.
  static const double formMaxWidth = 480;
}
