import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task_scaffold.dart';

/// 紧凑端首页（嵌入生活台 Tab 用）：列表首页概览。
///
/// 兼容旧入口名；实际渲染交由 [TaskScaffold] 按断点自适应。
class TaskHomePage extends ConsumerWidget {
  const TaskHomePage({super.key, this.onOpenList});

  /// 点开列表的回调（紧凑端由壳层路由推栈）。
  final ValueChanged<String>? onOpenList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TaskScaffold(onOpenList: onOpenList);
  }
}
