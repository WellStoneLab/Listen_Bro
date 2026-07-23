import 'dart:async';

import 'package:flutter/material.dart';

import '../config/audio_paths.dart';
import '../config/game_constants.dart';
import '../models/master_models.dart';
import '../services/audio_service.dart';
import '../services/cocktail_mixer.dart';

class CocktailMixerSheet extends StatefulWidget {
  const CocktailMixerSheet({
    super.key,
    required this.catalog,
    required this.audio,
    this.unlockedIds = const {},
  });

  final List<CocktailDef> catalog;
  final AudioService audio;
  final Set<String> unlockedIds;

  @override
  State<CocktailMixerSheet> createState() => _CocktailMixerSheetState();
}

class _CocktailMixerSheetState extends State<CocktailMixerSheet> {
  /// -1 = pick unlocked / craft from scratch; 0–3 = ingredient steps.
  late int _step;
  String? _base;
  final Set<String> _mix = {};
  /// null until user picks シェイクする / シェイクしない.
  bool? _shake;
  final Set<String> _top = {};

  List<CocktailDef> get _unlocked {
    final byId = {for (final c in widget.catalog) c.id: c};
    return widget.unlockedIds
        .map((id) => byId[id])
        .whereType<CocktailDef>()
        .toList()
      ..sort((a, b) => a.cocktailName.compareTo(b.cocktailName));
  }

  @override
  void initState() {
    super.initState();
    _step = _unlocked.isEmpty ? 0 : -1;
  }

  @override
  void dispose() {
    unawaited(widget.audio.stopSe());
    super.dispose();
  }

  void _serveRecipe(CocktailDef recipe) {
    Navigator.pop(context, CocktailCraftInput.fromRecipe(recipe));
  }

  Future<void> _selectShake(bool shake) async {
    setState(() => _shake = shake);
    if (shake) {
      await widget.audio.playSeFor(
        AudioPaths.cocktailShake,
        const Duration(seconds: 2),
      );
    } else {
      await widget.audio.stopSe();
    }
  }

  bool get _canGoNext {
    if (_step == 0) return _base != null;
    if (_step == 2) return _shake != null;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'カクテル作成',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_step == -1) ...[
              const Text(
                '作成済みカクテル',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                '一度成功したネームドは、ここからそのまま提供できます。',
                style: TextStyle(fontSize: 12, color: Color(0xFFB8A890)),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _unlocked)
                        FilledButton.tonal(
                          onPressed: () => _serveRecipe(c),
                          child: Text(c.cocktailName),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('材料から新しく作る'),
              ),
            ] else if (_step == 0) ...[
              const Text('1. ベースを選ぶ'),
              Wrap(
                spacing: 6,
                children: [
                  for (final b in GameConstants.bases)
                    ChoiceChip(
                      label: Text(b),
                      selected: _base == b,
                      onSelected: (_) => setState(() => _base = b),
                    ),
                ],
              ),
            ] else if (_step == 1) ...[
              const Text('2. ミックス液体（複数可）'),
              Wrap(
                spacing: 6,
                children: [
                  for (final m in GameConstants.mixLiquors)
                    FilterChip(
                      label: Text(m),
                      selected: _mix.contains(m),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _mix.add(m);
                        } else {
                          _mix.remove(m);
                        }
                      }),
                    ),
                ],
              ),
            ] else if (_step == 2) ...[
              const Text('3. シェイク'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('シェイクする'),
                    selected: _shake == true,
                    onSelected: (_) => unawaited(_selectShake(true)),
                  ),
                  ChoiceChip(
                    label: const Text('シェイクしない'),
                    selected: _shake == false,
                    onSelected: (_) => unawaited(_selectShake(false)),
                  ),
                ],
              ),
            ] else ...[
              const Text('4. トッピング（複数可）'),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in GameConstants.afterShakes)
                    FilterChip(
                      label: Text(t),
                      selected: _top.contains(t),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _top.add(t);
                        } else {
                          _top.remove(t);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (_step >= 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_step > 0 || _unlocked.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        unawaited(widget.audio.stopSe());
                        setState(() {
                          if (_step == 0 && _unlocked.isNotEmpty) {
                            _step = -1;
                          } else {
                            _step--;
                          }
                        });
                      },
                      child: const Text('戻る'),
                    ),
                  const Spacer(),
                  if (_step < 3)
                    FilledButton(
                      onPressed: !_canGoNext
                          ? null
                          : () {
                              unawaited(widget.audio.stopSe());
                              setState(() => _step++);
                            },
                      child: const Text('次へ'),
                    )
                  else
                    FilledButton(
                      onPressed: _base == null || _shake == null
                          ? null
                          : () {
                              unawaited(widget.audio.stopSe());
                              Navigator.pop(
                                context,
                                CocktailCraftInput(
                                  base: _base!,
                                  mixLiquor: _mix.toList(),
                                  shake: _shake!,
                                  afterShake: _top.toList(),
                                ),
                              );
                            },
                      child: const Text('提供する'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
