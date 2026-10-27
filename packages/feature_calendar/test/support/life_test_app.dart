import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_localizations/flutter_localizations.dart' as sdk;

/// 测试宿主：保留 MaterialApp 给未迁移的第三方 Material 岛（kalender 等），
/// 同时挂 cupertino_ui 与 SDK 的本地化，供 Cupertino 弹窗/Sheet/Picker 使用。
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
