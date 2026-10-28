import '../models/calendar.dart';
import '../models/calendar_event.dart';
import '../models/calendar_preference.dart';

/// 日历数据端口（契约 §5.2；开源包唯一数据入口，禁止依赖 HTTP）。
///
/// 编辑语义（对齐提醒端口约定）：
/// - 全字段编辑 = UI 层构造/复制模型 + [upsertEvent] 全量回写；
///   重复事件的「仅此日程 / 此日程及之后 / 所有日程」由 [EditScope] +
///   [upsertEvent.occurrenceStart] 承载（契约 §3.2.1）。
/// - `watch*` 返回 [Stream]：任何写操作后订阅方收到新快照，UI 用
///   Riverpod StreamProvider 消费，禁止手动 reload 循环。
abstract interface class CalendarRepository {
  /// 全部日历（侧栏数据；含 isVisible/isDefault/组名）。
  Stream<List<Calendar>> watchCalendars();

  /// 时间窗 `[from, to)` 内的日程主记录与例外行（重复展开交给
  /// `expandOccurrences` 纯函数；主记录不按窗口截断，由展开器过滤）。
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  });

  Future<CalendarEvent?> getEvent(String id);

  /// 新增或更新日历（全量回写）。
  Future<void> upsertCalendar(Calendar c);

  /// 删除日历（级联其日程；最后一条本地日历拒绝删除，见契约 §7）。
  Future<void> deleteCalendar(String id);

  /// 设默认日历（每用户唯一）。
  Future<void> setDefaultCalendar(String id);

  /// 侧栏保序重排（[ids] 为目标全序）。
  Future<void> reorderCalendars(List<String> ids);

  /// 可见性：单条勾选（[id]+[visible]）、全选/全不选（[allVisible]）、
  /// 仅显示该日历（[onlyId]）。
  Future<void> setVisibility({String? id, bool? visible, bool? allVisible, String? onlyId});

  /// 新增或更新日程，返回落库后的 id。
  ///
  /// [scope] 仅对重复主记录有意义；[occurrenceStart] 为被编辑的原始
  /// occurrence 开始（UTC，scope=thisOnly/thisAndFuture 时必传）。
  Future<String> upsertEvent(
    CalendarEvent e, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  });

  /// 删除日程（重复事件按 [EditScope]：仅此/及之后/全部）。
  Future<void> deleteEvent(
    String id, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  });

  /// 移动日程到其他日历（目标须同用户且可写）。
  Future<void> moveEvent(String id, String targetCalendarId);

  /// 标题/地点/备注 LIKE 搜索（limit 默认 50）。
  Future<List<CalendarEvent>> search(
    String keyword, {
    DateTime? from,
    DateTime? to,
    int limit = 50,
  });

  /// 用户偏好（未设置时实现层应回契约 §2.9 默认值）。
  Stream<CalendarPreference> watchPreference();

  Future<void> savePreference(CalendarPreference p);
}

/// 系统写入能力（可选端口，#230）。
///
/// 节假日补齐 / 订阅刷新这类**应用内部生成**的日程不由用户编辑，必须绕过
/// [CalendarRepository.upsertEvent] 的只读守卫——否则「订阅过节假日」的端
/// 每次启动都会在写只读日历时抛异常，`runApp` 永不执行（纯黑窗口）。
///
/// 这不是放宽只读规则：实现层只接受落到系统日历（[CalendarKind.holiday] /
/// [CalendarKind.subscription]）的写入，其它日历照旧拒绝；用户路径仍走
/// [CalendarRepository.upsertEvent]。
abstract interface class CalendarSystemWriter {
  /// 写入应用内部生成的日程（幂等：同一 id 覆盖）。
  ///
  /// 目标日历非系统日历（或不存在）时抛 [StateError]。
  Future<void> upsertSystemEvent(CalendarEvent e);
}

/// 重复事件编辑范围（契约 §3.2.1：仅此日程 / 此日程及之后 / 所有日程）。
enum EditScope { thisOnly, thisAndFuture, all }
