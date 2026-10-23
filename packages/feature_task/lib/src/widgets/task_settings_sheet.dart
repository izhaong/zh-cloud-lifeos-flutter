import 'package:flutter/material.dart';

/// 任务 App 设置弹层（线框：客户端/Pad 侧栏「设置」入口）。
///
/// UI 态，不开路由；P0 先做入口 + 占位行，真实设置项随后续阶段填。
Future<void> showTaskSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return const SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                        Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Center(
                child: Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
                        ListTile(
              leading: Icon(Icons.account_circle_outlined),
              title: Text('账号与同步'),
              subtitle: Text('登录后可用（同步仅私有 cloud）'),
            ),
                        ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text('通知与提醒'),
              subtitle: Text('规划（P1）'),
            ),
                        ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('外观'),
              subtitle: Text('跟随系统'),
            ),
                        SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
