/// 测试支撑（Epic #126/D）。
///
/// 只给各包 `test/` 用，不进生产代码路径。放在 app_core 是为了让所有依赖它的
/// 包共享同一份宿主，而不是每个包 `test/support/` 各抄一份。
library;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_localizations/flutter_localizations.dart' as sdk;

/// 测试宿主：保留 MaterialApp 给尚未迁移的 Material widget / 第三方岛
/// （kalender、quill 等），同时挂 cupertino_ui 与 SDK 的本地化，供新 Cupertino
/// 弹窗 / Sheet / Picker 使用。
///
/// 早先 `feature_task` 与 `feature_calendar` 各有一份逐字相同的实现（#293）；
/// 现在两处 `test/support/life_test_app.dart` 只是 re-export 本文件。
Widget lifeTestHost(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalCupertinoLocalizations.delegate,
      sdk.GlobalCupertinoLocalizations.delegate,
      sdk.GlobalMaterialLocalizations.delegate,
      sdk.GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh', 'CN')],
    locale: const Locale('zh', 'CN'),
    home: child,
  );
}
