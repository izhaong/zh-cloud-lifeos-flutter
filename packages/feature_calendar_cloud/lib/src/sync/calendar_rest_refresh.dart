// 共享关系变化后的日历重拉（#369）。
//
// 背景：服务端在共享邀请/回复/改权限/移除时写 `entityType=share` 的变更（#553），
// 并在同一事务里建/删**影子日历**。客户端 pull 到 share 变更后只知道「共享变了」
// （`CalendarSyncReport.shareChanged`，见 #365），影子日历本身要另取一次列表。
//
// 这里用 REST `/calendar/list` 全量拉一次并 upsert——比让服务端把影子日历也塞进
// 增量 change 简单，也不会因为 cursor 已推进而漏掉同一事务里的行。
import '../collab/rest_calendar_collab_port.dart';
import 'calendar_sync_coordinator.dart';
import 'package:feature_calendar/feature_calendar.dart';

/// 拉一次日历列表并落库，返回 upsert 的条数。
///
/// 失败交由调用方处理（启动路径上应与其它同步一样「不挡本地」）。
Future<int> refreshCalendarsFromRest({
  required CalendarCollabPort port,
  required CalendarRepository repository,
}) async {
  final rows = await port.calendarList();
  if (rows.isEmpty) {
    return 0;
  }
  final existing = await repository.watchCalendars().first;
  final byRemote = <String, Calendar>{
    for (final calendar in existing)
      if (calendar.remoteId != null) calendar.remoteId!: calendar,
  };
  var applied = 0;
  for (final row in rows) {
    final remoteId = row['id']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      continue; // 没有服务端 id 的行没法对齐本地实体
    }
    final calendar = CalendarSyncCoordinator.calendarFromPayload(
      row,
      remoteId: remoteId,
      existing: byRemote[remoteId],
    );
    await repository.upsertCalendar(calendar);
    byRemote[remoteId] = calendar;
    applied++;
  }
  return applied;
}
