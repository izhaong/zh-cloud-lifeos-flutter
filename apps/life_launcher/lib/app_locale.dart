import 'package:flutter/widgets.dart' show Locale;

/// 产品级 locale 声明（#387）。
///
/// 抽成常量是为了让测试能直接断言「声明 == 实际可达」，不必拉起整个应用。
/// #577 起设置辅助窗口（独立 engine）也读同一份，避免两个窗口语言不一致。
const Locale kAppLocale = Locale('zh', 'CN');

/// 声明支持的语言。**必须与 [kAppLocale] 一致**——声明了却不可达的语言就是假能力。
const List<Locale> kAppSupportedLocales = [Locale('zh', 'CN')];
