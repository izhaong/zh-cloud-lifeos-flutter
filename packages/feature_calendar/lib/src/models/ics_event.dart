/// ICS 解析出的单条事件（与 kernel 的 `CalendarEvent` 解耦：解析层不该知道落库细节）。
class IcsEvent {
  const IcsEvent({
    required this.uid,
    required this.title,
    required this.start,
    required this.allDay,
    this.end,
    this.description,
    this.location,
  });

  /// ICS 的 `UID`（缺失时用「开始时间 + 标题」兜底）。
  final String uid;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String? description;
  final String? location;
}
