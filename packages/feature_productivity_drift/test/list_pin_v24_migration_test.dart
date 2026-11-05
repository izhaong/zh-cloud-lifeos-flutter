// #563：清单置顶从「本机视图态键袋」升成 `reminder_lists.is_pinned`（V24）。
//
// 这条迁移唯一的风险是**老用户升级后置顶掉了**——他们以前置顶过，键就躺在
// `task_preferences.collapsed_keys_json` 里。所以这里量三件事：
// ① 袋里每条 `pinned:<listId>` 都写进了对应那一行；
// ② 写完要把袋里那批键删掉（两处真相源迟早打架），但别的键必须原样留着；
// ③ 指向不存在清单的幽灵键不能把整库升级搞挂。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<LifeProductivityDb> openV23WithBag(String bagJson) async {
    final dir = await Directory.systemTemp.createTemp('fl563_v24');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/legacy_v23.db');

    // 先用 V24 的类把全表建好，再拔掉本轮新增的列、把 user_version 压回 23，
    // 这样重开时走的是真实的 from=23 → to=24 路径（同仓 v6/v10 迁移测试的配方）。
    final seed = LifeProductivityDb(NativeDatabase(file));
    await seed
        .into(seed.reminderLists)
        .insert(ReminderListsCompanion.insert(id: 'list.a', title: '甲'));
    await seed
        .into(seed.reminderLists)
        .insert(ReminderListsCompanion.insert(id: 'list.c', title: '丙'));
    await seed.customStatement(
      'INSERT INTO task_preferences (user_key, collapsed_keys_json) VALUES (?, ?)',
      ['local', bagJson],
    );
    await seed.customStatement(
      'ALTER TABLE reminder_lists DROP COLUMN is_pinned',
    );
    await seed.customStatement('PRAGMA user_version = 23');
    await seed.close();

    final db = LifeProductivityDb(NativeDatabase(file));
    addTearDown(db.close);
    // 首次查询才会真正触发 onUpgrade。
    await db.customSelect('SELECT 1').get();
    return db;
  }

  Future<List<String>> bagOf(LifeProductivityDb db) async {
    final pref = await DriftTaskPreferenceRepository(
      db,
    ).watchPreference().first;
    return pref.collapsedKeys;
  }

  test('#563 V24：袋里的 pinned:<id> 搬进 is_pinned，且袋里只剩别的键', () async {
    final db = await openV23WithBag(
      '["list.c|收件箱","pinned:list.c","view:subtasksHidden","pinned:list.a"]',
    );
    final repo = DriftReminderRepository(db);
    final lists = await repo.watchLists().first;

    expect(lists.where((e) => e.isPinned).map((e) => e.id).toSet(), {
      'list.a',
      'list.c',
    }, reason: '老用户以前置顶过几条，升级后就得还是几条');
    expect(await bagOf(db), [
      'list.c|收件箱',
      'view:subtasksHidden',
    ], reason: '分区折叠键与子任务显隐键不能被顺手清掉');
  });

  test('#563 V24：幽灵键（指向已删清单）不阻断升级，也不留残键', () async {
    final db = await openV23WithBag('["pinned:list.gone"]');
    final lists = await DriftReminderRepository(db).watchLists().first;
    expect(lists.where((e) => e.isPinned), isEmpty);
    expect(await bagOf(db), isEmpty, reason: '搬不动也要从袋里摘掉，否则两处真相');
  });

  test('#563 V24：没有置顶键的存量库，袋保持原样', () async {
    final db = await openV23WithBag('["list.a|收件箱"]');
    final lists = await DriftReminderRepository(db).watchLists().first;
    expect(lists.every((e) => !e.isPinned), isTrue);
    expect(await bagOf(db), [
      'list.a|收件箱',
    ], reason: '没有 pinned: 时不该重写这一列（连顺序都不该变）');
  });

  test('#563 全新库：is_pinned 默认 false', () async {
    final db = LifeProductivityDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.reminderLists)
        .insert(ReminderListsCompanion.insert(id: 'list.a', title: '甲'));
    final lists = await DriftReminderRepository(db).watchLists().first;
    // 仓库会派生内置智能清单，所以按 id 取而不是数总数。
    expect(
      lists.firstWhere((e) => e.id == 'list.a').isPinned,
      isFalse,
      reason: '新建列默认 false，升级不得凭空造出置顶',
    );
    expect(db.schemaVersion, 25);
  });

  test('#563 往返：经仓库写 isPinned 后重新打开库仍是 true', () async {
    final dir = await Directory.systemTemp.createTemp('fl563_roundtrip');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/rt.db');
    final db = LifeProductivityDb(NativeDatabase(file));
    final repo = DriftReminderRepository(db);
    await repo.upsertList(
      const ReminderList(id: 'list.c', title: '丙', sortOrder: 2),
    );
    final before = (await repo.watchLists().first).firstWhere(
      (e) => e.id == 'list.c',
    );
    await repo.upsertList(before.copyWith(isPinned: true));
    await db.close();

    final reopened = LifeProductivityDb(NativeDatabase(file));
    addTearDown(reopened.close);
    final after = (await DriftReminderRepository(
      reopened,
    ).watchLists().first).firstWhere((e) => e.id == 'list.c');
    expect(after.isPinned, isTrue, reason: '置顶必须是落库字段，不是内存里改一下');
  });
}
