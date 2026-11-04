/// 清单共享成员（服务端 `lifeos_list_member` 的本地视图）。
///
/// id 一律用字符串承载：服务端是 bigint，本地 `ReminderList.remoteId` 也是字符串，
/// 走网络时再转，避免两套数字精度假设。
class TaskListMember {
  const TaskListMember({
    required this.memberUserId,
    required this.role,
    required this.status,
    this.nickname,
  });

  final String memberUserId;

  /// owner / editor / viewer。
  final String role;

  /// invited / active / exited / removed。
  final String status;

  /// 服务端富化的昵称；查不到为空。
  final String? nickname;

  bool get isActive => status == 'active';

  bool get canWrite => role == 'owner' || role == 'editor';
}

/// 别人共享给我的清单（服务端 `my-lists` 的一行）。
class TaskSharedList {
  const TaskSharedList({
    required this.listId,
    required this.name,
    required this.ownerUserId,
    required this.role,
  });

  final String listId;
  final String name;
  final String ownerUserId;
  final String role;
}

/// 别人共享给我的清单里的一条任务（`/lifeos/task/task/page` 的只读投影）。
///
/// 不复用 `ReminderItem`：那条类型是 Drift 行的形状，带本地 id、outbox 与
/// 同步水位字段。共享清单按 #600 的 B 路线**不进本地表**，若硬套 `ReminderItem`
/// 就会诱使后续代码把它写回仓库、把别人的清单当成自己的回推（outbox 污染）。
/// 这里刻意只留展示所需字段，且没有任何写入口。
class TaskSharedItem {
  const TaskSharedItem({
    required this.id,
    required this.listId,
    required this.title,
    this.notes,
    this.dueAt,
    this.allDay = false,
    this.priority = 0,
    this.flagged = false,
    this.completed = false,
    this.tagNames = const <String>[],
  });

  /// 服务端任务编号（bigint，同样按字符串承载，避免两套精度假设）。
  final String id;
  final String listId;
  final String title;
  final String? notes;
  final DateTime? dueAt;
  final bool allDay;

  /// 服务端 0~5，0 表示无优先级。
  final int priority;
  final bool flagged;
  final bool completed;
  final List<String> tagNames;
}

class TaskCollabException implements Exception {
  TaskCollabException(this.message);

  final String message;

  @override
  String toString() => 'TaskCollabException: $message';
}

/// 清单共享端口（flutter#570；矩阵行 25「共享列表（邀请/参与者）」的客户端消费面）。
///
/// 契约在服务端 zh-cloud-service #587 + #589（`/app-api/lifeos/task/list/**`
/// 与 `/app-api/lifeos/task/list-member/**`）。端口放 kernel、实现放
/// feature_task_cloud —— 与 `ReminderRepository` / `SyncOutbox` 同一条依赖方向：
/// feature_task 不依赖 feature_task_cloud，只能经由这里拿抽象。
abstract interface class TaskCollabPort {
  /// 当前登录用户编号（读本地会话，不发网络）。
  ///
  /// UI 用它区分「我是所有者」与「我是被共享人」——两种身份能做的操作不同
  /// （改角色/移除只对所有者开放，退出只对成员开放），而这层信息不在
  /// `ReminderList` 里（本地清单没有 owner 列）。
  Future<String?> whoAmI();

  /// 某清单的成员表。`listId` 是**服务端编号**（本地 `ReminderList.remoteId`）。
  Future<List<TaskListMember>> listMembers(String listId);

  /// 按手机号解析用户编号（服务端只做精确匹配，不回手机号）。
  Future<String> resolveUserByMobile(String mobile);

  Future<void> inviteMembers(
    String listId, {
    required List<String> userIds,
    required String role,
  });

  Future<void> updateMemberRole(String listId, String userId, String role);

  Future<void> removeMember(String listId, String userId);

  /// 被邀请人接受邀请（invited -> active）。
  Future<void> joinList(String listId);

  Future<void> exitList(String listId);

  /// 我作为活跃成员参与的清单。
  Future<List<TaskSharedList>> mySharedLists();

  /// 共享清单的条目（flutter#599/#600 路线 B：直连服务端读，不落本地 Drift）。
  ///
  /// 服务端读侧已放行 active 成员（`LifeosListServiceImpl.visibleTo`），
  /// 返回的是**别人的**清单，调用方不得把它写回任何本地仓库。
  Future<List<TaskSharedItem>> sharedListTasks(
    String listId, {
    bool includeCompleted,
  });
}

/// 邀请角色的中文标签（`ListShareSheet` 与侧栏「与我共享」共用一份口径）。
String taskShareRoleLabel(String role) => switch (role) {
  'owner' => '所有者',
  'editor' => '可编辑',
  'viewer' => '仅查看',
  _ => role,
};
