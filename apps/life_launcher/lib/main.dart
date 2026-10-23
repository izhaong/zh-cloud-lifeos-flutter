import 'package:app_core/app_core.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'router/life_router.dart';
import 'shell/pinned_tabs_service.dart';
import 'shell_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 组合根：单点工厂切换 InMemory / Drift；偏好存储与徽标源同在此注入。
  final repository = await openDefaultDriftRepository();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
        pinnedTabsServiceProvider.overrideWithValue(
          PinnedTabsService(prefs),
        ),
      ],
      child: const LifeLauncherApp(),
    ),
  );
}

class LifeLauncherApp extends ConsumerWidget {
  const LifeLauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = buildLifeRouter(ref);
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
