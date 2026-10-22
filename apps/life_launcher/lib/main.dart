import 'package:app_core/app_core.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/life_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 组合根：单点工厂切换 InMemory / Drift。
  /// P0 起默认 Drift（离线持久化）；测试与冒烟可切回 InMemory。
  final repository = await openDefaultDriftRepository();

  runApp(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
      ],
      child: const LifeLauncherApp(),
    ),
  );
}

class LifeLauncherApp extends StatelessWidget {
  const LifeLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildLifeRouter();
    return MaterialApp.router(
      title: 'LifeOS 生活台',
      debugShowCheckedModeBanner: false,
      theme: LifeTokens.light(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
