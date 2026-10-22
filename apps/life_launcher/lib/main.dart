import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/life_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  /// 组合根：单点工厂切换 InMemory / Drift（Phase 1 起 Drift 为默认，
  /// 详见 packages/feature_productivity_drift；未注入前回退 InMemory 冒烟）。
  final repository = createReminderRepository();

  runApp(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repository),
      ],
      child: const LifeLauncherApp(),
    ),
  );
}

/// 组合根仓库工厂：当前返回 InMemory；Drift 门禁通过后切换为
/// `DriftReminderRepository(...)`（见 feature_productivity_drift 包）。
ReminderRepository createReminderRepository() {
  return InMemoryReminderRepository();
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
