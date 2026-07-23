import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/audio_paths.dart';
import '../config/customer_seat_layout.dart';
import '../config/game_constants.dart';
import '../data/master_repository.dart';
import '../data/stores.dart';
import '../models/game_models.dart';
import '../models/master_models.dart';
import 'audio_service.dart';
import 'cocktail_mixer.dart';
import 'intimacy_service.dart';

enum GamePhase {
  idle,
  mixing,
  awaitingCommand,
  awaitingQuestionAnswer,
}

class GameController extends ChangeNotifier {
  GameController({
    required this.repository,
    required this.saveStore,
    required this.settingsStore,
  });

  final MasterDataRepository repository;
  final SaveStore saveStore;
  final SettingsStore settingsStore;
  final AudioService audio = AudioService();
  final CocktailMixer mixer = CocktailMixer();
  final IntimacyService intimacy = IntimacyService();
  final _rng = Random();

  bool loading = true;
  bool hasSave = false;
  AppSettings settings = const AppSettings();
  DebugOverrides debug = const DebugOverrides();
  GameSaveData save = GameSaveData();
  GamePhase phase = GamePhase.idle;
  String? selectedGuestId;
  TalkStackDef? pendingTalkStep;

  Future<void> initialize() async {
    await repository.load();
    settings = await settingsStore.loadSettings();
    debug = await settingsStore.loadDebug();
    hasSave = await saveStore.hasSave();
    await audio.init(settings);
    loading = false;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await settingsStore.saveSettings(settings);
    await audio.applySettings(settings);
    notifyListeners();
  }

  Future<void> updateDebug(DebugOverrides next) async {
    debug = next;
    await settingsStore.saveDebug(debug);
    for (final e in debug.intimacyLevels.entries) {
      final p = _progress(e.key);
      p.intimacyLevel = e.value.clamp(0, GameConstants.maxIntimacyLevel);
    }
    await _autosave();
    notifyListeners();
  }

  Future<void> startNewGame() async {
    save = GameSaveData();
    for (final c in repository.customers) {
      save.progress[c.id] = CustomerProgress(customerId: c.id);
    }
    phase = GamePhase.idle;
    selectedGuestId = null;
    pendingTalkStep = null;
    _appendLog('DAY ${save.day} — バーが開店した。');
    await saveStore.save(save);
    hasSave = true;
    await audio.playBgm(AudioPaths.bgmMain);
    await _tryArriveGuest();
    notifyListeners();
  }

  Future<void> continueGame() async {
    final loaded = await saveStore.load();
    if (loaded == null) return;
    save = loaded;
    for (final c in repository.customers) {
      save.progress.putIfAbsent(c.id, () => CustomerProgress(customerId: c.id));
    }
    phase = save.guests.any((g) => g.awaitingOrder)
        ? GamePhase.idle
        : (save.guests.isEmpty ? GamePhase.idle : GamePhase.awaitingCommand);
    selectedGuestId = save.guests.isEmpty ? null : save.guests.first.customerId;
    if (selectedGuestId != null) {
      _preloadTalk(selectedGuestId!);
    }
    await audio.playBgm(AudioPaths.bgmMain);
    notifyListeners();
  }

  Future<void> returnToTitle() async {
    await audio.stopBgm();
    phase = GamePhase.idle;
    notifyListeners();
  }

