// #574：「显示 → 根据时间分组」——打开后「全部」列表从按清单分组改为按日期分组，
// 且开关写进 TaskPreference.viewOptionsJson（重启可读回）。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

final _now = DateTime(2026, 10, 31, 9);

Future<InMemoryReminderRepository> _seed() async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  repo.nowProvider = () => _now;
  await repo.upsertList(const ReminderList(id: 'list.a', title: '清单A'));
  await repo.upsertList(const ReminderList(id: 'list.b', title: '清单B'));
  await repo.upsertItem(ReminderItem(
    id: 'a1',
    listId: 'list.a',
    title: 'A今天',
    dueAt: DateTime(2026, 10, 31, 10),
  ));
  await repo.upsertItem(ReminderItem(
    id: 'b1',
    listId: 'list.b',
    title: 'B明天',
    dueAt: DateTime(2026, 11, 1, 10),
  ));
  return repo;
}

void main() {
  test('viewOptionsJson 读写往返，坏 JSON 回默认', () {
    const base = TaskPreference();
    expect(base.viewOptionBool('groupByTime'), isFalse);

    final on = base.withViewOptionBool('groupByTime', true);
    expect(on.viewOptionBool('groupByTime'), isTrue);
    // 再写另一个键时保留已有键
    final both = on.withViewOptionBool('viewMode', false);
    expect(both.viewOptionBool('groupByTime'), isTrue);
    expect(both.viewOptionBool('viewMode'), isFalse);

    const broken = TaskPreference(viewOptionsJson: '{oops');
    expect(broken.viewOptionBool('groupByTime'), isFalse);
    expect(
      broken.withViewOptionBool('groupByTime', true).viewOptionBool(
            'groupByTime',
          ),
      isTrue,
    );
  });

  testWidgets('「全部」默认按清单分组；打开根据时间分组后按日期分组（#574）', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final repo = await _seed();
    final prefs = InMemoryTaskPreferenceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          taskPreferenceRepositoryProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => _now),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'smart.all')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section_清单A')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_清单B')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_今天')), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskScaffold)),
    );
    container.read(groupByTimeProvider.notifier).toggle();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section_今天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_明天')), findsOneWidget);
    expect(find.byKey(const ValueKey('section_清单A')), findsNothing);
    expect(find.byKey(const ValueKey('section_清单B')), findsNothing);

    final saved = await prefs.watchPreference().first;
    expect(saved.viewOptionBool('groupByTime'), isTrue,
        reason: '开关必须落进本地偏好');
  });
}
