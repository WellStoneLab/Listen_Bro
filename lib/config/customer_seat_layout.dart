/// Fixed customer seat layout on [barBackgroundAsset] (reference 1152×1024).
///
/// Three seats only — left / center / right. Do not change anchors without
/// updating `.cursor/rules/customer-seat-placement.mdc` and seat previews.
class CustomerSeatLayout {
  CustomerSeatLayout._();

  static const String barBackgroundAsset = 'assets/images/bar_bg_main.png';

  /// Cropped seated sprite height ÷ background height (all seats).
  static const double spriteHeightFrac = 0.3594;

  /// Sprite top ÷ background height (all seats).
  static const double topYFrac = 0.3135;

  /// Sprite center X ÷ background width — **fixed**.
  static const double leftAnchorXFrac = 0.18;
  static const double centerAnchorXFrac = 0.50;
  static const double rightAnchorXFrac = 0.82;

  /// All seat ids in left-to-right order.
  static const List<CustomerSeatId> seats = CustomerSeatId.values;

  static double anchorXFrac(CustomerSeatId seat) => switch (seat) {
        CustomerSeatId.left => leftAnchorXFrac,
        CustomerSeatId.center => centerAnchorXFrac,
        CustomerSeatId.right => rightAnchorXFrac,
      };

  /// Left (px) of the sprite for [seat].
  static double left(CustomerSeatId seat, double bgWidth, double spriteWidth) =>
      bgWidth * anchorXFrac(seat) - spriteWidth / 2;

  /// Top (py) of the sprite (same for every seat).
  static double top(double bgHeight) => bgHeight * topYFrac;

  /// Target sprite height for any seat.
  static double spriteHeight(double bgHeight) => bgHeight * spriteHeightFrac;

  // --- Convenience aliases (same as [left]/[top]/[spriteHeight]) ---

  static double leftLeft(double bgWidth, double spriteWidth) =>
      left(CustomerSeatId.left, bgWidth, spriteWidth);

  static double centerLeft(double bgWidth, double spriteWidth) =>
      left(CustomerSeatId.center, bgWidth, spriteWidth);

  static double rightLeft(double bgWidth, double spriteWidth) =>
      left(CustomerSeatId.right, bgWidth, spriteWidth);

  static double leftTop(double bgHeight) => top(bgHeight);
  static double centerTop(double bgHeight) => top(bgHeight);
  static double rightTop(double bgHeight) => top(bgHeight);

  static double centerSpriteHeight(double bgHeight) => spriteHeight(bgHeight);
}

enum CustomerSeatId { left, center, right }
