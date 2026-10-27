import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalMaterialLocalizations, GlobalWidgetsLocalizations;

/// 测试宿主：保留 MaterialApp 给未迁移的 Material widget，
/// 同时挂 cupertino_ui 的本地化，供新 Cupertino 弹窗/Sheet 使用。
Widget lifeTestHost(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh', 'CN')],
    locale: const Locale('zh', 'CN'),
    home: child,
  );
}
