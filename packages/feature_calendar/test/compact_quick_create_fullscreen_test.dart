// TC-CAL-UI-204（#620）：iPhone 档点「＋」必须是全屏新建页，不是居中小对话框。
//
// 台账那句是「compact 点 + → 表单全屏，保存后回到日视图」。此前 compact 与
// medium/expanded 拿到的是同一个 `showCupertinoDialog` 居中小框
// （`widgets/quick_event_dialog.dart` 全程没有按尺寸分叉），所以这行不是「没测」，
// 是「做出来不是那个东西」。
//
// 本文件钉三条：① 375 下页路由全屏、居中小框不在树里（量矩形，不靠肉眼）；
// ② 保存后停在日视图且锚点落到被创建的那一天；③ medium 档的既有居中小框不被改坏。
import 'dart:async';

import 'package:feature_calendar/feature_calendar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

const _page = Key('quick_event_page');
const _dialog = Key('quick_event_dialog');
const _pane = Key('event_inspector_pane');

void main() {
  late _Repo repo;

  Future<ProviderContainer> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        calendarRepositoryProvider.overrideWithValue(repo),
        sidebarPrefsProvider.overrideWith((ref) => null),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 9)),
      ],
    );
    addTearDown(container.dispose);
    container.read(anchorDateProvider.notifier).set(DateTime(2026, 10, 29));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: lifeTestHost(const CalendarScaffold()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// ＋ → 新建日程（走生产入口，不直接调 showQuickEventDialog）。
  Future<void> openQuickCreate(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('quick_create_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_create_event')));
    await tester.pumpAndSettle();
  }

  testWidgets('375 档点「＋」：表单是全屏页路由，不是居中小框', (tester) async {
    await pumpAt(tester, const Size(375, 800));
    await openQuickCreate(tester);

    expect(
      find.byKey(_page),
      findsOneWidget,
      reason: 'TC-CAL-UI-204 期望的是全屏表单（顶部取消/完成，字段逐段铺开）',
    );
    expect(
      find.byKey(_dialog),
      findsNothing,
      reason: '居中小框是 compact 上的坏呈现，摘掉它才算做到',
    );
    // 量矩形而不是肉眼：页必须占满视口（居中小框只有几十到几百高）。
    final rect = tester.getRect(find.byKey(_page));
    expect(rect.height, greaterThanOrEqualTo(800 * 0.9));
    expect(rect.width, greaterThanOrEqualTo(375 * 0.9));
  });

  testWidgets('375 档保存后停在日视图，锚点是被创建的那一天', (tester) async {
    final container = await pumpAt(tester, const Size(375, 800));
    await openQuickCreate(tester);

    // 输入用绝对日期而不是「明天」：`showQuickEventDialog` 的解析基准是它自己的
    // `now ?? DateTime.now()`，而 `openQuickEvent` 没把 clockProvider 传进去，
    // 写「明天」会让本用例的真值挂在真实挂钟上（跑到午夜就漂一天）。
    // 解析基准不接 clockProvider 这件事本身另记（不影响本单要证的锚点行为）。
    await tester.enterText(
      find.byKey(const Key('quick_event_input')),
      '11月20日下午3点开会',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick_event_create')));
    await tester.pumpAndSettle();

    // 解析结果进编辑面（契约 §6 的快速解析在 iPhone 上没被砍掉）。
    expect(find.byKey(_pane), findsOneWidget);
    await tester.tap(find.byKey(const Key('event_inspector_save')));
    await tester.pumpAndSettle();

    expect(find.byKey(_pane), findsNothing, reason: '保存后关页');
    expect(repo.upserted, isNotEmpty, reason: '确实写进仓库了');
    expect(
      find.byKey(const Key('calendar_day_view')),
      findsOneWidget,
      reason: '「保存后回到日视图」= 档位不动（compact 打开时就是日档），不是被改成别的档',
    );
    final created = repo.upserted.last.startAt.toLocal();
    final anchor = container.read(anchorDateProvider);
    expect(
      [anchor.year, anchor.month, anchor.day],
      [created.year, created.month, created.day],
      reason: '锚点要落到被创建的那一天，否则看到的还是前一天',
    );
  });

  testWidgets('对照：medium 档点「＋」仍是居中小对话框（既有呈现没被改坏）', (tester) async {
    await pumpAt(tester, const Size(800, 900));
    await openQuickCreate(tester);

    expect(find.byKey(_dialog), findsOneWidget);
    expect(find.byKey(_page), findsNothing);
  });
}

class _Repo implements CalendarRepository {
  final List<CalendarEvent> upserted = [];

  final _events = StreamController<List<CalendarEvent>>.broadcast();

  @override
  Stream<List<Calendar>> watchCalendars() => Stream.value(const [
        Calendar(
          id: 'c1',
          title: '工作',
          colorArgb: 0xFF007AFF,
          isDefault: true,
        ),
      ]);

  @override
  Stream<List<CalendarEvent>> watchEvents({
    required DateTime from,
    required DateTime to,
    Set<String>? calendarIds,
  }) async* {
    yield List<CalendarEvent>.unmodifiable(upserted);
    yield* _events.stream;
  }

  @override
  Future<String> upsertEvent(
    CalendarEvent event, {
    EditScope scope = EditScope.all,
    DateTime? occurrenceStart,
  }) async {
    upserted.add(event);
    _events.add(List<CalendarEvent>.unmodifiable(upserted));
    return event.id;
  }

  @override
  Stream<CalendarPreference> watchPreference() =>
      Stream.value(const CalendarPreference());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
