import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'task_scaffold.dart';

/// 紧凑端单列表页（栈导航推入用）：带返回按钮的全屏列表内容。
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
