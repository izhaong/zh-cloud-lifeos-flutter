import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collab/rest_calendar_collab_port.dart';
import '../sync/calendar_sync_coordinator.dart';

/// 组合根注入（未登录/未配置时为 null）。
final calendarCollabPortProvider =
    Provider<CalendarCollabPort?>((ref) => null);

final calendarSyncCoordinatorProvider =
    Provider<CalendarSyncCoordinator?>((ref) => null);

/// 日历云侧页面：收件箱 / 共享日历 / 导入导出（F-17；TC-CAL-UI-180～182）。
class CalendarCloudPage extends ConsumerStatefulWidget {
  const CalendarCloudPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<CalendarCloudPage> createState() => _CalendarCloudPageState();
}

class _CalendarCloudPageState extends ConsumerState<CalendarCloudPage> {
  String? _message;
  final _icsController = TextEditingController();

  @override
  void dispose() {
    _icsController.dispose();
    super.dispose();
  }

  CalendarCollabPort? get _port => ref.read(calendarCollabPortProvider);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        key: const Key('calendar_cloud_page'),
        appBar: AppBar(
          title: const Text('日历云服务'),
          bottom: const TabBar(tabs: [
            Tab(text: '收件箱'),
            Tab(text: '共享日历'),
            Tab(text: '导入导出'),
          ]),
        ),
        body: Column(
          children: [
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_message!,
                    key: const Key('calendar_cloud_message'),
                    style: const TextStyle(color: Color(0xFF8E8E93))),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _InboxTab(port: _port, onMessage: _setMessage),
                  _SharedTab(port: _port, onMessage: _setMessage),
                  _ImportExportTab(
                    port: _port,
                    controller: _icsController,
                    onMessage: _setMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setMessage(String message) {
    if (mounted) {
      setState(() => _message = message);
    }
  }
}

class _InboxTab extends StatefulWidget {
  const _InboxTab({required this.port, required this.onMessage});

  final CalendarCollabPort? port;
  final ValueChanged<String> onMessage;

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  late final Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final port = widget.port;
    if (port == null) {
      return [];
    }
    return port.inboxList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('收件箱加载失败：${snapshot.error}'));
        }
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return const Center(
              child: Text('暂无收件箱消息', key: Key('inbox_empty')));
        }
        return ListView(
          key: const Key('inbox_list'),
          children: [
            for (final row in rows)
              ListTile(
                key: Key('inbox_item_${row['id']}'),
                title: Text(row['type']?.toString() ?? ''),
                subtitle: Text(row['payload']?.toString() ?? ''),
                trailing: row['type'] == 'SHARE_INVITATION'
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(
                          key: Key('inbox_accept_${row['id']}'),
                          onPressed: () => _respond(row, true),
                          child: const Text('接受'),
                        ),
                        TextButton(
                          key: Key('inbox_decline_${row['id']}'),
                          onPressed: () => _respond(row, false),
                          child: const Text('拒绝'),
                        ),
                      ])
                    : null,
              ),
          ],
        );
      },
    );
  }

  Future<void> _respond(Map<String, dynamic> row, bool accept) async {
    final port = widget.port;
    final shareId = (row['shareId'] as num?)?.toInt() ??
        (row['calendarShareId'] as num?)?.toInt();
    if (port == null || shareId == null) {
      return;
    }
    await port.respondShare(shareId, accept: accept);
    widget.onMessage(accept ? '已接受共享' : '已拒绝共享');
  }
}

class _SharedTab extends StatefulWidget {
  const _SharedTab({required this.port, required this.onMessage});

  final CalendarCollabPort? port;
  final ValueChanged<String> onMessage;

  @override
  State<_SharedTab> createState() => _SharedTabState();
}

class _SharedTabState extends State<_SharedTab> {
  late final Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final port = widget.port;
    if (port == null) {
      return [];
    }
    return port.calendarList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('共享日历加载失败：${snapshot.error}'));
        }
        final rows = (snapshot.data ?? const [])
            .where((c) => c['kind']?.toString() == 'SHARED')
            .toList();
        if (rows.isEmpty) {
          return const Center(
              child: Text('暂无共享日历', key: Key('shared_empty')));
        }
        return ListView(
          key: const Key('shared_list'),
          children: [
            for (final row in rows)
              ListTile(
                key: Key('shared_item_${row['id']}'),
                title: Text(row['title']?.toString() ?? '共享日历'),
                subtitle: Text(row['permission']?.toString() ?? ''),
              ),
          ],
        );
      },
    );
  }
}

class _ImportExportTab extends StatelessWidget {
  const _ImportExportTab({
    required this.port,
    required this.controller,
    required this.onMessage,
  });

  final CalendarCollabPort? port;
  final TextEditingController controller;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton(
          key: const Key('export_feed_button'),
          onPressed: () async {
            final url = await port?.exportFeedUrl(null);
            onMessage(url == null ? '导出链接不可用' : '导出链接：$url');
          },
          child: const Text('生成公开导出链接'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('import_ics_input'),
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '粘贴 ICS 内容',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('import_ics_button'),
          onPressed: () async {
            final text = controller.text;
            if (text.trim().isEmpty) {
              onMessage('请先粘贴 ICS 内容');
              return;
            }
            await port?.importIcs(
              calendarId: 0,
              filename: 'import.ics',
              bytes: text.codeUnits,
            );
            onMessage('已提交导入');
          },
          child: const Text('导入到日历'),
        ),
      ],
    );
  }
}
