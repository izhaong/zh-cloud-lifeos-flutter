import 'dart:js_interop';

/// 浏览器 IANA 时区名（#302），如 `America/New_York`；取不到返回 null。
///
/// `flutter_timezone` 在 Web 上不可用，而 `Etc/GMT±N` 兜底是固定偏移、不跟
/// 夏令时。浏览器本身知道真名：
/// `Intl.DateTimeFormat().resolvedOptions().timeZone`。
@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}

String? browserTimeZoneName() {
  try {
    final zone = _DateTimeFormat().resolvedOptions().timeZone;
    if (zone == null || zone.isEmpty) return null;
    return zone;
  } catch (_) {
    return null;
  }
}
