import 'package:flutter/material.dart';

import '../config/game_constants.dart';
import '../models/game_models.dart';
import '../services/game_controller.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  GameController get c => widget.controller;
  late int _tick;
  late Map<String, int> _levels;
  late bool _showIntimacyHud;

  @override
  void initState() {
    super.initState();
    _tick = c.debug.tickMinutes;
    _showIntimacyHud = c.debug.showIntimacyHud;
    _levels = {
      for (final cust in c.repository.customers)
        cust.id: c.debug.intimacyLevels[cust.id] ??
            c.save.progress[cust.id]?.intimacyLevel ??
            0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tickOptions = [for (var m = 30; m <= 480; m += 30) m];
    return Scaffold(
      appBar: AppBar(title: const Text('デバッグ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('イベント経過時間'),
          DropdownButton<int>(
            value: _tick,
            isExpanded: true,
            items: [
              for (final m in tickOptions)
                DropdownMenuItem(value: m, child: Text('$m 分')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _tick = v);
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('親密度HUDをキャラ上に表示'),
            subtitle: const Text('レベルとゲージをスプライト上部に表示'),
            value: _showIntimacyHud,
            onChanged: (v) => setState(() => _showIntimacyHud = v),
          ),
          const SizedBox(height: 16),
          const Text('親密度レベル'),
          for (final cust in c.repository.customers)
            Row(
              children: [
                Expanded(child: Text(cust.customerName)),
                DropdownButton<int>(
                  value: _levels[cust.id] ?? 0,
                  items: [
                    for (var i = 0; i <= GameConstants.maxIntimacyLevel; i++)
                      DropdownMenuItem(value: i, child: Text('Lv.$i')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _levels[cust.id] = v);
                  },
                ),
              ],
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await c.updateDebug(DebugOverrides(
                tickMinutes: _tick,
                intimacyLevels: Map<String, int>.from(_levels),
                showIntimacyHud: _showIntimacyHud,
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('適用'),
          ),
        ],
      ),
    );
  }
}
