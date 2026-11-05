import 'package:feature_calendar_cloud/feature_calendar_cloud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// F-17 云侧 UI（TC-CAL-UI-180～182）。
void main() {
  late _CollabPort port;
  late ProviderContainer container;

  setUp(() {
    port = _CollabPort();
    container = ProviderContainer(
      overrides: [calendarCollabPortProvider.overrideWithValue(port)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpPage(WidgetTester tester, {int tab = 0}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: CalendarCloudPage(initialTab: tab)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('TC-CAL-UI-180 收件箱列表', (tester) async {
    port.inbox = [
      {'id': 1, 'type': 'SHARE_INVITATION', 'shareId': 7, 'payload': '共享：工作'},
      {'id': 2, 'type': 'EVENT_REPLY', 'payload': '接受了邀请'},
    ];
    await pumpPage(tester);

    expect(find.byKey(const Key('inbox_list')), findsOneWidget);
    expect(find.text('SHARE_INVITATION'), findsOneWidget);
    expect(find.text('EVENT_REPLY'), findsOneWidget);
  });

  testWidgets('TC-CAL-UI-181 接受共享', (tester) async {
    port.inbox = [
      {'id': 1, 'type': 'SHARE_INVITATION', 'shareId': 7, 'payload': '共享：工作'},
    ];
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('inbox_accept_1')));
    await tester.pumpAndSettle();

    expect(port.responded, [(7, true)]);
    expect(find.text('已接受共享'), findsOneWidget);
  });

  testWidgets('TC-CAL-UI-182 共享日历与导出链接', (tester) async {
    port.calendars = [
      {'id': 1, 'title': '团队', 'kind': 'SHARED', 'permission': 'EDIT'},
      {'id': 2, 'title': '工作', 'kind': 'LOCAL'},
    ];
    await pumpPage(tester, tab: 1);
    expect(find.byKey(const Key('shared_list')), findsOneWidget);
    expect(find.text('团队'), findsOneWidget);

    await tester.tap(find.text('导入导出'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export_feed_button')));
    await tester.pumpAndSettle();
    final message = tester.widget<Text>(
      find.byKey(const Key('calendar_cloud_message')),
    );
    expect(message.data, contains('导出链接'));
  });

  testWidgets('#604 导入导出页有「设为默认」「导出 .ics」「导出全部」入口', (tester) async {
    port.calendars = [
      {'id': 7, 'title': '工作', 'kind': 'LOCAL'},
    ];
    await pumpPage(tester, tab: 2);
    await tester.pumpAndSettle();

    String message() => tester
        .widget<Text>(find.byKey(const Key('calendar_cloud_message')))
        .data!;

    await tester.tap(find.byKey(const Key('set_default_calendar_7')));
    await tester.pumpAndSettle();
    expect(port.defaultSet, 7);
    expect(message(), contains('已设为默认日历'));

    await tester.tap(find.byKey(const Key('export_calendar_7')));
    await tester.pumpAndSettle();
    expect(message(), contains('已导出'));

    await tester.tap(find.byKey(const Key('export_all_button')));
    await tester.pumpAndSettle();
    expect(port.exportAllCalls, 1);
    expect(message(), contains('已导出全部日历'));
  });

  // TC-CAL-UI-161（#607 档 A 第六批）：导入入口真把 .ics 递给导入 API。
  // 台账那句「调用导入 API 后月视图出现事件」里，月视图那半属于服务端落库 +
  // 下一次 pull，fake 端口造不出来（也不该在单测里打真网络）；本包能量的是入口这一手：
  // 粘的内容原样进 importIcs 的 bytes、空内容不发请求（发一个空 body 上去，
  // 服务端只会回一个看不懂的错，用户体验是「点了没反应」）。
  testWidgets('TC-CAL-UI-161 导入入口：空内容不发请求，粘贴后按原样提交 .ics', (tester) async {
    port.calendars = [
      {'id': 7, 'title': '工作', 'kind': 'LOCAL'},
    ];
    await pumpPage(tester, tab: 2);
    await tester.pumpAndSettle();

    String message() => tester
        .widget<Text>(find.byKey(const Key('calendar_cloud_message')))
        .data!;

    // 半边①：空输入 → 零调用 + 提示先粘贴
    await tester.tap(find.byKey(const Key('import_ics_button')));
    await tester.pumpAndSettle();
    expect(port.imports, isEmpty, reason: '空内容也发请求 = 把空 body 推给服务端');
    expect(message(), contains('请先粘贴'));

    // 半边②：粘进 ICS → 参数与字节都要对得上
    const ics = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR\n';
    await tester.enterText(find.byKey(const Key('import_ics_input')), ics);
    await tester.tap(find.byKey(const Key('import_ics_button')));
    await tester.pumpAndSettle();

    expect(port.imports, hasLength(1));
    final (calendarId, filename, bytes) = port.imports.single;
    expect(filename, 'import.ics');
    expect(bytes, ics.codeUnits, reason: '提交出去必须就是粘进来的那段');
    expect(message(), contains('已提交导入'));
    // 当前导入走「导入到默认位置」：calendarId 传 0 由服务端落进可用日历。
    expect(calendarId, 0);
  });

  testWidgets('#604 导出失败给友好文案，不回显异常类名（沿用 #165 约束）', (tester) async {
    port.calendars = [
      {'id': 7, 'title': '工作', 'kind': 'LOCAL'},
    ];
    port.exportError = CalendarSyncException('导出失败', statusCode: 502);
    await pumpPage(tester, tab: 2);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export_calendar_7')));
    await tester.pumpAndSettle();

    expect(find.text('暂时不可用，请稍后重试'), findsOneWidget);
    expect(find.textContaining('CalendarSyncException'), findsNothing);
    expect(find.textContaining('502'), findsNothing);
  });

  // parity#618：这两个按钮此前是裸 await——端口抛错时整条 handler 崩，
  // 界面停在上一句消息上，用户看到的「点了没反应」就是这么来的。
  testWidgets('#618 生成导出链接失败给友好文案，不回显异常类名', (tester) async {
    port.feedError = CalendarSyncException('链接生成失败', statusCode: 500);
    await pumpPage(tester, tab: 2);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export_feed_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('暂时不可用，请稍后重试'),
      findsOneWidget,
      reason: '抛错要落到页内消息，不能只留在日志里',
    );
    expect(find.textContaining('CalendarSyncException'), findsNothing);
    expect(find.textContaining('500'), findsNothing);
    expect(
      find.text('导出链接不可用'),
      findsNothing,
      reason: '那是「已登录但服务端没给链接」的另一档，不能被失败兜底蹭用',
    );
  });

  testWidgets('#618 导入抛错给友好文案，且不许报「已提交导入」', (tester) async {
    port.importError = CalendarSyncException('导入被拒', statusCode: 502);
    await pumpPage(tester, tab: 2);
    await tester.pumpAndSettle();

    const ics = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR\n';
    await tester.enterText(find.byKey(const Key('import_ics_input')), ics);
    await tester.tap(find.byKey(const Key('import_ics_button')));
    await tester.pumpAndSettle();

    final message = tester
        .widget<Text>(find.byKey(const Key('calendar_cloud_message')))
        .data!;
    expect(message, contains('暂时不可用'));
    expect(
      message,
      isNot(contains('已提交导入')),
      reason: '请求根本没被接受，报「已提交」是把失败说成成功',
    );
    expect(port.imports, isEmpty, reason: '抛错档不该留下一条成功记录');
    expect(find.textContaining('CalendarSyncException'), findsNothing);
  });

  // parity#165：未登录（401）不得回显内部异常类名，给面向用户的未登录说明
  testWidgets('#165 未登录收件箱显示友好文案，不暴露异常类名', (tester) async {
    port.inboxError = CalendarSyncException('未登录', statusCode: 401);
    await pumpPage(tester);

    expect(find.text('收件箱登录后可查看（当前未登录）'), findsOneWidget);
    expect(
      find.textContaining('CalendarSyncException'),
      findsNothing,
      reason: '#165: 不得回显异常类型名与状态码',
    );
  });
}

class _CollabPort implements CalendarCollabPort {
  List<Map<String, dynamic>> inbox = [];
  List<Map<String, dynamic>> calendars = [];
  final List<(int, bool)> responded = [];
  CalendarSyncException? inboxError;
  int? defaultSet;
  int exportAllCalls = 0;
  final List<(int, String, List<int>)> imports = [];
  String ics = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR';
  CalendarSyncException? exportError;
  CalendarSyncException? feedError;
  CalendarSyncException? importError;

  @override
  Future<List<Map<String, dynamic>>> inboxList() async {
    final err = inboxError;
    if (err != null) {
      throw err;
    }
    return inbox;
  }

  @override
  Future<void> respondShare(int shareId, {required bool accept}) async {
    responded.add((shareId, accept));
  }

  @override
  Future<List<Map<String, dynamic>>> calendarList() async => calendars;

  @override
  Future<String?> exportFeedUrl(int? calendarId) async {
    final err = feedError;
    if (err != null) {
      throw err;
    }
    return 'https://example.com/feed.ics';
  }

  @override
  Future<void> importIcs({
    required int calendarId,
    required String filename,
    required List<int> bytes,
  }) async {
    final err = importError;
    if (err != null) {
      throw err;
    }
    imports.add((calendarId, filename, bytes));
  }

  @override
  Future<void> setDefaultCalendar(int calendarId) async {
    defaultSet = calendarId;
  }

  @override
  Future<String> exportCalendarIcs(int calendarId) async {
    final err = exportError;
    if (err != null) {
      throw err;
    }
    return ics;
  }

  @override
  Future<String> exportAllIcs() async {
    exportAllCalls++;
    final err = exportError;
    if (err != null) {
      throw err;
    }
    return ics;
  }

  @override
  Future<int> duplicateEvent(
    int eventId, {
    required DateTime newStartAt,
  }) async => 99;
}
