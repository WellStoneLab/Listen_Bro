import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/customer_seat_layout.dart';
import '../services/cocktail_mixer.dart';
import '../services/game_controller.dart';
import '../widgets/cocktail_mixer_sheet.dart';
import '../widgets/typewriter_log.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChanged);
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openMixer() async {
    c.openMixer();
    final input = await showModalBottomSheet<CocktailCraftInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1612),
      builder: (ctx) => CocktailMixerSheet(
        catalog: c.repository.cocktails,
        unlockedIds: c.save.unlockedRecipes,
        audio: c.audio,
      ),
    );
    if (input == null) {
      c.cancelMixer();
      return;
    }
    await c.serveCocktail(input);
  }

  @override
  Widget build(BuildContext context) {
    final guest = c.selectedGuestId == null ? null : c.guestById(c.selectedGuestId!);
    final awaiting = guest?.awaitingOrder ?? false;
    final canCommand = c.phase == GamePhase.awaitingCommand && guest != null && !awaiting;
    final questionAnswers = c.phase == GamePhase.awaitingQuestionAnswer
        ? (c.pendingTalkStep?.questionAnswers ?? const <String>[])
        : const <String>[];

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          // 16 bands: status handled by SafeArea top approx; we use full height
          // bands: datetime 1, main 8, commands 2, log 4 = 15; + safe top
          return SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: h * 1 / 16,
                  width: w,
                  child: _DateTimeBar(
                    day: c.save.day,
                    clock: c.clockLabel(),
                    onBack: () async {
                      await c.returnToTitle();
                      if (context.mounted) context.go('/');
                    },
                  ),
                ),
                SizedBox(
                  height: h * 8 / 16,
                  width: w,
                  child: _MainStage(controller: c, onTapSeat: c.selectGuest),
                ),
                SizedBox(
                  height: h * 2 / 16,
                  width: w,
                  child: _CommandPad(
                    targetName: guest == null
                        ? null
                        : (c.customerOf(guest.customerId)?.customerName ??
                            guest.customerId),
                    multiGuest: c.save.guests.length > 1,
                    canTalk: canCommand,
                    canService: canCommand,
                    canOrder: canCommand,
                    canWatch: c.phase != GamePhase.mixing &&
                        c.phase != GamePhase.awaitingQuestionAnswer,
                    showMix: awaiting &&
                        guest != null &&
                        c.phase != GamePhase.mixing &&
                        c.phase != GamePhase.awaitingQuestionAnswer,
                    questionAnswers: questionAnswers,
                    onTalk: c.commandTalk,
                    onWatch: c.commandWatch,
                    onService: c.commandService,
                    onOrder: c.commandOrder,
                    onMix: _openMixer,
                    onAnswer: c.answerQuestion,
                  ),
                ),
                SizedBox(
                  height: h * 4 / 16,
                  width: w,
                  child: TypewriterLog(
                    lines: c.save.logs,
                    messageSpeed: c.settings.messageSpeed,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateTimeBar extends StatelessWidget {
  const _DateTimeBar({
    required this.day,
    required this.clock,
    required this.onBack,
  });

  final int day;
  final String clock;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1210),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Color(0xFFD8C4A8), size: 20),
          ),
          Text(
            'DAY $day',
            style: const TextStyle(
              color: Color(0xFFF0E0C8),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(clock, style: const TextStyle(color: Color(0xFFE8D5B5), fontSize: 16)),
        ],
      ),
    );
  }
}

class _MainStage extends StatelessWidget {
  const _MainStage({required this.controller, required this.onTapSeat});

