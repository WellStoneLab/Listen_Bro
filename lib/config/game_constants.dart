/// Game timing and intimacy constants.
class GameConstants {
  GameConstants._();

  static const int openHour = 18;
  static const int closeHour = 2; // next calendar day
  static const int defaultTickMinutes = 30;
  static const int maxGuests = 3;
  static const int maxIntimacyLevel = 5;
  static const int maxIntimacyGauge = 3;

  /// Stack resume chance when intimacy level >= this.
  static const int stackResumeMinLevel = 4;

  /// Match score lower bounds by intimacy level (inclusive).
  static const List<double> matchToleranceByLevel = [
    0.55,
    0.50,
    0.45,
    0.40,
    0.35,
    0.30,
  ];

  static const List<String> bases = [
    'Gin',
    'Rum',
    'Shoju',
    'Tequila',
    'Vodka',
    'Whisky',
    'R.Wine',
    'W.Wine',
  ];

  static const List<String> mixLiquors = [
    'Beer',
    'Gin',
    'Rum',
    'Sake',
    'Shoju',
    'Tequila',
    'Vodka',
    'Whisky',
    'Citras Liqour',
    'chocolate Liquor',
    'Coffee Liquor',
    'Water',
    'Soda',
    'Ginger Ale',
    'Fresh Juice',
    'Vermouth',
  ];

  static const List<String> afterShakes = [
    'ice',
    'water',
    'soda',
    'Lemon',
    'Orange',
    'Olive',
    'Mint',
    'Cream',
    'Fire',
    'Lime',
    'Salt',
    'Pineapple',
  ];
}
