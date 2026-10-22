import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: LifeLauncherApp(
        reminderRepository: InMemoryReminderRepository(),
      ),
    ),
  );
}

class LifeLauncherApp extends StatelessWidget {
  const LifeLauncherApp({super.key, required this.reminderRepository});

  final ReminderRepository reminderRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeOS 生活台',
      debugShowCheckedModeBanner: false,
      theme: LifeTokens.light(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LifeShell(reminderRepository: reminderRepository),
    );
  }
}

/// 飞书式底部 Tab：任务 / 占位 / 更多。
class LifeShell extends StatefulWidget {
  const LifeShell({super.key, required this.reminderRepository});

  final ReminderRepository reminderRepository;

  @override
  State<LifeShell> createState() => _LifeShellState();
}

class _LifeShellState extends State<LifeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TaskHomePage(repository: widget.reminderRepository),
      const _PlaceholderPage(title: '日历', subtitle: 'feature_calendar 待拆入'),
      const _PlaceholderPage(title: '习惯', subtitle: 'feature_habit 待拆入'),
      const _MorePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: '任务',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: '习惯',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: '更多',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage();

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
