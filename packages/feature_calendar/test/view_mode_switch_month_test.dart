// #632：日档切月档时，月视图在 build 里同步 `replaceEvents`，
// 旧日视图的 kalender 子树刚被 deactivate、还没 dispose，它的监听器被同步唤起
// 后查祖先 ⇒ `Looking up a deactivated widget's ancestor is unsafe`。
//
// 本文件钉两件事：切档不许抛（宽档走 provider、紧凑档走菜单），
// 以及**装载没被挪丢**（月视图仍拿到当月 occurrence）。后者是前者的对照组——
// 「改成不装载」也能让第一条变绿，那不是修复。
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as kalender;

import 'support/life_test_app.dart';

void main() {
  late kalender.DefaultEventsController eventsController;

  Future<ProviderContainer> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    eventsController = kalender.DefaultEventsController();
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(
          _Repo(
            events: [
              CalendarEvent(
                id: 'e1',
                calendarId: 'c1',
                uid: 'e1',
                title: '晨会',
                startAt: DateTime(2026, 10, 29, 9, 30),
                endAt: DateTime(2026, 10, 29, 10, 30),
                timeZone: 'Asia/Shanghai',
                updatedAt: DateTime(2026, 10, 1),
              ),
            ],
          ),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 9)),
        kalenderEventsControllerProvider.overrideWithValue(eventsController),
      ],
    );
    addTearDown(container.dispose);
    container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 29));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // 不钉档：档位由 viewModeProvider 决定，切档才是生产路径（#628 改名后语义）。
        child: lifeTestHost(const CalendarScaffold()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// 控制器里当前的月视图 tile（`CalendarEventTile` 由 `occurrencesProvider` 产出）。
  List<CalendarEventTile> tiles() =>
      eventsController.events.whereType<CalendarEventTile>().toList();

  testWidgets('宽档：日→月切档不抛断言，月视图与事件装载都在（#632）', (tester) async {
    final container = await pump(tester, const Size(1000, 800));
    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: '起手（日档渲染）就该干净，否则下面的红不能归因给切档',
    );

    container.read(viewModeProvider.notifier).set(CalendarViewMode.month);
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: '旧日视图停用期间同步发控制器通知 ⇒ deactivated ancestor 断言',
    );
    expect(find.byKey(const Key('calendar_month_view')), findsOneWidget);
    expect(
      tiles().map((t) => t.title).toList(),
      ['晨会'],
      reason: '装载挪出 build 后事件不许丢（只断「不抛」会放过「干脆不装载」那种假修复）',
    );
  });

  testWidgets('宽档：月→日切回同样不抛（#632）', (tester) async {
    final container = await pump(tester, const Size(1000, 800));
    container.read(viewModeProvider.notifier).set(CalendarViewMode.month);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    container.read(viewModeProvider.notifier).set(CalendarViewMode.day);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '反向切档是同一条拆树路径');
    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);
  });

  testWidgets('紧凑档菜单点「月」：同样不抛，月条按契约让位（#632）', (tester) async {
    await pump(tester, const Size(375, 800));

    await tester.tap(find.byKey(const Key('calendar_view_mode_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar_view_mode_month')));
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'iPhone 用户每天走这条路，provider 直写只是它的副本',
    );
    expect(find.byKey(const Key('calendar_month_view')), findsOneWidget);
    expect(tiles().map((t) => t.title).toList(), ['晨会']);
    // 顺带把月档那一侧的挂载不变量接住（#631 的紧凑档用例只验了年档）：
    // 屏上已是整月网格，月条重复且白吃 52 高。
    expect(
      find.byKey(const Key('calendar_month_strip')),
      findsNothing,
      reason: '月档挂条 = 同一个月看两遍',
    );
  });
}

class _Repo implements CalendarRepository {
  _Repo({required this.events});

  final List<CalendarEvent> events;

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const []);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) => Stream.value(events);

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
