import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../providers.dart';

/// 受邀者面板（矩阵 F4 发送邀请 / F5 移除受邀者；契约 §3.3）。
///
/// 读写都以服务端为准：本地 `CalendarEvent.invitees` 只是缓存（push 不带 invitees、
/// pull 保留旧值），所以进面板重读一次，写完再读一次。
/// 日程还没落库时调用方不打开本面板（表单那行先给「保存后可邀请」）。
Future<void> showInviteesSheet(BuildContext context, {required int eventId}) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _InviteesSheet(eventId: eventId),
    );

class _InviteesSheet extends ConsumerStatefulWidget {
  const _InviteesSheet({required this.eventId});

  final int eventId;

  @override
  ConsumerState<_InviteesSheet> createState() => _InviteesSheetState();
}

class _InviteesSheetState extends ConsumerState<_InviteesSheet> {
  List<EventInvitee> _invitees = const [];
  final _mobile = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;

  CalendarCollabPort? get _port => ref.read(calendarCollabPortProvider);

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
    final port = _port;
    if (port == null) {
      setState(() {
        _loading = false;
        _error = '未登录或云端未就绪';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await port.inviteeList(widget.eventId);
      if (!mounted) return;
      setState(() {
        _invitees = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取受邀者失败';
      });
    }
  }

  Future<void> _remove(String memberUserId) => _run(() async {
    await _port!.removeInvitee(widget.eventId, memberUserId);
    await _load();
    return '已移除受邀者';
  }, failure: '移除受邀者失败');

  Future<void> _add() => _run(() async {
    // 两步都要 await：解析拿成员编号，再让服务端「仅添加不发送」。
    final id = await _port!.resolveMemberByMobile(_mobile.text);
    await _port!.addInvitees(widget.eventId, [id]);
    await _load();
    _mobile.clear();
    return '已添加受邀者';
  }, failure: '添加受邀者失败');

  Future<void> _send() => _run(() async {
    await _port!.sendInvitations(widget.eventId);
    return '已发送邀请';
  }, failure: '发送邀请失败');

  /// 写动作统一走这里：忙时忽略重复点击，成功后给一条当场可见的提示。
  Future<void> _run(
    Future<String> Function() action, {
    required String failure,
  }) async {
    if (_port == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final msg = await action();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('invitee_sheet'),
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('受邀者', style: TextStyle(fontSize: 17)),
              ),
              CupertinoButton(
                key: const Key('invitee_close'),
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              key: const Key('invitee_error'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
            ),
          if (_message != null)
            Padding(
              key: const Key('invitee_message'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_message!),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CupertinoActivityIndicator(key: Key('invitee_loading')),
            )
          else if (_invitees.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('还没有受邀者', key: Key('invitee_empty')),
            )
          else
            for (final i in _invitees)
              Padding(
                key: Key('invitee_row_${i.memberUserId}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i.displayName ?? i.memberUserId}（${_partstatLabel(i.partstat)}）',
                      ),
                    ),
                    CupertinoButton(
                      key: Key('invitee_remove_${i.memberUserId}'),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: _busy ? null : () => _remove(i.memberUserId),
                      child: const Text('移除'),
                    ),
                  ],
                ),
              ),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  key: const Key('invitee_mobile'),
                  controller: _mobile,
                  placeholder: '成员手机号',
                  keyboardType: TextInputType.phone,
                ),
              ),
              CupertinoButton(
                key: const Key('invitee_add_submit'),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: _busy ? null : _add,
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            key: const Key('invitee_send'),
            color: CupertinoColors.systemBlue.resolveFrom(context),
            onPressed: _busy ? null : _send,
            child: const Text('发送邀请'),
          ),
        ],
      ),
    );
  }
}

String _partstatLabel(PartStat p) => switch (p) {
  PartStat.needsAction => '未回复',
  PartStat.accepted => '已接受',
  PartStat.declined => '已拒绝',
  PartStat.tentative => '待定',
};
