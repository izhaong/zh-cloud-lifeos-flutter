/// 非 Web 平台的占位实现（#302）。
///
/// 条件导入的默认分支：VM / 移动 / 桌面走这里，返回 null 表示「浏览器 API 不可用」，
/// `deviceTimeZoneName()` 会继续走偏移兜底。
String? browserTimeZoneName() => null;
