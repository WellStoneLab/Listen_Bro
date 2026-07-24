import '../config/customer_seat_layout.dart';

class AppSettings {
  const AppSettings({
    this.musicVolume = 0.7,
    this.soundVolume = 0.8,
    this.messageSpeed = 3,
  });

  final double musicVolume;
  final double soundVolume;

  /// 1 slow … 5 fast
  final int messageSpeed;

  AppSettings copyWith({
    double? musicVolume,
    double? soundVolume,
    int? messageSpeed,
  }) {
    return AppSettings(
      musicVolume: musicVolume ?? this.musicVolume,
      soundVolume: soundVolume ?? this.soundVolume,
      messageSpeed: messageSpeed ?? this.messageSpeed,
    );
  }

  Map<String, dynamic> toJson() => {
        'musicVolume': musicVolume,
        'soundVolume': soundVolume,
        'messageSpeed': messageSpeed,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      musicVolume: (json['musicVolume'] as num?)?.toDouble() ?? 0.7,
      soundVolume: (json['soundVolume'] as num?)?.toDouble() ?? 0.8,
      messageSpeed: (json['messageSpeed'] as num?)?.toInt() ?? 3,
    );
  }
}

class DebugOverrides {
  const DebugOverrides({
    this.tickMinutes = 30,
    this.intimacyLevels = const {},
    this.showIntimacyHud = false,
  });

  final int tickMinutes;
  final Map<String, int> intimacyLevels;

  /// キャラクター画像上に親密度レベル／ゲージを表示
  final bool showIntimacyHud;

  DebugOverrides copyWith({
    int? tickMinutes,
    Map<String, int>? intimacyLevels,
    bool? showIntimacyHud,
  }) {
    return DebugOverrides(
      tickMinutes: tickMinutes ?? this.tickMinutes,
      intimacyLevels: intimacyLevels ?? this.intimacyLevels,
      showIntimacyHud: showIntimacyHud ?? this.showIntimacyHud,
    );
  }

  Map<String, dynamic> toJson() => {
        'tickMinutes': tickMinutes,
        'intimacyLevels': intimacyLevels,
        'showIntimacyHud': showIntimacyHud,
      };

  factory DebugOverrides.fromJson(Map<String, dynamic> json) {
    final raw = json['intimacyLevels'] as Map<String, dynamic>? ?? {};
    return DebugOverrides(
      tickMinutes: (json['tickMinutes'] as num?)?.toInt() ?? 30,
      intimacyLevels: raw.map((k, v) => MapEntry(k, (v as num).toInt())),
      showIntimacyHud: json['showIntimacyHud'] as bool? ?? false,
    );
  }
}

class CustomerProgress {
  CustomerProgress({
    required this.customerId,
    this.intimacyLevel = 0,
    this.intimacyGauge = 0,
    this.stackStep = 1,
    this.stackInterrupted = false,
  });

  final String customerId;
  int intimacyLevel;
  int intimacyGauge;
  int stackStep;
  bool stackInterrupted;

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'intimacyLevel': intimacyLevel,
        'intimacyGauge': intimacyGauge,
        'stackStep': stackStep,
        'stackInterrupted': stackInterrupted,
      };

  factory CustomerProgress.fromJson(Map<String, dynamic> json) {
    return CustomerProgress(
      customerId: json['customerId'] as String,
      intimacyLevel: (json['intimacyLevel'] as num?)?.toInt() ?? 0,
      intimacyGauge: (json['intimacyGauge'] as num?)?.toInt() ?? 0,
      stackStep: (json['stackStep'] as num?)?.toInt() ?? 1,
      stackInterrupted: json['stackInterrupted'] as bool? ?? false,
    );
  }
}

class GuestState {
  GuestState({
    required this.customerId,
    required this.seat,
    required this.arrivedMinutes,
    required this.departMinutes,
    this.awaitingOrder = true,
    this.justServed = false,
    this.commandTurns = 0,
  });

  final String customerId;
  final CustomerSeatId seat;
  final int arrivedMinutes;
  final int departMinutes;
  bool awaitingOrder;
  bool justServed;
  int commandTurns;

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'seat': seat.name,
        'arrivedMinutes': arrivedMinutes,
        'departMinutes': departMinutes,
        'awaitingOrder': awaitingOrder,
        'justServed': justServed,
        'commandTurns': commandTurns,
      };

  factory GuestState.fromJson(Map<String, dynamic> json) {
    return GuestState(
      customerId: json['customerId'] as String,
      seat: CustomerSeatId.values.byName(json['seat'] as String),
      arrivedMinutes: (json['arrivedMinutes'] as num).toInt(),
      departMinutes: (json['departMinutes'] as num).toInt(),
      awaitingOrder: json['awaitingOrder'] as bool? ?? false,
      justServed: json['justServed'] as bool? ?? false,
      commandTurns: (json['commandTurns'] as num?)?.toInt() ?? 0,
    );
  }
}

class GameSaveData {
  GameSaveData({
    this.day = 1,
    this.minutesFromMidnight = 18 * 60,
    List<GuestState>? guests,
    Map<String, CustomerProgress>? progress,
    Set<String>? unlockedRecipes,
    List<String>? logs,
    this.blockNextArrival = false,
  })  : guests = guests ?? <GuestState>[],
        progress = progress ?? <String, CustomerProgress>{},
        unlockedRecipes = unlockedRecipes ?? <String>{},
        logs = logs ?? <String>[];

  int day;

  /// Minutes from 00:00. Open 18:00 … close 02:00 (next day = 26:00 in continuous minutes).
  int minutesFromMidnight;
  List<GuestState> guests;
  Map<String, CustomerProgress> progress;
  Set<String> unlockedRecipes;
  List<String> logs;
  bool blockNextArrival;

  Map<String, dynamic> toJson() => {
        'day': day,
        'minutesFromMidnight': minutesFromMidnight,
        'guests': guests.map((g) => g.toJson()).toList(),
        'progress': progress.map((k, v) => MapEntry(k, v.toJson())),
        'unlockedRecipes': unlockedRecipes.toList(),
        'logs': logs,
        'blockNextArrival': blockNextArrival,
      };

  factory GameSaveData.fromJson(Map<String, dynamic> json) {
    final progRaw = json['progress'] as Map<String, dynamic>? ?? {};
    return GameSaveData(
      day: (json['day'] as num?)?.toInt() ?? 1,
      minutesFromMidnight:
          (json['minutesFromMidnight'] as num?)?.toInt() ?? 18 * 60,
      guests: (json['guests'] as List<dynamic>? ?? [])
          .map((e) => GuestState.fromJson(e as Map<String, dynamic>))
          .toList(),
      progress: progRaw.map(
        (k, v) => MapEntry(k, CustomerProgress.fromJson(v as Map<String, dynamic>)),
      ),
      unlockedRecipes:
          (json['unlockedRecipes'] as List<dynamic>? ?? []).map((e) => e as String).toSet(),
      logs: (json['logs'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      blockNextArrival: json['blockNextArrival'] as bool? ?? false,
    );
  }
}
