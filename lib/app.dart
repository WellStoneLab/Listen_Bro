import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'data/master_repository.dart';
import 'data/stores.dart';
import 'screens/debug_screen.dart';
import 'screens/game_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/title_screen.dart';
import 'services/game_controller.dart';

class ListenBroApp extends StatefulWidget {
  const ListenBroApp({super.key});

  @override
  State<ListenBroApp> createState() => _ListenBroAppState();
}

class _ListenBroAppState extends State<ListenBroApp> {
  late final GameController _controller;
  late final GoRouter _router;
  bool _bootCompleted = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _controller = GameController(
      repository: MasterDataRepository(),
      saveStore: SaveStore(),
      settingsStore: SettingsStore(),
    );

    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => TitleScreen(controller: _controller),
        ),
        GoRoute(
          path: '/game',
          builder: (context, state) => GameScreen(controller: _controller),
        ),
        GoRoute(
          path: '/debug',
          builder: (context, state) => DebugScreen(controller: _controller),
        ),
      ],
    );

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _controller.initialize(),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    if (mounted) setState(() => _bootCompleted = true);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5C3A2E);
    if (!_bootCompleted || _controller.loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      );
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: '聞いてよ！マスター',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
