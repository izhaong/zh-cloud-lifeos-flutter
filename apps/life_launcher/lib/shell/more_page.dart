import 'package:flutter/material.dart';

/// 「更多」面板：全部已装应用 + 编辑 + 添加更多应用（Phase 5 目录占位）。
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更多'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('编辑')),
        ],
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.check_circle),
            title: Text('任务'),
            subtitle: Text('已安装 · 已固定到 Tab'),
          ),
          const ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text('日历'),
            subtitle: Text('占位'),
          ),
          const ListTile(
            leading: Icon(Icons.spa),
            title: Text('习惯'),
            subtitle: Text('占位'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('添加更多应用'),
            subtitle: const Text('打开 LifeOS App Store（H1 目录）'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('目录客户端 Phase 5')),
              );
            },
          ),
        ],
      ),
    );
  }
}
