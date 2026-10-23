import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #3 · kernel 与服务端契约对齐（M2）
/// TC-KR-107：服务端 ID 映射字段（remoteId，Spec 028 临时 ID 映射的本地侧）；
/// TC-KR-108：回收窗字段（deletedAt）与完成时间（completedAt）；
/// TC-KR-109：分区归属（sectionId，A15 手动分区）；
/// TC-KR-110：优先级映射编解码（FL 0/1/5/9 ↔ 服务端 0/1/2/3，M1 冻结口径）。
void main() {
  group('TC-KR-107 remoteId 服务端 ID 映射字段', () {
    test('默认 null；copyWith 可写入/清除', () {
      const item = ReminderItem(id: 'local-1', listId: 'l1', title: 't');
      expect(item.remoteId, isNull);

      final bound = item.copyWith(remoteId: 'srv-42');
      expect(bound.remoteId, 'srv-42');

      expect(bound.copyWith(remoteId: ReminderItem.clear).remoteId, isNull);
      expect(bound.copyWith().remoteId, 'srv-42'); // 不传保持
    });

    test('参与相等性', () {
      const a = ReminderItem(id: '1', listId: 'l', title: 't');
      final b = a.copyWith(remoteId: 'srv-1');
      expect(a, isNot(b));
    });
  });

  group('TC-KR-108 completedAt / deletedAt 契约字段', () {
    test('默认 null；copyWith 哨兵三态', () {
      const item = ReminderItem(id: '1', listId: 'l', title: 't');
      final now = DateTime.utc(2026, 10, 24, 1, 0);

      final done = item.copyWith(isCompleted: true, completedAt: now);
      expect(done.completedAt, now);

      final recycled = done.copyWith(deletedAt: now);
      expect(recycled.deletedAt, now);

      expect(recycled.copyWith(completedAt: ReminderItem.clear).completedAt,
          isNull);
      expect(recycled.copyWith(deletedAt: ReminderItem.clear).deletedAt, isNull);
      expect(recycled.copyWith().completedAt, now); // 不传保持
    });
  });

  group('TC-KR-109 sectionId 分区归属', () {
    test('默认 null；copyWith 写入/清除（移动列表时应清空）', () {
      const item = ReminderItem(id: '1', listId: 'l', title: 't');
      final sectioned = item.copyWith(sectionId: 'sec-1');
      expect(sectioned.sectionId, 'sec-1');
      expect(sectioned.copyWith(sectionId: ReminderItem.clear).sectionId,
          isNull);
    });
  });

  group('TC-KR-110 优先级映射编解码（FL ↔ 服务端）', () {
    test('FL 0/1/5/9 ↔ 服务端 0/1/2/3 双向', () {
      expect(ReminderPriorityCodec.toServer(0), 0);
      expect(ReminderPriorityCodec.toServer(1), 1);
      expect(ReminderPriorityCodec.toServer(5), 2);
      expect(ReminderPriorityCodec.toServer(9), 3);

      expect(ReminderPriorityCodec.fromServer(0), 0);
      expect(ReminderPriorityCodec.fromServer(1), 1);
      expect(ReminderPriorityCodec.fromServer(2), 5);
      expect(ReminderPriorityCodec.fromServer(3), 9);
    });

    test('未知值兜底：越界服务端值按 0（无）处理；越界 FL 值按 0 上送', () {
      expect(ReminderPriorityCodec.fromServer(7), 0);
      expect(ReminderPriorityCodec.fromServer(-1), 0);
      expect(ReminderPriorityCodec.toServer(42), 0);
    });

    test('编解码往返不损失语义档位', () {
      for (final fl in [0, 1, 5, 9]) {
        expect(ReminderPriorityCodec.fromServer(
            ReminderPriorityCodec.toServer(fl)), fl);
      }
    });
  });
}
