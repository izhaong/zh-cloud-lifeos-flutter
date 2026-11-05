// TC-CAL-UI-203（#616）：列表档得有一扇能点到的门。
//
// 列表视图本身在 #399 就被证过（test/list_view_test.dart 四条），但生产侧两个档位
// 切换器——宽档的 _ViewSegment、紧凑档的 _CompactViewModeMenu——的 modes 里都没有
// CalendarViewMode.list，全仓也没有一处 viewModeProvider.notifier.set(list)。
// 唯一进得去的路径是 CalendarScaffold(pinnedViewMode: list)，而那只被测试用过：
// 一座没有门的房间。本文件只钉入口，不重证列表渲染面。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// 档位入口的 Key：宽档挂在段控件的第 5 格，紧凑档挂在菜单项上
/// （两处互斥渲染，find.byKey 在任一档都只命中一个）。
const _listEntry = Key('calendar_view_mode_list');

void main() {
  late ProviderContainer container;

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
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
        // 挂钟与锚点一起钉在 10/29，用例不随执行日期飘。
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 9)),
      ],
    );
    addTearDown(container.dispose);
    container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 29));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // 不传 pinnedViewMode：生产侧从不传（全仓 grep 只有测试在用），
        // 而它一旦传了就把档位钉死（calendar_scaffold.dart:39 是
        // `pinnedViewMode ?? watch(viewModeProvider)`），入口点下去档位会变、
        // 视图却不动——那不是本单要证的「可达路径」。钉死这件事是 #628。
        child: lifeTestHost(const CalendarScaffold()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 段控件当前选中档；紧凑档不渲染段控件，返回 null。
  CalendarViewMode? segmentGroupValue(WidgetTester tester) {
    final finder = find.byWidgetPredicate(
      (widget) => widget is CupertinoSlidingSegmentedControl<CalendarViewMode>,
    );
    if (finder.evaluate().isEmpty) {
      return null;
    }
    return (tester.widget(finder)
            as CupertinoSlidingSegmentedControl<CalendarViewMode>)
        .groupValue;
  }

  testWidgets('TC-CAL-UI-203 宽档：段控件切到列表再切回日，同一天的数据两种排法', (tester) async {
    await pumpAt(tester, const Size(1000, 800));

    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);
    expect(segmentGroupValue(tester), CalendarViewMode.day);

    await tester.tap(find.byKey(_listEntry));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar_list_view')),
      findsOneWidget,
      reason: '入口点了没换档 = 门是画的',
    );
    expect(
      find.byKey(const Key('calendar_day_view')),
      findsNothing,
      reason: '切过去后日轴须卸掉，否则两条时间轴同时在树里',
    );
    expect(find.text('晨会'), findsOneWidget, reason: '同一条日程要在列表里');
    expect(segmentGroupValue(tester), CalendarViewMode.list);

    // 点回来：段控件里的「日」格（作用域切进工具栏，避免撞上侧栏月历的星期头）
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('calendar_toolbar')),
        matching: find.text('日'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);
    expect(find.text('晨会'), findsOneWidget, reason: '回到日轴后事件卡须在');
    expect(segmentGroupValue(tester), CalendarViewMode.day);
  });

  testWidgets('TC-CAL-UI-203 紧凑档：视图菜单里有列表项，点得下去', (tester) async {
    await pumpAt(tester, const Size(375, 800));

    expect(segmentGroupValue(tester), isNull, reason: '紧凑档本就没有段控件');
    expect(find.byKey(const Key('calendar_day_view')), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar_view_mode_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(_listEntry), findsOneWidget, reason: '菜单里没有这一档');

    await tester.tap(find.byKey(_listEntry));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar_list_view')), findsOneWidget);
    expect(find.text('晨会'), findsOneWidget);
    expect(container.read(viewModeProvider), CalendarViewMode.list);
  });

  // 设计不变量：入口的可见标记是图标，不是「列表」二字。
  // 既有两条契约用例（calendar_shell_test TC-CAL-UI-001、list_view_test #399）拿
  // find.text('列表') 的**缺席**当判据（前者判「不在任务列表页」，后者判「占位符没回来」）；
  // 常驻工具栏里再放一份「列表」会把这两条判据同时作废。故宽档只挂图标 + 语义标签。
  testWidgets('不变量：工具栏不常驻「列表」二字（既有两条缺席判据要留着有效）', (tester) async {
    await pumpAt(tester, const Size(1000, 800));

    expect(
      find.descendant(
        of: find.byKey(const Key('calendar_toolbar')),
        matching: find.text('列表'),
      ),
      findsNothing,
    );
    // 但读屏要能读出这一格是什么。
    expect(find.byKey(_listEntry), findsOneWidget);
  });
}

class _Repo implements CalendarRepository {
  _Repo({required this.events});

  final List<CalendarEvent> events;
  final List<Calendar> calendars = const [
    Calendar(id: 'c1', title: '工作', colorArgb: 0xFF007AFF),
  ];

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(calendars);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) =>
      Stream.value(
        events.where((e) => !e.startAt.isBefore(from) && e.startAt.isBefore(to)).toList(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
