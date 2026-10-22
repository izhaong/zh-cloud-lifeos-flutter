import 'package:flutter/material.dart';

/// 「详细信息」占位页（Phase 1 骨架；Phase 2 落完整编辑表单）。
///
/// 布局无关：紧凑端为模态全屏页，宽屏端为第三栏内容。
class ReminderDetailPane extends StatelessWidget {
  const ReminderDetailPane({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('详细信息'),
        leading: MediaQuery.of(context).size.width < 600
            ? CloseButton(
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: const Center(
        child: Text('详情编辑（Phase 2）：备注 / 日期 / 标签 / 优先级 / 子任务'),
      ),
    );
  }
}
