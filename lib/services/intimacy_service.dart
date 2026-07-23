import '../config/game_constants.dart';
import '../models/game_models.dart';

class IntimacyService {
  /// Apply gauge delta then run level up/down rules. Returns log message if any.
  String? applyGauge(CustomerProgress p, int delta) {
    if (delta == 0) return null;
    p.intimacyGauge += delta;

    if (p.intimacyLevel >= GameConstants.maxIntimacyLevel &&
        p.intimacyGauge >= GameConstants.maxIntimacyGauge) {
      p.intimacyGauge = GameConstants.maxIntimacyGauge;
      return '親密度が最大値に達しました。マスターはもう心友です！';
    }

    while (p.intimacyGauge >= GameConstants.maxIntimacyGauge &&
        p.intimacyLevel < GameConstants.maxIntimacyLevel) {
      p.intimacyLevel += 1;
      p.intimacyGauge = 0;
      if (p.intimacyLevel >= GameConstants.maxIntimacyLevel) {
        p.intimacyGauge = 0;
        break;
      }
    }

    while (p.intimacyGauge < 0) {
      if (p.intimacyLevel <= 0) {
        p.intimacyLevel = 0;
        p.intimacyGauge = 0;
        break;
      }
      p.intimacyLevel -= 1;
      p.intimacyGauge = 2;
    }

    if (p.intimacyLevel >= GameConstants.maxIntimacyLevel &&
        p.intimacyGauge >= GameConstants.maxIntimacyGauge) {
      p.intimacyGauge = GameConstants.maxIntimacyGauge;
      return '親密度が最大値に達しました。マスターはもう心友です！';
    }
    return null;
  }
}
