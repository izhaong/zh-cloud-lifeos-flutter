// TC-CAL-SYNC-107/108 收尾（#369）：收到 share 变更信号后，用 REST 列表把影子日历补回来。
//
// 链路：#553（服务端写 share 变更）→ #365（客户端 pull 不再静默丢弃，给出
// `report.shareChanged`）→ **本卡**（组合根据此重拉 `/calendar/list`）。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements CalendarRepository {
  final List<Calendar> calendars = [];

  @override
  Stream<List<Calendar>> watchCalendars() async* {
    yield List<Calendar>.unmodifiable(calendars);
  }

  @override
  Future<void> upsertCalendar(Calendar calendar) async {
    calendars.removeWhere((c) => c.id == calendar.id);
    calendars.add(calendar);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Port implements CalendarCollabPort {
  List<Map<String, dynamic>> rows = const [];
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> calendarList() async {
    calls++;
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('TC-CAL-SYNC-107 共享变化后重拉：影子日历落库且 kind 跟随服务端', () async {
    final repo = _Repo();
    final port = _Port()
      ..rows = [
        {
          'id': 900,
          'title': '张三的日历',
          'kind': 'SHARED',
          'color': '#FF9500',
          'isVisible': true,
          'revision': 3,
        },
      ];

    final applied =
        await refreshCalendarsFromRest(port: port, repository: repo);

    expect(applied, 1);
    expect(port.calls, 1);
    final calendar = repo.calendars.single;
    expect(calendar.remoteId, '900');
    expect(calendar.title, '张三的日历');
    expect(calendar.kind, CalendarKind.shared,
        reason: 'kind 必须跟随服务端；否则影子日历会被当成可写本地日历');
    expect(calendar.revision, 3);
  });

  test('TC-CAL-SYNC-108 重拉必须复用本地已有实体（不产生重复行）', () async {
    final repo = _Repo();
    await repo.upsertCalendar(const Calendar(
      id: 'local-1',
      remoteId: '900',
      title: '旧名字',
      colorArgb: 0xFF007AFF,
    ));
    final port = _Port()
      ..rows = [
        {'id': 900, 'title': '新名字', 'kind': 'SHARED'},
      ];

    await refreshCalendarsFromRest(port: port, repository: repo);

    expect(repo.calendars, hasLength(1), reason: '按 remoteId 复用同一行');
    expect(repo.calendars.single.id, 'local-1');
    expect(repo.calendars.single.title, '新名字');
  });

  test('没有 id 的行被跳过（无法对齐本地实体）', () async {
    final repo = _Repo();
    final port = _Port()
      ..rows = [
        {'title': '脏数据'},
        {'id': 901, 'title': '正常'},
      ];

    final applied =
        await refreshCalendarsFromRest(port: port, repository: repo);

    expect(applied, 1);
    expect(repo.calendars.single.remoteId, '901');
  });
}
