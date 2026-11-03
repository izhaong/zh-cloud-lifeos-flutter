import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// flutter#570：清单共享的**生产入口**（矩阵行 25「共享列表（邀请/参与者）」）。
///
/// 端口抽象在 kernel（`TaskCollabPort`），实现是 feature_task_cloud 的
/// `RestTaskCollabPort`，由组合根注入——本文件只认抽象。
Future<void> showListShareSheet(
  BuildContext context, {
  required ReminderList list,
  required TaskCollabPort port,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => ListShareSheet(list: list, port: port),
  );
}

String _roleLabel(String role) => switch (role) {
  'owner' => '所有者',
  'editor' => '可编辑',
  'viewer' => '仅查看',
  _ => role,
};

String _statusLabel(String status) => switch (status) {
  'invited' => '待接受',
  'active' => '已加入',
  'exited' => '已退出',
  'removed' => '已移除',
  _ => status,
};

class ListShareSheet extends StatefulWidget {
  const ListShareSheet({super.key, required this.list, required this.port});

  final ReminderList list;
  final TaskCollabPort port;

  @override
  State<ListShareSheet> createState() => _ListShareSheetState();
}

class _ListShareSheetState extends State<ListShareSheet> {
  final TextEditingController _mobile = TextEditingController();

  List<TaskListMember>? _members;
  String? _me;
  String? _error;
  bool _busy = false;

  String? get _serverListId => widget.list.remoteId;

  bool get _isOwner {
    final me = _me;
    if (me == null) return false;
    final owner = _members?.where((e) => e.role == 'owner').firstOrNull;
    return owner?.memberUserId == me;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _serverListId;
    if (id == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final both = await Future.wait([
        widget.port.listMembers(id),
        widget.port.whoAmI().then((v) => v ?? ''),
      ]);
      if (!mounted) return;
      setState(() {
        _members = both[0] as List<TaskListMember>;
        final me = both[1] as String;
        _me = me.isEmpty ? null : me;
        _busy = false;
      });
    } on TaskCollabException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on TaskCollabException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _invite() async {
    final mobile = _mobile.text.trim();
    if (mobile.isEmpty) return;
    final id = _serverListId;
    if (id == null) return;
    await _run(() async {
      final userId = await widget.port.resolveUserByMobile(mobile);
      await widget.port.inviteMembers(id, userIds: [userId], role: 'viewer');
    });
    if (!mounted) return;
    _mobile.clear();
  }

  Future<void> _cycleRole(TaskListMember member) async {
    final id = _serverListId;
    if (id == null) return;
    final next = member.role == 'editor' ? 'viewer' : 'editor';
    await _run(
      () => widget.port.updateMemberRole(id, member.memberUserId, next),
    );
  }

  Future<void> _remove(TaskListMember member) async {
    final id = _serverListId;
    if (id == null) return;
    await _run(() => widget.port.removeMember(id, member.memberUserId));
  }

  Future<void> _join() async {
    final id = _serverListId;
    if (id == null) return;
    await _run(() => widget.port.joinList(id));
  }

  Future<void> _exit() async {
    final id = _serverListId;
    if (id == null) return;
    await _run(() => widget.port.exitList(id));
  }

  @override
  Widget build(BuildContext context) {
    final id = _serverListId;
    final members = _members;
    final mine = members?.where((e) => e.memberUserId == _me).firstOrNull;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemGroupedBackground,
        context,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('共享「${widget.list.title}」')),
                  CupertinoButton(
                    key: const ValueKey('share_done'),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            if (id == null)
              const Padding(
                key: ValueKey('share_no_remote_id'),
                padding: EdgeInsets.all(16),
                child: Text('这份清单还没有服务端编号（未同步过），先同步到云端再共享。'),
              )
            else ...[
              if (_error != null)
                Padding(
                  key: const ValueKey('share_error'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(_error!),
                ),
              if (mine != null && !mine.isActive)
                CupertinoListTile(
                  key: const ValueKey('share_join_row'),
                  title: Text('邀请待接受（${_statusLabel(mine.status)}）'),
                  trailing: CupertinoButton(
                    key: const ValueKey('share_join'),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: _busy ? null : _join,
                    child: const Text('接受邀请'),
                  ),
                ),
              if (members == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CupertinoActivityIndicator(),
                )
              else if (members.isEmpty)
                const Padding(
                  key: ValueKey('share_members_empty'),
                  padding: EdgeInsets.all(16),
                  child: Text('还没有协作者'),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in members)
                        CupertinoListTile(
                          key: ValueKey('share_member_${m.memberUserId}'),
                          title: Text(
                            m.nickname?.isNotEmpty == true
                                ? m.nickname!
                                : '用户 ${m.memberUserId}',
                          ),
                          subtitle: Text(
                            '${_roleLabel(m.role)} · ${_statusLabel(m.status)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isOwner && m.role != 'owner') ...[
                                CupertinoButton(
                                  key: ValueKey('share_role_${m.memberUserId}'),
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  onPressed: _busy ? null : () => _cycleRole(m),
                                  child: const Text('改角色'),
                                ),
                                CupertinoButton(
                                  key: ValueKey(
                                    'share_remove_${m.memberUserId}',
                                  ),
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  onPressed: _busy ? null : () => _remove(m),
                                  child: const Text('移除'),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (_isOwner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          key: const ValueKey('share_invite_mobile'),
                          controller: _mobile,
                          placeholder: '对方手机号',
                          onSubmitted: _busy ? null : (_) => _invite(),
                        ),
                      ),
                      CupertinoButton(
                        key: const ValueKey('share_invite_submit'),
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: _busy ? null : _invite,
                        child: const Text('邀请'),
                      ),
                    ],
                  ),
                )
              else if (mine != null && mine.isActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: CupertinoButton(
                    key: const ValueKey('share_exit'),
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    onPressed: _busy ? null : _exit,
                    child: const Text('退出这份清单'),
                  ),
                ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
