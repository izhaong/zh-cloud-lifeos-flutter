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
}