  String clockLabel() {
    final m = save.minutesFromMidnight;
    final hour = (m ~/ 60) % 24;
    final min = m % 60;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  CustomerDef? customerOf(String id) => repository.customersById[id];

  GuestState? guestById(String id) {
    for (final g in save.guests) {
      if (g.customerId == id) return g;
    }
    return null;
  }

  GuestState? guestAt(CustomerSeatId seat) {
    for (final g in save.guests) {
      if (g.seat == seat) return g;
    }
    return null;
  }

  void selectGuest(String customerId) {
    if (!save.guests.any((g) => g.customerId == customerId)) return;
    if (selectedGuestId == customerId) return;
    selectedGuestId = customerId;
    _preloadTalk(customerId);
    if (save.guests.length > 1) {
      final name = customerOf(customerId)?.customerName ?? customerId;
      _appendLog('→ $name を選んだ。');
    }
    notifyListeners();
  }

  void openMixer() {
    final g = _selectedGuest();
    if (g == null || !g.awaitingOrder) return;
    phase = GamePhase.mixing;
    notifyListeners();
  }

  void cancelMixer() {
    phase = GamePhase.idle;
    notifyListeners();
  }

  Future<void> serveCocktail(CocktailCraftInput input) async {
    final g = _selectedGuest();
    if (g == null) return;
    final customer = repository.customersById[g.customerId];
    if (customer == null) return;

    final result = mixer.craft(input, repository.cocktails);
    _appendLog('${customer.customerName} に「${result.displayName}」を提供した。');

    if (result.kind == CocktailResultKind.fail) {
      final msg = intimacy.applyGauge(_progress(g.customerId), -1);
      _appendLog('カクテルが爆発した…');
      if (msg != null) _appendLog(msg);
    } else {
      if (result.matched != null) {
        final id = result.matched!.id;
        final learned = save.unlockedRecipes.add(id);
        if (learned) {
          _appendLog('「${result.displayName}」のレシピを覚えた。次回から直接選べる。');
        }
      }
      final preferred = customer.preferredCocktailIds;
      final wantsSpecific = preferred.isNotEmpty;
      final matchesWant = result.matched != null &&
          preferred.contains(result.matched!.id);

      if (wantsSpecific && !matchesWant && result.kind == CocktailResultKind.success) {
        _appendLog('好みの一杯ではなかったようだ。（親密度は変わらない）');
      } else if (wantsSpecific &&
          result.kind == CocktailResultKind.plain) {
        _appendLog('好みの一杯ではなかったようだ。（親密度は変わらない）');
      } else {
        final score = mixer.matchScore(result, customer);
        final tol = mixer.toleranceForLevel(_progress(g.customerId).intimacyLevel);
        final delta = score >= tol ? 1 : -1;
        final msg = intimacy.applyGauge(_progress(g.customerId), delta);
        _appendLog(delta > 0
            ? 'カクテルは気に入ったようだ。（マッチ ${(score * 100).round()}%）'
            : 'カクテルは好みではなかった…（マッチ ${(score * 100).round()}%）');
        if (msg != null) _appendLog(msg);
      }
    }

    g.awaitingOrder = false;
    g.justServed = true;
    phase = GamePhase.awaitingCommand;
    _preloadTalk(g.customerId);
    await _autosave();
    notifyListeners();
  }

  Future<void> commandTalk() async {
    final g = _selectedGuest();
    if (g == null) return;
    final customer = repository.customersById[g.customerId]!;
    final step = pendingTalkStep;
    final prog = _progress(g.customerId);

    // question は「みまもる」「サービス」のみ
    if (step?.talkType == TalkType.question) {
      _appendLog('${customer.customerName} は何か聞きたそうにしている…');
      await _finishCommandTurn(g);
      return;
    }

    if (step?.talkType == TalkType.suffer && _rng.nextDouble() < 0.5) {
      _appendLog('「今はそっとしておいてほしい・・・」');
      intimacy.applyGauge(prog, -1);
      await _finishCommandTurn(g);
      return;
    }

    if (step == null) {
      _appendLog('${customer.customerName} は特に話すことがないようだ。');
      await _finishCommandTurn(g);
      return;
    }

    _appendLog('${customer.customerName}「${step.text}」');
    await _completeTalkStep(g, step);
  }

  Future<void> commandWatch() async {
    final g = _selectedGuest();
    if (g == null) {
      _appendLog('・・・こういう時間も悪くない。・・・ずっとじゃなければね。');
      await _advanceTime();
      return;
    }
    _appendLog('マスターは静かにお客様を見守っている。');
    final step = pendingTalkStep;
    if (step != null && step.talkType == TalkType.question) {
      await _beginQuestion(g, step);
      return;
    }
    if (step != null && step.talkType == TalkType.suffer) {
      final customer = repository.customersById[g.customerId]!;
      _appendLog('${customer.customerName}「${step.text}」');
      await _completeTalkStep(g, step);
      return;
    }
    _appendLog('お客様は静かな時間をお楽しみいただいているようだ。');
    await _finishCommandTurn(g);
  }

  Future<void> commandService() async {
    final g = _selectedGuest();
    if (g == null) return;
    _appendLog('・・・サービスです。');
    final step = pendingTalkStep;
    final prog = _progress(g.customerId);

    if (step?.talkType == TalkType.question) {
      await _beginQuestion(g, step!);
      return;
    }

    if (step?.talkType == TalkType.suffer) {
      final roll = _rng.nextDouble();
      if (roll < 0.5) {
        final customer = repository.customersById[g.customerId]!;
        _appendLog('${customer.customerName}「${step!.text}」');
        await _completeTalkStep(g, step);
        return;
      }
      if (roll < 0.75) {
        _appendLog('お客様が気を悪くしてしまった…');
        intimacy.applyGauge(prog, -1);
        await _finishCommandTurn(g);
        return;
      }
    }

    if (_rng.nextDouble() < 0.25) {
      intimacy.applyGauge(prog, 1);
      _appendLog('どうやら気に入っていただけたようだ・・・');
    } else {
      _appendLog('どうやら気に入っていただけたようだ・・・');
    }
    await _finishCommandTurn(g);
  }

  Future<void> _beginQuestion(GuestState g, TalkStackDef step) async {
    final customer = repository.customersById[g.customerId]!;
    _appendLog('${customer.customerName}「${step.text}」');
    phase = GamePhase.awaitingQuestionAnswer;
    await _autosave();
    notifyListeners();
  }

  Future<void> answerQuestion(String answer) async {
    final g = _selectedGuest();
    final step = pendingTalkStep;
    if (g == null ||
        step == null ||
        step.talkType != TalkType.question ||
        phase != GamePhase.awaitingQuestionAnswer) {
      return;
    }

    _appendLog('マスター「$answer」');
    final prog = _progress(g.customerId);
    final expected = step.expectation;
    if (expected != null && answer == expected) {
      intimacy.applyGauge(prog, 1);
      _appendLog('その答えは気に入ったようだ。（親密度ゲージ+1）');
    } else {
      intimacy.applyGauge(prog, -1);
      _appendLog('その答えはあまり気に入らなかったようだ。（親密度ゲージ-1）');
    }
    await _completeTalkStep(g, step);
  }

  Future<void> commandOrder() async {
    final g = _selectedGuest();
    if (g == null) return;
    _appendLog('・・・ほかに何か飲まれますか？');
    if (g.justServed) {
      _appendLog('「いま頼んだばかりだよ」');
      intimacy.applyGauge(_progress(g.customerId), -1);
      await _finishCommandTurn(g);
      return;
    }
    final chance = (g.commandTurns * 0.25).clamp(0.0, 1.0);
    if (_rng.nextDouble() < chance) {
      _appendLog('おかわりの注文が入った。');
      g.awaitingOrder = true;
      g.justServed = false;
      phase = GamePhase.idle;
      await _autosave();
      notifyListeners();
      return;
    }
    _appendLog('今は飲まないようだ。');
    await _finishCommandTurn(g);
  }

  Future<void> _completeTalkStep(GuestState g, TalkStackDef step) async {
    final prog = _progress(g.customerId);
    if (step.endOfStack) {
      intimacy.applyGauge(prog, 1);
      _appendLog('会話の区切りがついた。（親密度ゲージ+1）');
      prog.stackStep = 1;
      prog.stackInterrupted = false;
    } else {
      prog.stackStep = step.step + 1;
      prog.stackInterrupted = false;
    }
    await _finishCommandTurn(g);
  }

  Future<void> _finishCommandTurn(GuestState g) async {
    g.justServed = false;
    g.commandTurns += 1;
    // Spec: next guest only after drink + one command turn.
    if (!g.awaitingOrder) {
      save.blockNextArrival = false;
    }
    phase = g.awaitingOrder ? GamePhase.idle : GamePhase.awaitingCommand;
    await _advanceTime();
  }

  Future<void> _advanceTime() async {
    final tick = debug.tickMinutes.clamp(30, 8 * 60);
    // snap to 30-min units
    final step = (tick ~/ 30).clamp(1, 16) * 30;
    save.minutesFromMidnight += step;
    _appendLog('（時間が$step分経過した → ${clockLabel()}）');

    final departed = await _processDepartures();
    if (_isPastClose()) {
      await _closeDay();
    } else if (!departed) {
      // 退店と同じタイミングでは来店しない（次の時間経過で来店判定）
      await _tryArriveGuest();
    }
    await _autosave();
    notifyListeners();
  }

  bool _isPastClose() {
    // Close at 02:00 = 26*60 from previous noon timeline; we use minutes wrapping:
    // day starts 18:00 (1080). Close when >= 26:00 equivalent = 1080 + 8*60 = 1560
    // OR when hour crosses into 2am after midnight: minutesFromMidnight >= 24*60 + 2*60
    return save.minutesFromMidnight >= 24 * 60 + GameConstants.closeHour * 60;
  }

  Future<void> _closeDay() async {
    for (final g in List<GuestState>.from(save.guests)) {
      _onGuestLeave(g, closing: true);
    }
    save.guests.clear();
    save.day += 1;
    save.minutesFromMidnight = GameConstants.openHour * 60;
    save.logs = [];
    save.blockNextArrival = false;
    phase = GamePhase.idle;
    selectedGuestId = null;
    pendingTalkStep = null;
    _appendLog('DAY ${save.day} — バーが開店した。');
    await _tryArriveGuest();
  }

  /// Returns true if at least one guest left this tick.
  Future<bool> _processDepartures() async {
    final leaving = save.guests
        .where((g) => save.minutesFromMidnight >= g.departMinutes)
        .toList();
    for (final g in leaving) {
      _onGuestLeave(g, closing: false);
      save.guests.removeWhere((x) => x.customerId == g.customerId);
    }
    if (leaving.isNotEmpty &&
        (selectedGuestId == null ||
            !save.guests.any((g) => g.customerId == selectedGuestId))) {
      selectedGuestId =
          save.guests.isEmpty ? null : save.guests.first.customerId;
      if (selectedGuestId != null) _preloadTalk(selectedGuestId!);
    }
    return leaving.isNotEmpty;
  }

  void _onGuestLeave(GuestState g, {required bool closing}) {
    final customer = repository.customersById[g.customerId];
    final name = customer?.customerName ?? g.customerId;
    _appendLog(closing ? '$name が退店した。' : '$name が席を立った。');
    final prog = _progress(g.customerId);
    final canResume = prog.intimacyLevel >= GameConstants.stackResumeMinLevel &&
        _rng.nextDouble() < 0.5;
    if (!canResume && prog.stackStep > 1) {
      prog.stackStep = 1;
      prog.stackInterrupted = false;
    } else if (prog.stackStep > 1) {
      prog.stackInterrupted = true;
    }
  }

  Future<void> _tryArriveGuest() async {
    if (save.blockNextArrival) return;
    if (save.guests.length >= GameConstants.maxGuests) return;
    if (_isPastClose()) return;

    // Need free seat and not waiting for order-turn gate from previous serve
    // Spec: next guest only after drink + one command turn → blockNextArrival cleared in finishCommandTurn / serve
    final occupied = save.guests.map((g) => g.seat).toSet();
    final free = CustomerSeatId.values.where((s) => !occupied.contains(s)).toList();
    if (free.isEmpty) return;

    final inBar = save.guests.map((g) => g.customerId).toSet();
    final candidates =
        repository.customers.where((c) => !inBar.contains(c.id)).toList();
    if (candidates.isEmpty) return;

    // Soft random: always try when seats free after a turn (or opening)
    final customer = candidates[_rng.nextInt(candidates.length)];
    final seat = free[_rng.nextInt(free.length)];
    final stayHours = customer.avgStayHours + (_rng.nextInt(5) - 2) * 0.5;
    final stayMin = (stayHours * 60).round().clamp(30, 8 * 60);
    final guest = GuestState(
      customerId: customer.id,
      seat: seat,
      arrivedMinutes: save.minutesFromMidnight,
      departMinutes: save.minutesFromMidnight + stayMin,
      awaitingOrder: true,
    );
    save.guests.add(guest);
    selectedGuestId = customer.id;
    phase = GamePhase.idle;
    save.blockNextArrival = true; // until order+command done

    final prog = _progress(customer.id);
    if (prog.stackInterrupted) {
      _appendLog('・・・そういえばこの前話の途中だった話だけど・・・');
      prog.stackInterrupted = false;
    }
    _appendLog('${customer.customerName} が来店した。');
    _preloadTalk(customer.id);
    unawaited(audio.playSe(AudioPaths.doorRing));
  }

  void _preloadTalk(String customerId) {
    final prog = _progress(customerId);
    pendingTalkStep =
        repository.stepFor(customerId, prog.intimacyLevel, prog.stackStep);
  }

  CustomerProgress _progress(String id) {
    return save.progress.putIfAbsent(id, () => CustomerProgress(customerId: id));
  }

  GuestState? _selectedGuest() {
    final id = selectedGuestId;
    if (id == null) return null;
    return guestById(id);
  }

  void _appendLog(String line) {
    save.logs = [...save.logs, line];
    if (save.logs.length > 200) {
      save.logs = save.logs.sublist(save.logs.length - 200);
    }
  }

  Future<void> _autosave() async {
    await saveStore.save(save);
    hasSave = true;
  }

  @override
  void dispose() {
    unawaited(audio.dispose());
    super.dispose();
  }
}
