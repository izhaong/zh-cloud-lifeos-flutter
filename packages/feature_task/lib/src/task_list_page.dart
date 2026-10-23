import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'task_scaffold.dart';

/// 紧凑端单列表页（壳内子路由）：列表内容；生活台底栏由壳提供。
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key, required this.list, this.onSelectItem});

  final ReminderList list;
  final ValueChanged<ReminderItem>? onSelectItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 紧凑端列表页：直接复用布局无关内容区；宽屏端该内容由 TaskScaffold 分栏呈现。
    return TaskScaffold(openListId: list.id);
  }
}
