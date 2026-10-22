import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({
    super.key,
    required this.list,
    required this.repository,
  });

  final ReminderList list;
  final ReminderRepository repository;

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  late Future<List<ReminderItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.watchItems(listId: widget.list.id);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.repository.watchItems(listId: widget.list.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.list.title),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(CupertinoIcons.ellipsis_circle),
          ),
        ],
      ),
      body: FutureBuilder<List<ReminderItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <ReminderItem>[];
          if (items.isEmpty) {
            return const Center(child: Text('没有提醒'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 52),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: IconButton(
                  onPressed: () async {
                    await widget.repository.toggleCompleted(item.id);
                    await _reload();
                  },
                  icon: Icon(
                    item.isCompleted
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color: item.isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black26,
                  ),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: item.dueAt == null
                    ? null
                    : Text(
                        MaterialLocalizations.of(context).formatMediumDate(
                          item.dueAt!,
                        ),
                      ),
                trailing: item.isFlagged
                    ? const Icon(CupertinoIcons.flag_fill, color: Colors.orange)
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
