import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'task_list_page.dart';

/// iPhone「提醒事项」列表首页骨架（智能列表卡片 + 我的列表）。
class TaskHomePage extends StatelessWidget {
  const TaskHomePage({
    super.key,
    required this.repository,
    this.embedded = true,
  });

  final ReminderRepository repository;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReminderList>>(
      future: repository.watchLists(),
      builder: (context, snapshot) {
        final lists = snapshot.data ?? const <ReminderList>[];
        final smart = lists.where((e) => e.isSmart).toList();
        final mine = lists.where((e) => !e.isSmart).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          appBar: AppBar(
            title: const Text('提醒事项'),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(CupertinoIcons.ellipsis_circle),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SmartGrid(lists: smart, repository: repository),
              const SizedBox(height: 20),
              Text(
                '我的列表',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < mine.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 52),
                      ListTile(
                        leading: CircleAvatar(
                          radius: 10,
                          backgroundColor: Color(mine[i].colorArgb),
                        ),
                        title: Text(mine[i].title),
                        trailing: Text('${mine[i].itemCount}'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TaskListPage(
                                list: mine[i],
                                repository: repository,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(CupertinoIcons.add),
            label: const Text('新建提醒'),
          ),
        );
      },
    );
  }
}

class _SmartGrid extends StatelessWidget {
  const _SmartGrid({required this.lists, required this.repository});

  final List<ReminderList> lists;
  final ReminderRepository repository;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        for (final list in lists)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TaskListPage(
                      list: list,
                      repository: repository,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _iconFor(list.id),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const Spacer(),
                        Text(
                          '${list.itemCount}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      list.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(String id) {
    return switch (id) {
      'smart.today' => CupertinoIcons.today,
      'smart.scheduled' => CupertinoIcons.calendar,
      'smart.all' => CupertinoIcons.tray_full,
      'smart.flagged' => CupertinoIcons.flag_fill,
      _ => CupertinoIcons.list_bullet,
    };
  }
}
