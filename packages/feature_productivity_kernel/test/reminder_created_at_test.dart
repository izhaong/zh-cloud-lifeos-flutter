import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apple 提醒事项「按创建日期」档的数据源契约（flutter #278，前置 service #539）。
///
/// 创建时间是服务端插入时刻：入站必须读得到、出站不许回传覆盖、
/// 本地编辑（copyWith 全量回写）不得把它抹平。
void main() {
  final created = DateTime(2026, 10, 20, 9, 30);
  final createdMilli = created.millisecondsSinceEpoch;

  ReminderItem base({DateTime? createdAt}) => ReminderItem(
    id: 't1',
    listId: 'list.a',
    title: '买牛奶',
    createdAt: createdAt,
  );

  ReminderItem decode(Map<String, dynamic> payload, {ReminderItem? existing}) =>
      reminderItemFromSyncPayload(
        payload,
        entityId: 't1',
        listId: 'list.a',
        existing: existing,
      );

  test('入站：createTime（camel）与 create_time（snake）都读得到', () {
    final camel = decode({'title': '买牛奶', 'createTime': createdMilli});
    expect(camel.createdAt, created);
    final snake = decode({'title': '买牛奶', 'create_time': createdMilli});
    expect(snake.createdAt, created);
  });

  test('入站缺键：保留本地已有创建时间，不抹成 null', () {
    final kept = decode({'title': '改名'}, existing: base(createdAt: created));
    expect(kept.createdAt, created);
    // 首次落库且服务端没给（老数据）⇒ null，排序时该行走「排最后」分支
    expect(decode({'title': '改名'}).createdAt, isNull);
  });

  test('入站给的新值覆盖本地（服务端权威）', () {
    final older = DateTime(2020, 1, 1);
    final overridden = decode({
      'title': '买牛奶',
      'createTime': createdMilli,
    }, existing: base(createdAt: older));
    expect(overridden.createdAt, created);
  });

  test('出站：payload 不回传创建时间（服务端插入时刻唯一）', () {
    expect(
      taskSyncPayload(base(createdAt: created)),
      isNot(contains('createTime')),
    );
    expect(
      taskSyncPayload(base(createdAt: created)),
      isNot(contains('create_time')),
    );
  });

  test('copyWith 全量回写不改写、也不抹平创建时间', () {
    expect(base(createdAt: created).copyWith(title: '改名').createdAt, created);
    expect(base().copyWith(title: '改名').createdAt, isNull);
  });

  test('createdAt 进 Equatable：只有创建时间不同即判不等', () {
    expect(base(createdAt: created), isNot(base()));
  });
}
