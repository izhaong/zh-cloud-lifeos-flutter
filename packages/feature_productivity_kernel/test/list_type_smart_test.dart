import 'package:flutter_test/flutter_test.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// TC-UI-115 后端契约：列表类型（standard/grocery）与预设分区模板；
/// TC-UI-116 后端契约：自定义智能列表条件（smartFilter）。
void main() {
  group('TC-KR-120 列表类型与采购预设（kernel 契约）', () {
    test('ReminderList.listType 默认 standard；grocery 可建', () {
      const std = ReminderList(id: 'l1', title: '普通');
      expect(std.listType, ReminderListType.standard);

      const groc = ReminderList(
        id: 'l2',
        title: '采购',
        listType: ReminderListType.grocery,
      );
      expect(groc.listType, ReminderListType.grocery);
    });

    test('grocery 预设分区模板与服务端 TodoListDO 一致（8 项）', () {
      expect(groceryPresetSections.length, 8);
      expect(groceryPresetSections.first, '农产品');
      expect(groceryPresetSections.last, '日用品');
    });

    test('createGroceryList 预置分区元数据（sortOrder 连续）', () {
      final list = ReminderList.createGroceryList(
        id: 'l3',
        title: '周采购',
        colorArgb: 0xFF34C759,
      );
      expect(list.listType, ReminderListType.grocery);
      expect(list.sections.length, 8);
      expect(list.sections.first.title, '农产品');
      expect(list.sections.first.sortOrder, 0);
      expect(list.sections[7].sortOrder, 7);
    });
  });

  group('TC-KR-121 自定义智能列表（smartFilter 契约）', () {
    test('SmartListFilter 条件建模 + matches 命中', () {
      const filter = SmartListFilter(
        tagEquals: '工作',
        flaggedOnly: true,
      );
      const hit = ReminderItem(
        id: 'i1',
        listId: 'l1',
        title: '命中',
        isFlagged: true,
        tags: ['工作'],
      );
      final workTag = ['工作'];
      final miss1 = ReminderItem(
        id: 'i2',
        listId: 'l1',
        title: '无旗标',
        tags: workTag,
      );
      const miss2 = ReminderItem(
        id: 'i3',
        listId: 'l1',
        title: '无标签',
        isFlagged: true,
      );
      expect(filter.matches(hit), isTrue);
      expect(filter.matches(miss1), isFalse);
      expect(filter.matches(miss2), isFalse);
    });

    test('空条件 filter 命中全部未完成（对齐智能列表基线）', () {
      const filter = SmartListFilter();
      const a = ReminderItem(id: 'a', listId: 'l', title: 'A');
      const done = ReminderItem(
        id: 'b',
        listId: 'l',
        title: 'B',
        isCompleted: true,
      );
      expect(filter.matches(a), isTrue);
      expect(filter.matches(done), isFalse); // 已完成不进智能列表
    });
  });
}
