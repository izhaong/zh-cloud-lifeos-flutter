import '../models/calendar_event.dart';

/// 日历云端协作端口（契约 §3.3–§3.6；F-17）。
///
/// 抽象放在 kernel、实现在 `feature_calendar_cloud`：与 `TaskCollabPort` 同形，
/// 这样开源侧的 `feature_calendar` 能在不 import 云包的前提下消费它
/// （#606 的「复制日程」就依赖这一点——原件在服务端时改走 `/event/duplicate`）。
abstract interface class CalendarCollabPort {
  Future<List<Map<String, dynamic>>> inboxList();

  Future<void> respondShare(int shareId, {required bool accept});

  Future<List<Map<String, dynamic>>> calendarList();

  Future<String?> exportFeedUrl(int? calendarId);

  Future<void> importIcs({
    required int calendarId,
    required String filename,
    required List<int> bytes,
  });

  /// TC-CAL-API-104：互斥置默认日历（服务端 `PUT /calendar/set-default?id=`）。
  Future<void> setDefaultCalendar(int calendarId);

  /// TC-CAL-API-140：导出单日历 .ics，返回服务端 `text/calendar` 原文。
  Future<String> exportCalendarIcs(int calendarId);

  /// TC-CAL-API-143：导出全部本地日历为一个 .ics。
  Future<String> exportAllIcs();

  /// TC-CAL-API-115：复制日程，服务端返回新日程编号。
  Future<int> duplicateEvent(int eventId, {required DateTime newStartAt});

  /// TC-CAL-API-163 的服务端真相：受邀者列表以服务端为准（客户端本地那份只是缓存）。
  Future<List<EventInvitee>> inviteeList(int eventId);

  /// TC-CAL-API-163（C-101）：移除受邀者（服务端已发送过则给该人写取消通知）。
  Future<void> removeInvitee(int eventId, String memberUserId);

  /// TC-CAL-API-162（C-100）：发送邀请（服务端置 `invited_at` 并写收件箱）。
  Future<void> sendInvitations(int eventId);

  /// TC-CAL-API-160（C-096/097）：按手机号解析成员编号。
  ///
  /// 日历侧没有解析端点（`AppLifeosCalendarInviteeController` 的 add 只收 `memberUserIds`），
  /// 全仓唯一入口是任务域 `GET /lifeos/task/list-member/resolve`——缝开在端口上，
  /// 跨域 URL 由 cloud 实现层吸收，`feature_calendar` 不因此依赖任务域包。
  Future<String> resolveMemberByMobile(String mobile);

  /// TC-CAL-API-160（C-096/097）：添加受邀者（服务端「仅添加不发送」，发送另走 sendInvitations）。
  Future<void> addInvitees(
    int eventId,
    List<String> memberUserIds, {
    InviteeRole role = InviteeRole.required,
  });
}
