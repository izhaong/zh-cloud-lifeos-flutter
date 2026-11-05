import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-KR-112：标签存储序列化一致性（InMemory ≡ Drift）。
///
/// 真实策略：存储层是 verbatim 透传——[DriftReminderRepository] 的
/// `_encodeTags` 直接 `jsonEncode(tags)`，[InMemoryReminderRepository] 原样持有，
/// 两端都不做去重或空串过滤（去重/空串归一在输入边界 UI 完成）。
/// 本测试钉住「同一 tags 载荷在两端落库结果完全一致」，即序列化/反序列化
/// 行为对齐，避免某一端悄悄改写在两侧出现分歧。
void main() {
  late LifeProductivityDb db;
  late DriftReminderRepository drift;
  late InMemoryReminderRepository memory;

  setUp(() {
    db = LifeProductivityDb(NativeDatabase.memory());
    drift = DriftReminderRepository(db);
    memory = InMemoryReminderRepository();
  });

  tearDown(() async {
    await db.close();
  });

  Future<(List<String>, List<String>)> roundtripBoth(
    List<String> tags,
  ) async {
    const listId = 'list.t';
    await drift.upsertList(const ReminderList(id: listId, title: 't'));
    await memory.upsertList(const ReminderList(id: listId, title: 't'));
    await drift.upsertItem(
      ReminderItem(id: 'i', listId: listId, title: 'x', tags: tags),
    );
    await memory.upsertItem(
      ReminderItem(id: 'i', listId: listId, title: 'x', tags: tags),
    );
    final d = (await drift.watchItems(listId: listId).first).single;
    final m = (await memory.watchItems(listId: listId).first).single;
    return (d.tags, m.tags);
  }

  test('普通多标签两端一致', () async {
    final (d, m) = await roundtripBoth(['工作', '设计']);
    expect(d, ['工作', '设计'], reason: 'drift 原样落库');
    expect(m, ['工作', '设计'], reason: 'memory 原样持有');
    expect(d, m, reason: 'InMemory ≡ Drift');
  });

  test('含空串与重复的两端一致（存储层不自行去重）', () async {
    final (d, m) = await roundtripBoth(['工作', '', '工作']);
    expect(d, ['工作', '', '工作'], reason: 'drift verbatim');
    expect(m, ['工作', '', '工作'], reason: 'memory verbatim');
    expect(d, m, reason: 'InMemory ≡ Drift');
  });

  test('空标签列表两端一致', () async {
    final (d, m) = await roundtripBoth([]);
    expect(d, isEmpty);
    expect(m, isEmpty);
    expect(d, m, reason: 'InMemory ≡ Drift');
  });
}
