/// kalender 的日期/星期名走 intl，包里只编译 en_US；其它语言必须先初始化
/// 本地化数据，否则 zh_CN 下会渲染成 Mon…Sun（#193）。
library;

import 'package:intl/date_symbol_data_local.dart';

bool _initialized = false;

/// 在 runApp 前调用一次；重复调用无副作用。
Future<void> ensureCalendarDateLocalization() async {
  if (_initialized) return;
  await initializeDateFormatting();
  _initialized = true;
}
