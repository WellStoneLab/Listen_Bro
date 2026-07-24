import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/customer_seat_layout.dart';
import '../services/cocktail_mixer.dart';
import '../services/game_controller.dart';
import '../widgets/cocktail_mixer_sheet.dart';
import '../widgets/typewriter_log.dart';

/// Amber selection outline that follows sprite alpha (not a bounding box).
const _kSelectAmber = Color(0xFFFFC857);
const _kSelectAmberSoft = Color(0xAAFFC857);
const _kSelectOutlineOffsets = <Offset>[
  Offset(-1.8, 0),
  Offset(1.8, 0),
  Offset(0, -1.8),
  Offset(0, 1.8),
  Offset(-1.4, -1.4),
  Offset(1.4, -1.4),
  Offset(-1.4, 1.4),
  Offset(1.4, 1.4),
];

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
    final locked = c.phase == GamePhase.closing || c.blackoutOpacity > 0;
    final canCommand =
        !locked && c.phase == GamePhase.awaitingCommand && guest != null && !awaiting;
    final questionAnswers = (!locked && c.phase == GamePhase.awaitingQuestionAnswer)
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
            child: Stack(
              children: [
                Column(
                  children: [
                    SizedBox(
                      height: h * 1 / 16,
                      width: w,
                      child: _DateTimeBar(
                        day: c.save.day,
                        clock: c.clockLabel(),
                        onBack: locked
                            ? null
                            : () async {
                                await c.returnToTitle();
                                if (context.mounted) context.go('/');
                              },
                      ),
                    ),
                    SizedBox(
                      height: h * 8 / 16,
                      width: w,
                      child: _MainStage(
                        controller: c,
                        onTapSeat: locked ? (_) {} : c.selectGuest,
                      ),
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
                        canWatch: !locked &&
                            c.phase != GamePhase.mixing &&
                            c.phase != GamePhase.awaitingQuestionAnswer,
                        showMix: !locked &&
                            awaiting &&
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
                // Full-screen blackout for day transition
                IgnorePointer(
                  ignoring: c.blackoutOpacity < 0.01,
                  child: AnimatedOpacity(
                    opacity: c.blackoutOpacity.clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    child: const ColoredBox(color: Colors.black),
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
    this.onBack,
  });

  final int day;
  final String clock;
  final VoidCallback? onBack;

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

class _MainStage extends StatefulWidget {
  const _MainStage({required this.controller, required this.onTapSeat});

  final GameController controller;
  final void Function(String customerId) onTapSeat;

  @override
  State<_MainStage> createState() => _MainStageState();
}

class _SeatPresence {
  _SeatPresence({required this.customerId, required this.shown});

  final String customerId;
  bool shown;
}

class _MainStageState extends State<_MainStage> {
  static const _dissolve = Duration(milliseconds: 700);

  final Map<CustomerSeatId, _SeatPresence> _presence = {};
  bool _bootstrapped = false;

  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant _MainStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPresence();
  }

  void _bootstrap() {
    for (final seat in CustomerSeatId.values) {
      final g = controller.guestAt(seat);
      if (g != null) {
        // Start hidden, then dissolve in on first frame.
        _presence[seat] = _SeatPresence(customerId: g.customerId, shown: false);
      }
    }
    _bootstrapped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (final p in _presence.values) {
          p.shown = true;
        }
      });
    });
  }

  void _syncPresence() {
    if (!_bootstrapped) return;
    var changed = false;

    for (final seat in CustomerSeatId.values) {
      final g = controller.guestAt(seat);
      final cur = _presence[seat];

      if (g != null) {
        if (cur == null || cur.customerId != g.customerId) {
          _presence[seat] = _SeatPresence(customerId: g.customerId, shown: false);
          changed = true;
          final id = g.customerId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final p = _presence[seat];
            if (p == null || p.customerId != id || p.shown) return;
            setState(() => p.shown = true);
          });
        }
      } else if (cur != null && cur.shown) {
        cur.shown = false;
        changed = true;
        final id = cur.customerId;
        Future<void>.delayed(_dissolve, () {
          if (!mounted) return;
          final p = _presence[seat];
          if (p == null || p.customerId != id || p.shown) return;
          setState(() => _presence.remove(seat));
        });
      }
    }

    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bw = constraints.maxWidth;
        final bh = constraints.maxHeight;
        final visibleCount =
            _presence.values.where((p) => p.shown).length;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              CustomerSeatLayout.barBackgroundAsset,
              fit: BoxFit.cover,
            ),
            for (final seat in CustomerSeatId.values)
              _SeatHitZone(
                controller: controller,
                seat: seat,
                stageWidth: bw,
                stageHeight: bh,
                onTap: widget.onTapSeat,
                interactive: _presence[seat]?.shown == true &&
                    controller.guestAt(seat) != null,
              ),
            for (final seat in CustomerSeatId.values)
              if (_presence[seat] != null)
                _SeatGuest(
                  controller: controller,
                  seat: seat,
                  customerId: _presence[seat]!.customerId,
                  shown: _presence[seat]!.shown,
                  dissolve: _dissolve,
                  stageWidth: bw,
                  stageHeight: bh,
                  onTap: widget.onTapSeat,
                  tappable: controller.guestAt(seat)?.customerId ==
                      _presence[seat]!.customerId,
                  showIntimacyHud: controller.debug.showIntimacyHud,
                ),
            // Order dialogue as speech bubble (not log)
            if (controller.orderBubbleText != null &&
                controller.selectedGuestId != null)
              _OrderBubble(
                text: controller.orderBubbleText!,
                seat: controller.guestById(controller.selectedGuestId!)?.seat ??
                    CustomerSeatId.center,
                stageWidth: bw,
                stageHeight: bh,
              ),
            if (visibleCount > 1)
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
            // Closing announcement (dissolve)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: controller.closingMessage == null ? 0 : 1,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                child: Container(
                  alignment: Alignment.center,
                  color: const Color(0x66000000),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    controller.closingMessage ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF0E0C8),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Order line as a speech bubble above the ordering guest (main stage, not log).
