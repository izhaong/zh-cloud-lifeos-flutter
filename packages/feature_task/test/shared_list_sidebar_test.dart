import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #599/#600 的共享清单消费面。
///
/// `_Shell` 复刻 `task_scaffold.dart` 里 `_SharedOrEmptyPane` 的判定：
/// 两侧读的是同一个 `sharedListByIdProvider`，所以「摘掉可见性判断 ⇒ 用例红」
/// 这条反向探针落在 provider 上，而不是落在一份测试专用的复制逻辑上。
class _Shell extends ConsumerStatefulWidget {
  const _Shell({required this.onSharedTap, this.sharedId});

  /// 断言「点得进」：侧栏行的回调。
  final ValueChanged<TaskSharedList> onSharedTap;

  /// 初始打开的清单 id（测试用它模拟「已经点进共享清单」）。
  final String? sharedId;

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  late String? _openId = widget.sharedId;

  @override
  Widget build(BuildContext context) {
    final lists =
        ref.watch(reminderListsProvider).asData?.value ?? const <ReminderList>[];
    final openId = _openId;
    final shared = openId == null ? null : ref.watch(sharedListByIdProvider(openId));
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 320,
              height: 760,
              child: TaskSidebar(
                lists: lists,
                selectedListId: _openId,
                onSelect: (l) => setState(() => _openId = l.id),
                onSelectSharedList: (s) {
                  widget.onSharedTap(s);
                  setState(() => _openId = s.listId);
                },
              ),
            ),
            Expanded(
              child: shared == null
                  ? const Center(child: Text('EMPTY'))
                  : SharedListPane(
                      key: ValueKey('shared_view_${shared.listId}'),
                      list: shared,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakePort implements TaskCollabPort {
  _FakePort({this.shared = const [], this.throwOnShared = false});

  final List<TaskSharedList> shared;
  final bool throwOnShared;
  int sharedTasksCalls = 0;

  @override
  Future<String?> whoAmI() async => '1001';

  @override
  Future<List<TaskListMember>> listMembers(String listId) async => const [];

  @override
  Future<String> resolveUserByMobile(String mobile) async => '2002';

  @override
  Future<void> inviteMembers(
    String listId, {
    required List<String> userIds,
    required String role,
  }) async {}

  @override
  Future<void> updateMemberRole(
    String listId,
    String userId,
    String role,
  ) async {}

  @override
  Future<void> removeMember(String listId, String userId) async {}

  @override
  Future<void> joinList(String listId) async {}

  @override
  Future<void> exitList(String listId) async {}

  @override
  Future<List<TaskSharedList>> mySharedLists() async {
    if (throwOnShared) throw TaskCollabException('未登录');
    return shared;
  }

  @override
  Future<List<TaskSharedItem>> sharedListTasks(
    String listId, {
    bool includeCompleted = false,
  }) async {
    sharedTasksCalls++;
    return const [
      TaskSharedItem(id: '5001', listId: '9001', title: '共享里的买牛奶'),
      TaskSharedItem(
        id: '5002',
        listId: '9001',
        title: '共享里已完成的',
        completed: true,
      ),
    ];
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required TaskCollabPort? port,
  ValueChanged<TaskSharedList>? onSharedTap,
  String? sharedId,
}) async {
  final repo = InMemoryReminderRepository(seedSampleData: false);
  await repo.upsertList(
    const ReminderList(id: 'list.own', title: '我的清单', colorArgb: 0xFF34C759),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        taskCollabPortProvider.overrideWithValue(port),
      ],
      child: _Shell(
        onSharedTap: onSharedTap ?? (_) {},
        sharedId: sharedId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('有共享数据 ⇒ 侧栏出现「与我共享」行，副标题带角色', (tester) async {
    await _pump(
      tester,
      port: _FakePort(
        shared: const [
          TaskSharedList(
            listId: '9001',
            name: '团队排班',
            ownerUserId: '2002',
            role: 'viewer',
          ),
        ],
      ),
    );

    expect(find.byKey(const ValueKey('sidebar_shared_9001')), findsOneWidget);
    expect(find.text('与我共享'), findsOneWidget);
    // 角色用同一份口径（ListShareSheet 的「仅查看」），不再各写一套中文。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar_shared_9001')),
        matching: find.text('仅查看'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('点共享行 ⇒ 进得去：只读视图渲染服务端条目（#599 判据 2 / #600 判据 1）',
      (tester) async {
    TaskSharedList? tapped;
    final port = _FakePort(
      shared: const [
        TaskSharedList(
          listId: '9001',
          name: '团队排班',
          ownerUserId: '2002',
          role: 'editor',
        ),
      ],
    );
    await _pump(tester, port: port, onSharedTap: (s) => tapped = s);

    await tester.tap(find.byKey(const ValueKey('sidebar_shared_9001')));
    await tester.pumpAndSettle();

    expect(tapped?.listId, '9001');
    expect(find.byKey(const ValueKey('shared_view_9001')), findsOneWidget);
    expect(find.byKey(const ValueKey('shared_item_5001')), findsOneWidget);
    expect(find.text('共享里的买牛奶'), findsOneWidget);
    // 读的是直连通道，不是本地 Drift 流。
    expect(port.sharedTasksCalls, 1);
  });

  testWidgets('端口抛错 ⇒ 整节不显示，也不报「加载失败」噪声（#599 判据 3）',
      (tester) async {
    await _pump(tester, port: _FakePort(throwOnShared: true));

    expect(find.text('与我共享'), findsNothing);
    expect(find.byKey(const ValueKey('sidebar_shared_9001')), findsNothing);
    expect(find.text('读不到这张共享清单'), findsNothing);
  });

  testWidgets('端口为 null（离线/未登录）⇒ 整节不显示', (tester) async {
    await _pump(tester, port: null);
    expect(find.byKey(const ValueKey('sidebar_shared_9001')), findsNothing);
  });

  testWidgets('仅查看角色：只读视图里没有任何可写入口（#600 判据 3）',
      (tester) async {
    await _pump(
      tester,
      port: _FakePort(
        shared: const [
          TaskSharedList(
            listId: '9001',
            name: '团队排班',
            ownerUserId: '2002',
            role: 'viewer',
          ),
        ],
      ),
      sharedId: '9001',
    );

    expect(find.byKey(const ValueKey('shared_readonly_badge')), findsOneWidget);
    expect(find.text('只读 · 仅查看'), findsOneWidget);
    // 可写入口的三种形状：新建输入框、「新提醒事项」文案、任何可点的按钮。
    expect(find.byType(CupertinoTextField), findsNothing);
    expect(find.text('新提醒事项'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shared_view_9001')),
        matching: find.byType(CupertinoButton),
      ),
      findsNothing,
    );
  });

  testWidgets('反向探针：不在共享册里的 id 不得渲染成共享视图（#600 判据 4）',
      (tester) async {
    // 摘掉 sharedListByIdProvider 里的 listId 过滤，这条当场红。
    await _pump(
      tester,
      port: _FakePort(
        shared: const [
          TaskSharedList(
            listId: '9001',
            name: '团队排班',
            ownerUserId: '2002',
            role: 'viewer',
          ),
        ],
      ),
      sharedId: 'list.own',
    );

    expect(find.text('EMPTY'), findsOneWidget);
    expect(find.byKey(const ValueKey('shared_view_list.own')), findsNothing);
    expect(find.byType(SharedListPane), findsNothing);
  });
}
