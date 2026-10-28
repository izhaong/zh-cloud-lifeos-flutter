import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';

import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-UI-120 持久半边：任务偏好一域一行、revision 由仓库递增、无行回契约默认
/// （flutter#124 卡 4；照 lifeos/calendar 的 CalendarPreferences 先例）。
void main() {
  late LifeProductivityDb db;
  late DriftTaskPreferenceRepository repo;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    repo = DriftTaskPreferenceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('V13：任务偏好表随 schemaVersion 13 建表', () async {
    expect(db.schemaVersion, 16);
    final names = (await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ).get()).map((r) => r.read<String>('name')).toSet();
    expect(names.contains('task_preferences'), isTrue);
  });

  test('无行时回契约默认（全天提醒开、完成标记关、建议列表开、默认列表未设）',
      () async {
    final p = await repo.watchPreference().first;
    expect(p, TaskPreference.defaults);
    expect(p.allDayNotify, isTrue);
    expect(p.markComplete, isFalse);
    expect(p.suggestLists, isTrue);
    expect(p.defaultListId, isNull);
  });

  test('保存后回读新值、revision 递增、仍只有一行', () async {
    await repo.savePreference(const TaskPreference(
      defaultListId: 'list.work',
      allDayNotify: false,
      markComplete: true,
      suggestLists: false,
    ));

    final saved = await repo.watchPreference().first;
    expect(saved.defaultListId, 'list.work');
    expect(saved.allDayNotify, isFalse);
    expect(saved.markComplete, isTrue);
    expect(saved.suggestLists, isFalse);
    expect(saved.revision, 1, reason: '首存 = 空行 0 + 1（日历先例同口径）');

    await repo.savePreference(saved.copyWith(allDayNotify: true));
    final again = await repo.watchPreference().first;
    expect(again.revision, 2);
    expect(again.allDayNotify, isTrue);
    expect(again.defaultListId, 'list.work', reason: '没改的字段保持');

    final rows = await db.select(db.taskPreferences).get();
    expect(rows, hasLength(1), reason: '一个本地用户一行，重放覆盖不追加');
  });

  test('还原=写回 defaults：三档回默认、默认列表清空', () async {
    await repo.savePreference(const TaskPreference(
        defaultListId: 'list.work',
        allDayNotify: false,
        markComplete: true,
        suggestLists: false));

    await repo.savePreference(TaskPreference.defaults);

    final back = await repo.watchPreference().first;
    expect(back.defaultListId, isNull, reason: '「还原」要能把默认列表也清回未设');
    expect(back.allDayNotify, isTrue);
    expect(back.markComplete, isFalse);
    expect(back.suggestLists, isTrue);
    expect(back.revision, 2, reason: '还原也是一次保存（revision 由仓库接管）');
  });

  test('视图态四列（显示已完成/排序/侧栏/折叠键）落库并原样读回', () async {
    await repo.savePreference(const TaskPreference(
      showCompleted: true,
      sortMode: 'title',
      sidebarVisible: false,
      collapsedKeys: ['list.work|今天', 'group:个人'],
    ));

    final back = await repo.watchPreference().first;
    expect(back.showCompleted, isTrue);
    expect(back.sortMode, 'title');
    expect(back.sidebarVisible, isFalse);
    expect(back.collapsedKeys, ['list.work|今天', 'group:个人'],
        reason: '折叠键是 JSON 数组列，读写要保序且带列表前缀');
  });

  test('损坏的折叠键 JSON 按「没有折叠」处理，不炸整行', () async {
    // 直接写脏字节（不走 companion：它没进包出口，也不该为一条测试放开）
    await db.customUpdate(
      'INSERT INTO task_preferences (user_key, collapsed_keys_json) VALUES (?, ?)',
      variables: [
        const Variable<String>('local'),
        const Variable<String>('不是 JSON'),
      ],
    );
    final back = await repo.watchPreference().first;
    expect(back.collapsedKeys, isEmpty);
    expect(back.showCompleted, isFalse, reason: '其它列走默认值，界面仍可渲染');
  });

  test('写一次就广播新值（设置弹层不手动 reload）', () async {
    final values = <bool>[];
    final done = Future<void>(() async {
      while (values.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final sub = repo.watchPreference().listen((p) => values.add(p.markComplete));
    await repo.savePreference(const TaskPreference(markComplete: true));
    await done.timeout(const Duration(seconds: 5));
    await sub.cancel();

    expect(values, [false, true]);
  });
}