  final GameController controller;
  final void Function(String customerId) onTapSeat;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bw = constraints.maxWidth;
        final bh = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              CustomerSeatLayout.barBackgroundAsset,
              fit: BoxFit.cover,
            ),
            // Wide seat hit zones (easy tap) under sprites
            for (final seat in CustomerSeatId.values)
              _SeatHitZone(
                controller: controller,
                seat: seat,
                stageWidth: bw,
                stageHeight: bh,
                onTap: onTapSeat,
              ),
            for (final seat in CustomerSeatId.values)
              _SeatGuest(
                controller: controller,
                seat: seat,
                stageWidth: bw,
                stageHeight: bh,
                onTap: onTapSeat,
              ),
            if (controller.save.guests.length > 1)
              const Positioned(
                left: 8,
                top: 6,
                child: Text(
                  'お客様をタップして選択',
                  style: TextStyle(
                    color: Color(0xCCF0E0C8),
                    fontSize: 11,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 4),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Left / center / right third of the stage — tap empty bar area to select.
class _SeatHitZone extends StatelessWidget {
  const _SeatHitZone({
    required this.controller,
    required this.seat,
    required this.stageWidth,
    required this.stageHeight,
    required this.onTap,
  });

  final GameController controller;
  final CustomerSeatId seat;
  final double stageWidth;
  final double stageHeight;
  final void Function(String customerId) onTap;

  @override
  Widget build(BuildContext context) {
    final guest = controller.guestAt(seat);
    if (guest == null) return const SizedBox.shrink();

    final zoneW = stageWidth / 3;
    final left = switch (seat) {
      CustomerSeatId.left => 0.0,
      CustomerSeatId.center => zoneW,
      CustomerSeatId.right => zoneW * 2,
    };
    // Cover from mid-upper torso area through the counter
    final top = stageHeight * 0.22;
    final height = stageHeight * 0.62;

    return Positioned(
      left: left,
      top: top,
      width: zoneW,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(guest.customerId),
        child: const ColoredBox(color: Colors.transparent),
      ),
    );
  }
}

class _SeatGuest extends StatelessWidget {
  const _SeatGuest({
    required this.controller,
    required this.seat,
    required this.stageWidth,
    required this.stageHeight,
    required this.onTap,
  });

  final GameController controller;
  final CustomerSeatId seat;
  final double stageWidth;
  final double stageHeight;
  final void Function(String customerId) onTap;

  @override
  Widget build(BuildContext context) {
    final guest = controller.guestAt(seat);
    if (guest == null) return const SizedBox.shrink();
    final customer = controller.customerOf(guest.customerId);
    final selected = controller.selectedGuestId == guest.customerId;
    final spriteH = CustomerSeatLayout.spriteHeight(stageHeight);
    final top = CustomerSeatLayout.top(stageHeight);
    // Approximate sprite width from John aspect (~359/368)
    final spriteW = spriteH * (359 / 368);
    final left = CustomerSeatLayout.left(seat, stageWidth, spriteW);
    final asset = customer?.spriteOrder;
    final name = customer?.customerName ?? guest.customerId;

    return Positioned(
      left: left,
      top: top,
      width: spriteW,
      height: spriteH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(guest.customerId),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            if (selected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFC857), width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66FFC857),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            if (asset != null)
              Image.asset(asset, fit: BoxFit.contain)
            else
              Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFFC857)
                        : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            if (selected)
              Positioned(
                top: -36,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE61A1210),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFFC857)),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFFFFC857),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFFFFC857),
                      size: 22,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommandPad extends StatelessWidget {
  const _CommandPad({
    required this.targetName,
    required this.multiGuest,
    required this.canTalk,
    required this.canService,
    required this.canOrder,
    required this.canWatch,
    required this.showMix,
    required this.questionAnswers,
    required this.onTalk,
    required this.onWatch,
    required this.onService,
    required this.onOrder,
    required this.onMix,
    required this.onAnswer,
  });

  final String? targetName;
  final bool multiGuest;
  final bool canTalk;
  final bool canService;
  final bool canOrder;
  final bool canWatch;
  final bool showMix;
  final List<String> questionAnswers;
  final VoidCallback onTalk;
  final VoidCallback onWatch;
  final VoidCallback onService;
  final VoidCallback onOrder;
  final VoidCallback onMix;
  final void Function(String answer) onAnswer;

  @override
  Widget build(BuildContext context) {
    final targetLabel = targetName == null
        ? null
        : (multiGuest ? '対象: $targetName' : targetName);

    Widget pad;
    if (questionAnswers.isNotEmpty) {
      final answers = questionAnswers.take(4).toList();
      while (answers.length < 4) {
        answers.add('');
      }
      pad = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CmdButton(
                    label: answers[0],
                    onPressed:
                        answers[0].isEmpty ? null : () => onAnswer(answers[0]),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _CmdButton(
                    label: answers[1],
                    onPressed:
                        answers[1].isEmpty ? null : () => onAnswer(answers[1]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CmdButton(
                    label: answers[2],
                    onPressed:
                        answers[2].isEmpty ? null : () => onAnswer(answers[2]),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _CmdButton(
                    label: answers[3],
                    onPressed:
                        answers[3].isEmpty ? null : () => onAnswer(answers[3]),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (showMix) {
      pad = Row(
        children: [
          Expanded(
            child: _CmdButton(label: 'カクテルを作る', onPressed: onMix),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _CmdButton(
              label: 'みまもる',
              onPressed: canWatch ? onWatch : null,
            ),
          ),
        ],
      );
    } else {
      pad = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CmdButton(
                    label: 'トークをする',
                    onPressed: canTalk ? onTalk : null,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _CmdButton(
                    label: 'みまもる',
                    onPressed: canWatch ? onWatch : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CmdButton(
                    label: 'サービスをする',
                    onPressed: canService ? onService : null,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _CmdButton(
                    label: 'オーダーを聞く',
                    onPressed: canOrder ? onOrder : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (targetLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                questionAnswers.isNotEmpty
                    ? '回答を選ぶ（$targetLabel）'
                    : targetLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: questionAnswers.isNotEmpty || multiGuest
                      ? const Color(0xFFFFC857)
                      : const Color(0xFFB8A890),
                  fontSize: 11,
                  fontWeight: questionAnswers.isNotEmpty || multiGuest
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          Expanded(child: pad),
        ],
      ),
    );
  }
}

class _CmdButton extends StatelessWidget {
  const _CmdButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor:
              onPressed == null ? const Color(0xFF2A221E) : const Color(0xFF5A3A2C),
          foregroundColor:
              onPressed == null ? const Color(0xFF6A5A50) : const Color(0xFFF2E4D0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: label.length > 14 ? 10 : 13),
        ),
      ),
    );
  }
}
