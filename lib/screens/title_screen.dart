import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/game_controller.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  final List<DateTime> _taps = [];

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

  void _onTitleTap() {
    final now = DateTime.now();
    _taps.removeWhere((t) => now.difference(t).inMilliseconds > 3000);
    _taps.add(now);
    if (_taps.length >= 5) {
      _taps.clear();
      context.push('/debug');
    }
  }

  Future<void> _startNew() async {
    try {
      if (c.hasSave) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('はじめから'),
            content: const Text(
              'はじめからゲームを開始すると、進行中のゲームを初期化してしまいます。よろしいですか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('はじめる'),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }
      await c.startNewGame();
      if (mounted) context.go('/game');
    } catch (e, st) {
      debugPrint('startNew failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('開始に失敗しました: $e')),
      );
    }
  }

  Future<void> _continue() async {
    await c.continueGame();
    if (mounted) context.go('/game');
  }

  Future<void> _openSettings() async {
    var music = c.settings.musicVolume;
    var sound = c.settings.soundVolume;
    var speed = c.settings.messageSpeed;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Music ${(music * 100).round()}%'),
                  Slider(
                    value: music,
                    onChanged: (v) => setLocal(() => music = v),
                  ),
                  Text('Sound ${(sound * 100).round()}%'),
                  Slider(
                    value: sound,
                    onChanged: (v) => setLocal(() => sound = v),
                  ),
                  Text('メッセージ速度 $speed'),
                  Slider(
                    value: speed.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (v) => setLocal(() => speed = v.round()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await c.updateSettings(c.settings.copyWith(
                      musicVolume: music,
                      soundVolume: sound,
                      messageSpeed: speed,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openCredits() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('クレジット'),
        content: const Text(
          'ゲーム制作：WellStone Lab\n'
          'キャラクター画像提供元：\n'
          '背景画像提供元：\n'
          '音楽・効果音提供元：',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1814), Color(0xFF0E0A09)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    GestureDetector(
                      onTap: _onTitleTap,
                      child: const Text(
                        '聞いてよ！マスター',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF0E0C8),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Listen_Bro',
                      style: TextStyle(color: Color(0xFF9A8470), fontSize: 14),
                    ),
                    const Spacer(),
                    _MenuButton(label: 'はじめから', onPressed: _startNew),
                    const SizedBox(height: 12),
                    _MenuButton(
                      label: 'つづきから',
                      onPressed: c.hasSave ? _continue : null,
                    ),
                    const SizedBox(height: 12),
                    _MenuButton(label: '設定', onPressed: _openSettings),
                    const SizedBox(height: 12),
                    _MenuButton(label: 'クレジット', onPressed: _openCredits),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFF6B4535) : const Color(0xFF3A2A24),
          foregroundColor: enabled ? const Color(0xFFF5E6D3) : const Color(0xFF7A6A60),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
