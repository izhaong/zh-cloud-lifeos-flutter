/// 颜色输入解析（#404）：让用户能自定义日历颜色，而不止内置色板。
///
/// 接受 `#RRGGBB` / `RRGGBB` / `#AARRGGBB`（大小写不限、允许首尾空白）。
/// 返回不透明 ARGB（无 alpha 时补 `0xFF`）；无法解析返回 null。
///
/// 为什么是「输入十六进制」而不是 Apple 的色轮：Issue 已写明「不要求逐像素复刻
/// Apple 色轮」，而色轮在 widget 测试里几乎不可断言（拖拽坐标 → 色相映射易漂移）。
/// 十六进制输入能覆盖「任意颜色」这个真实诉求，且是纯函数可单测。
int? parseHexColor(String raw) {
  var value = raw.trim();
  if (value.startsWith('#')) {
    value = value.substring(1);
  }
  if (value.length == 6) {
    value = 'FF$value';
  }
  if (value.length != 8) {
    return null;
  }
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    return null;
  }
  // 全透明对日历没有意义（等于看不见），按不透明处理。
  final alpha = (parsed >> 24) & 0xFF;
  return alpha == 0 ? (parsed | 0xFF000000) : parsed;
}

/// 转回 `#RRGGBB`（UI 回填用；忽略 alpha）。
String toHexColor(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