class _OrderBubble extends StatelessWidget {
  const _OrderBubble({
    required this.text,
    required this.seat,
    required this.stageWidth,
    required this.stageHeight,
  });

  final String text;
  final CustomerSeatId seat;
  final double stageWidth;
  final double stageHeight;

  @override
  Widget build(BuildContext context) {
    final spriteH = CustomerSeatLayout.spriteHeight(stageHeight);
    final top = CustomerSeatLayout.top(stageHeight);
    final spriteW = spriteH * (359 / 368);
    final left = CustomerSeatLayout.left(seat, stageWidth, spriteW);
    final maxW = (spriteW * 1.35).clamp(120.0, stageWidth * 0.42);

    return Positioned(
      left: (left + spriteW / 2 - maxW / 2).clamp(4.0, stageWidth - maxW - 4),
      top: (top - 56).clamp(4.0, stageHeight),
      width: maxW,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xF2FFF8EE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC4A574), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF2A1E14),
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(16, 8),
            painter: _BubbleTailPainter(),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.7, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xF2FFF8EE));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFC4A574)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Left / center / right third of the stage — tap empty bar area to select.
class _SeatHitZone extends StatelessWidget {
  const _SeatHitZone({
    required this.controller,
    required this.seat,
    required this.stageWidth,
    required this.stageHeight,
    required this.onTap,
    required this.interactive,
  });

  final GameController controller;
  final CustomerSeatId seat;
  final double stageWidth;
  final double stageHeight;
  final void Function(String customerId) onTap;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final guest = controller.guestAt(seat);
    if (guest == null || !interactive) return const SizedBox.shrink();

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
    required this.customerId,
    required this.shown,
    required this.dissolve,
    required this.stageWidth,
    required this.stageHeight,
    required this.onTap,
    required this.tappable,
    required this.showIntimacyHud,
  });

  final GameController controller;
  final CustomerSeatId seat;
  final String customerId;
  final bool shown;
  final Duration dissolve;
  final double stageWidth;
  final double stageHeight;
  final void Function(String customerId) onTap;
  final bool tappable;
  final bool showIntimacyHud;

  @override
  Widget build(BuildContext context) {
    final guest = controller.guestAt(seat);
    final customer = controller.customerOf(customerId);
    final selected =
        tappable && controller.selectedGuestId == customerId && shown;
    final spriteH = CustomerSeatLayout.spriteHeight(stageHeight);
    final top = CustomerSeatLayout.top(stageHeight);
    // Approximate sprite width from John aspect (~359/368)
    final spriteW = spriteH * (359 / 368);
    final left = CustomerSeatLayout.left(seat, stageWidth, spriteW);
    final drinking = guest != null && !guest.awaitingOrder;
    final asset = drinking
        ? (customer?.spriteDrink ?? customer?.spriteOrder)
        : customer?.spriteOrder;
    final name = customer?.customerName ?? customerId;
    final prog = controller.save.progress[customerId];

    return Positioned(
      left: left,
      top: top,
      width: spriteW,
      height: spriteH,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: dissolve,
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: !tappable || !shown,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(customerId),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                if (asset != null)
                  _SelectedSprite(asset: asset, selected: selected)
                else
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? _kSelectAmber : Colors.white24,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                if (showIntimacyHud && prog != null)
                  Positioned(
                    top: -28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE61A1210),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF8AB4FF)),
                      ),
                      child: Text(
                        'Lv.${prog.intimacyLevel}  G:${prog.intimacyGauge}',
                        style: const TextStyle(
                          color: Color(0xFFB8D4FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (selected)
                  Positioned(
                    top: showIntimacyHud ? -52 : -36,
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
                            border: Border.all(color: _kSelectAmber),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: _kSelectAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: _kSelectAmber,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Character sprite with optional amber edge highlight along the alpha silhouette.
class _SelectedSprite extends StatelessWidget {
  const _SelectedSprite({required this.asset, required this.selected});

  final String asset;
  final bool selected;

  static const _silhouette = ColorFilter.mode(_kSelectAmber, BlendMode.srcIn);
  static const _silhouetteSoft =
      ColorFilter.mode(_kSelectAmberSoft, BlendMode.srcIn);

  @override
  Widget build(BuildContext context) {
    Image sprite() => Image.asset(asset, fit: BoxFit.contain);
    if (!selected) return sprite();

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
          child: ColorFiltered(colorFilter: _silhouetteSoft, child: sprite()),
        ),
        for (final o in _kSelectOutlineOffsets)
          Transform.translate(
            offset: o,
            child: ColorFiltered(colorFilter: _silhouette, child: sprite()),
          ),
        sprite(),
      ],
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
