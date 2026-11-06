import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// `calendarCollabPortProvider` 与端口抽象都由开源侧提供（#606：Inspector 也要读同一个端口）。
import 'package:feature_calendar/feature_calendar.dart';

import '../sync/calendar_sync_coordinator.dart';
import '../sync/calendar_sync_models.dart';

/// 加载失败的面向用户文案（#165：不得回显异常类名/状态码）。
String _friendlyLoadError(Object? error) {
  if (error is CalendarSyncException && error.isUnauthorized) {
    return '登录后可查看（当前未登录）';
  }
  return '暂时不可用，请稍后重试';
}

final calendarSyncCoordinatorProvider = Provider<CalendarSyncCoordinator?>(
  (ref) => null,
);

/// 日历云侧页面：收件箱 / 共享日历 / 导入导出（F-17；TC-CAL-UI-180～182）。
class CalendarCloudPage extends ConsumerStatefulWidget {
  const CalendarCloudPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<CalendarCloudPage> createState() => _CalendarCloudPageState();
}

class _CalendarCloudPageState extends ConsumerState<CalendarCloudPage> {
  late int _tab = widget.initialTab;
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
    return CupertinoPageScaffold(
      key: const Key('calendar_cloud_page'),
      navigationBar: const CupertinoNavigationBar(middle: Text('日历云服务')),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _tab,
                  onValueChanged: (v) {
                    if (v != null) {
                      setState(() => _tab = v);
                    }
                  },
                  children: const {
                    0: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('收件箱'),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('共享日历'),
                    ),
                    2: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('导入导出'),
                    ),
                  },
                ),
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _message!,
                  key: const Key('calendar_cloud_message'),
                  style: const TextStyle(color: CupertinoColors.systemGrey),
                ),
              ),
            Expanded(
              child: switch (_tab) {
                1 => _SharedTab(port: _port, onMessage: _setMessage),
                2 => _ImportExportTab(
                  port: _port,
                  controller: _icsController,
                  onMessage: _setMessage,
                ),
                _ => _InboxTab(port: _port, onMessage: _setMessage),
              },
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
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '收件箱${_friendlyLoadError(snapshot.error)}',
              key: const Key('inbox_load_failed'),
            ),
          );
        }
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return const Center(child: Text('暂无收件箱消息', key: Key('inbox_empty')));
        }
        return ListView(
          key: const Key('inbox_list'),
          children: [
            for (final row in rows)
              _CloudRow(
                rowKey: Key('inbox_item_${row['id']}'),
                title: row['type']?.toString() ?? '',
                subtitle: row['payload']?.toString() ?? '',
                trailing: row['type'] == 'SHARE_INVITATION'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoButton(
                            key: Key('inbox_accept_${row['id']}'),
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => _respond(row, true),
                            child: const Text('接受'),
                          ),
                          CupertinoButton(
                            key: Key('inbox_decline_${row['id']}'),
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => _respond(row, false),
                            child: const Text('拒绝'),
                          ),
                        ],
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }

  Future<void> _respond(Map<String, dynamic> row, bool accept) async {
    final port = widget.port;
    final shareId =
        (row['shareId'] as num?)?.toInt() ??
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
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '共享日历${_friendlyLoadError(snapshot.error)}',
              key: const Key('shared_load_failed'),
            ),
          );
        }
        final rows = (snapshot.data ?? const [])
            .where((c) => c['kind']?.toString() == 'SHARED')
            .toList();
        if (rows.isEmpty) {
          return const Center(child: Text('暂无共享日历', key: Key('shared_empty')));
        }
        return ListView(
          key: const Key('shared_list'),
          children: [
            for (final row in rows)
              _CloudRow(
                rowKey: Key('shared_item_${row['id']}'),
                title: row['title']?.toString() ?? '共享日历',
                subtitle: row['permission']?.toString() ?? '',
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
        // #604：服务端早有端点、客户端此前没有入口的三行（矩阵 A8/C4/C5）。
        FutureBuilder<List<Map<String, dynamic>>>(
          key: const Key('export_calendar_rows'),
          future: port?.calendarList(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(_friendlyLoadError(snap.error));
            }
            final items = snap.data ?? const <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无可导出的日历'),
              );
            }
            return Column(
              children: [
                for (final item in items)
                  Builder(
                    builder: (context) {
                      final id = (item['id'] as num).toInt();
                      return Row(
                        children: [
                          Expanded(
                            child: Text('${item['title'] ?? '未命名日历'}'),
                          ),
                          CupertinoButton(
                            key: Key('set_default_calendar_$id'),
                            onPressed: () async {
                              try {
                                await port?.setDefaultCalendar(id);
                                onMessage('已设为默认日历');
                              } catch (error) {
                                onMessage(_friendlyLoadError(error));
                              }
                            },
                            child: const Text('设为默认'),
                          ),
                          CupertinoButton(
                            key: Key('export_calendar_$id'),
                            onPressed: () async {
                              try {
                                final ics = await port?.exportCalendarIcs(id);
                                onMessage(ics == null
                                    ? '导出失败'
                                    : '已导出 ${ics.length} 字节 .ics');
                              } catch (error) {
                                onMessage(_friendlyLoadError(error));
                              }
                            },
                            child: const Text('导出 .ics'),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        CupertinoButton(
          key: const Key('export_all_button'),
          color: CupertinoColors.systemBlue,
          onPressed: () async {
            try {
              final ics = await port?.exportAllIcs();
              onMessage(
                  ics == null ? '导出失败' : '已导出全部日历 ${ics.length} 字节');
            } catch (error) {
              onMessage(_friendlyLoadError(error));
            }
          },
          child: const Text('导出全部 .ics'),
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          key: const Key('export_feed_button'),
          color: CupertinoColors.systemBlue,
          onPressed: () async {
            // #618：此前是裸 await，端口抛错时整条 handler 崩，用户点了什么都没发生。
            try {
              final url = await port?.exportFeedUrl(null);
              onMessage(url == null ? '导出链接不可用' : '导出链接：$url');
            } catch (error) {
              onMessage(_friendlyLoadError(error));
            }
          },
          child: const Text('生成公开导出链接'),
        ),
        const SizedBox(height: 16),
        CupertinoTextField(
          key: const Key('import_ics_input'),
          controller: controller,
          maxLines: 6,
          minLines: 6,
          placeholder: '粘贴 ICS 内容',
        ),
        const SizedBox(height: 8),
        CupertinoButton(
          key: const Key('import_ics_button'),
          color: CupertinoColors.systemBlue,
          onPressed: () async {
            final text = controller.text;
            if (text.trim().isEmpty) {
              onMessage('请先粘贴 ICS 内容');
              return;
            }
            // #618：导入同样是裸 await；且服务端此刻只收到请求、还没落库，
            // 文案不许写成像「已经导入完成」，与 #165 的「不外推完成」口径一致。
            try {
              await port?.importIcs(
                calendarId: 0,
                filename: 'import.ics',
                bytes: text.codeUnits,
              );
            } catch (error) {
              onMessage(_friendlyLoadError(error));
              return;
            }
            onMessage('已提交导入，稍后出现在日历里');
          },
          child: const Text('导入到日历'),
        ),
      ],
    );
  }
}

/// 列表行：0.5px 分隔线 + 主/副标题（Apple 列表风格）。
class _CloudRow extends StatelessWidget {
  const _CloudRow({
    required this.rowKey,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final Key rowKey;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Padding(
        key: rowKey,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
