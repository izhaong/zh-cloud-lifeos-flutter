import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-KR-116：本地 id 工厂不携带服务端整数语义。
/// TC-KR-117：智能列表与普通列表同表，删除智能列表不级联源提醒。
void main() {
  test('TC-KR-116 本地 id 用 rem_/list_ 前缀，不是服务端数字 id', () {
    final itemId = newReminderId();
    final listId = newListId();

    expect(itemId, startsWith('rem_'));
    expect(listId, startsWith('list_'));
    expect(int.tryParse(itemId), isNull);
    expect(int.tryParse(listId), isNull);
  });

  test('TC-KR-117 删除智能列表不带走普通列表里的提醒', () async {
    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.personal', title: '个人', isSmart: false),
    );
    await repo.upsertItem(
      const ReminderItem(id: 'i1', listId: 'list.personal', title: '买牛奶'),
    );

    await repo.deleteList('smart.today');

    final lists = await repo.watchLists().first;
    expect(lists.any((list) => list.id == 'smart.today'), isFalse);
    expect(lists.any((list) => list.id == 'list.personal'), isTrue);
    final items = await repo.watchItems(listId: 'list.personal').first;
    expect(items.map((item) => item.title), ['买牛奶']);
  });
}
