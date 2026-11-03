import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/life_test_app.dart';

/// flutter#570：清单共享入口与成员表（矩阵行 25「共享列表（邀请/参与者）」的客户端半面）。
///
/// 端口用 fake：断言的是「谁看得见什么操作」这条边界，
/// 而不是网络形状（那由 feature_task_cloud 的契约测试钉）。
void main() {
  late InMemoryReminderRepository repo;
  late _FakePort port;

  Future<void> pump(
    WidgetTester tester, {
    TaskCollabPort? collab,
    bool withRemoteId = true,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          taskCollabPortProvider.overrideWithValue(collab),
        ],
        child: lifeTestHost(const TaskScaffold(openListId: 'list.work')),
      ),
    );
    await tester.pumpAndSettle();
    if (!withRemoteId) {
      // setUp 落的那条带 remoteId；这里覆盖成「本机新建、还没同步过」的形状
      await repo.upsertList(const ReminderList(id: 'list.work', title: '工作'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> openShare(WidgetTester tester, {bool settle = true}) async {
    await tester.tap(find.byKey(const ValueKey('list_more_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('共享…'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // 报错态下 members 仍为 null，加载指示是无限动画 ⇒ pumpAndSettle 永远不会收敛，
      // 只能手动过帧（这不是测试的将就，是「加载态动画会吞掉 settle 判据」这件事的实证）。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  setUp(() async {
    repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(
      const ReminderList(id: 'list.work', title: '工作', remoteId: '100'),
    );
    port = _FakePort();
  });

  testWidgets('所有者：成员表出昵称与角色，并给邀请输入框', (tester) async {
    port.me = '1';
    port.members = [
      const TaskListMember(memberUserId: '1', role: 'owner', status: 'active'),
      const TaskListMember(
        memberUserId: '2',
        role: 'viewer',
        status: 'active',
        nickname: '李四',
      ),
    ];
    await pump(tester, collab: port);
    await openShare(tester);

    expect(find.byKey(const ValueKey('share_sheet_host')), findsNothing);
    expect(find.byKey(const ValueKey('share_member_2')), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
    expect(find.text('仅查看 · 已加入'), findsOneWidget);
    expect(find.byKey(const ValueKey('share_role_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('share_remove_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('share_invite_mobile')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('share_exit')),
      findsNothing,
      reason: '所有者不能退出自己的清单',
    );
  });

  testWidgets('所有者点「改角色」：只发一次 updateMemberRole，参数是 viewer', (tester) async {
    port.me = '1';
    port.members = [
      const TaskListMember(memberUserId: '1', role: 'owner', status: 'active'),
      const TaskListMember(memberUserId: '2', role: 'editor', status: 'active'),
    ];
    await pump(tester, collab: port);
    await openShare(tester);

    await tester.tap(find.byKey(const ValueKey('share_role_2')));
    await tester.pumpAndSettle();

    expect(port.calls, [
      'listMembers',
      'whoAmI',
      'updateMemberRole',
      'listMembers',
      'whoAmI',
    ]);
    expect(port.lastRole, 'viewer', reason: 'editor 的下一档是 viewer');
    expect(port.lastTarget, '2');
  });

  testWidgets('被共享人：不给邀请框与改角色，给退出入口', (tester) async {
    port.me = '2';
    port.members = [
      const TaskListMember(memberUserId: '1', role: 'owner', status: 'active'),
      const TaskListMember(
        memberUserId: '2',
        role: 'editor',
        status: 'active',
        nickname: '李四',
      ),
    ];
    await pump(tester, collab: port);
    await openShare(tester);

    expect(find.byKey(const ValueKey('share_invite_mobile')), findsNothing);
    expect(find.byKey(const ValueKey('share_role_1')), findsNothing);
    expect(find.byKey(const ValueKey('share_exit')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('share_exit')));
    await tester.pumpAndSettle();
    expect(port.calls, contains('exitList'));
  });

  testWidgets('待接受的邀请：给「接受邀请」，点了才转 active', (tester) async {
    port.me = '2';
    port.members = [
      const TaskListMember(memberUserId: '1', role: 'owner', status: 'active'),
      const TaskListMember(
        memberUserId: '2',
        role: 'viewer',
        status: 'invited',
      ),
    ];
    await pump(tester, collab: port);
    await openShare(tester);

    expect(find.text('邀请待接受（待接受）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('share_join')));
    await tester.pumpAndSettle();

    expect(port.calls, contains('joinList'));
  });

  testWidgets('清单还没有服务端编号：说明而不是空表，且一次端口都不调', (tester) async {
    port.me = '1';
    await pump(tester, collab: port, withRemoteId: false);
    await openShare(tester);

    expect(find.byKey(const ValueKey('share_no_remote_id')), findsOneWidget);
    expect(find.textContaining('还没有服务端编号'), findsOneWidget);
    expect(port.calls, isEmpty, reason: '没有编号就不该打网络');
  });

  testWidgets('端口未注入：点共享… 给说明弹窗，不崩也不置灰占位', (tester) async {
    await pump(tester, collab: null);
    await openShare(tester);

    expect(find.text('当前环境未接入共享服务（未登录或离线档）。'), findsOneWidget);
    expect(find.byKey(const ValueKey('share_invite_mobile')), findsNothing);
  });

  testWidgets('服务端报错要显示原文，不能读成「没有协作者」', (tester) async {
    port.me = '1';
    port.failListMembersWith = '无权操作该清单（仅所有者可邀请/改角色/移除）';
    await pump(tester, collab: port);
    await openShare(tester, settle: false);

    expect(find.byKey(const ValueKey('share_error')), findsOneWidget);
    expect(find.textContaining('仅所有者'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('share_members_empty')),
      findsNothing,
      reason: '失败与空态是两件事，混起来就会骗过验收',
    );
  });
}

class _FakePort implements TaskCollabPort {
  String? me;
  List<TaskListMember> members = const [];
  String? failListMembersWith;
  final calls = <String>[];
  String? lastRole;
  String? lastTarget;

  @override
  Future<String?> whoAmI() async {
    calls.add('whoAmI');
    return me;
  }

  @override
  Future<List<TaskListMember>> listMembers(String listId) async {
    calls.add('listMembers');
    final fail = failListMembersWith;
    if (fail != null) throw TaskCollabException(fail);
    return members;
  }

  @override
  Future<String> resolveUserByMobile(String mobile) async {
    calls.add('resolveUserByMobile');
    return '9';
  }

  @override
  Future<void> inviteMembers(
    String listId, {
    required List<String> userIds,
    required String role,
  }) async {
    calls.add('inviteMembers');
    lastTarget = userIds.join(',');
    lastRole = role;
  }

  @override
  Future<void> updateMemberRole(
    String listId,
    String userId,
    String role,
  ) async {
    calls.add('updateMemberRole');
    lastTarget = userId;
    lastRole = role;
  }

  @override
  Future<void> removeMember(String listId, String userId) async {
    calls.add('removeMember');
    lastTarget = userId;
  }

  @override
  Future<void> joinList(String listId) async {
    calls.add('joinList');
  }

  @override
  Future<void> exitList(String listId) async {
    calls.add('exitList');
  }

  @override
  Future<List<TaskSharedList>> mySharedLists() async {
    calls.add('mySharedLists');
    return const [];
  }
}
