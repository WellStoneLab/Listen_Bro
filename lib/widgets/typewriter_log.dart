import 'dart:async';

import 'package:flutter/material.dart';

class TypewriterLog extends StatefulWidget {
  const TypewriterLog({
    super.key,
    required this.lines,
    required this.messageSpeed,
  });

  final List<String> lines;
  final int messageSpeed;

  @override
  State<TypewriterLog> createState() => _TypewriterLogState();
}

class _TypewriterLogState extends State<TypewriterLog> {
  final _scroll = ScrollController();
  String _visible = '';
  int _lineIndex = 0;
  int _charIndex = 0;
  Timer? _timer;
  List<String> _committed = [];

  @override
  void initState() {
    super.initState();
    _syncFrom(widget.lines, reset: true);
  }

  @override
  void didUpdateWidget(covariant TypewriterLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines != oldWidget.lines) {
      // DAY refresh or append
      if (widget.lines.isEmpty) {
        _syncFrom(widget.lines, reset: true);
      } else if (oldWidget.lines.isEmpty ||
          widget.lines.length < oldWidget.lines.length ||
          (oldWidget.lines.isNotEmpty &&
              widget.lines.first != oldWidget.lines.first)) {
        _syncFrom(widget.lines, reset: true);
      } else {
        _syncFrom(widget.lines, reset: false);
      }
    }
    if (widget.messageSpeed != oldWidget.messageSpeed) {
      _restartTimer();
    }
  }

  void _syncFrom(List<String> lines, {required bool reset}) {
    _timer?.cancel();
    if (reset) {
      _committed = [];
      _lineIndex = 0;
      _charIndex = 0;
      _visible = '';
    }
    if (lines.isEmpty) {
      setState(() {});
      return;
    }
    // Commit any fully shown previous lines
    while (_lineIndex < lines.length - 1) {
      if (_committed.length <= _lineIndex) {
        _committed.add(lines[_lineIndex]);
      }
      _lineIndex++;
      _charIndex = 0;
    }
    // Current last line typewriter
    final last = lines.last;
    if (_committed.length < lines.length - 1) {
      _committed = lines.sublist(0, lines.length - 1);
    }
    if (_visible == last) {
      setState(() {});
      return;
    }
    if (!_committed.contains(last) && _charIndex == 0 && _visible.isEmpty) {
      // start typing last
    } else if (_committed.length == lines.length) {
      // all committed somehow
      setState(() {});
      return;
    }
    _restartTimer();
    setState(() {});
  }

  Duration get _delay {
    // 1 slow … 5 fast
    final ms = 70 - (widget.messageSpeed.clamp(1, 5) - 1) * 12;
    return Duration(milliseconds: ms);
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.lines.isEmpty) return;
    final target = widget.lines.last;
    _timer = Timer.periodic(_delay, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_charIndex >= target.length) {
        t.cancel();
        if (_committed.isEmpty || _committed.last != target) {
          setState(() {
            _committed = [...widget.lines];
            _visible = '';
          });
        }
        _scrollToEnd();
        return;
      }
      setState(() {
        _charIndex++;
        _visible = target.substring(0, _charIndex);
      });
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final older = widget.lines.isEmpty
        ? <String>[]
        : widget.lines.sublist(0, widget.lines.length - 1);
    final showTyping = widget.lines.isNotEmpty && _visible.isNotEmpty;

    return Container(
      color: const Color(0xFF120E0C),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: ListView(
        controller: _scroll,
        children: [
          for (final line in older)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: const TextStyle(color: Color(0xFFC8B8A4), fontSize: 13)),
            ),
          if (showTyping)
            Text(_visible, style: const TextStyle(color: Color(0xFFF2E6D6), fontSize: 13))
          else if (widget.lines.isNotEmpty && _visible.isEmpty && older.length == widget.lines.length - 1)
            Text(widget.lines.last, style: const TextStyle(color: Color(0xFFF2E6D6), fontSize: 13)),
        ],
      ),
    );
  }
}
