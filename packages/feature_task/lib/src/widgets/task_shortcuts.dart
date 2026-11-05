import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// ⌘N 新建提醒、⌘F 聚焦搜索的快捷键层（macOS 对齐）。
///
/// 动作通过 [TaskShortcutsController] 广播给列表内容区执行
/// （打开草稿行 / 聚焦搜索框）；无监听时快捷键静默无操作。
/// 物理键盘端通用；触屏端无物理键自然不触发，不影响移动 IA。
class TaskShortcutsController extends ChangeNotifier {
  int _newReminderTicket = 0;
  int _focusSearchTicket = 0;
  int _newListTicket = 0;

  /// 自增票据：监听方对比上次处理的票号判断新事件。
  int get newReminderTicket => _newReminderTicket;
  int get focusSearchTicket => _focusSearchTicket;

  /// #249：⌘⇧N（Apple：文件 ▸ 新建列表）。
  int get newListTicket => _newListTicket;

  void requestNewReminder() {
    _newReminderTicket++;
    notifyListeners();
  }

  void requestFocusSearch() {
    _focusSearchTicket++;
    notifyListeners();
  }

  void requestNewList() {
    _newListTicket++;
    notifyListeners();
  }
}

/// 快捷键包装器：包在任务区外层；controller 经 InheritedWidget 下发。
class TaskShortcuts extends StatefulWidget {
  const TaskShortcuts({super.key, required this.child});

  final Widget child;

  /// 取最近外层控制器；未包 TaskShortcuts 时返回空实现（快捷键静默）。
  static TaskShortcutsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_TaskShortcutsScope>();
    return scope?.controller ?? TaskShortcutsController();
  }

  @override
  State<TaskShortcuts> createState() => _TaskShortcutsState();
}

class _TaskShortcutsState extends State<TaskShortcuts> {
  final _controller = TaskShortcutsController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 已有外层控制器（壳层包了一层 / 测试注入）时直接复用，不再建第二层：
    // 两层 scope 会让下层监听挂在列表内容区自己的控制器上，而按键走了外层，
    // 表现就是「某些快捷键进来没反应」（#249 排查中确认）。
    if (context.dependOnInheritedWidgetOfExactType<_TaskShortcutsScope>() !=
        null) {
      return widget.child;
    }
    return _TaskShortcutsScope(
      controller: _controller,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyN, meta: true):
              _NewReminderIntent(),
          SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              _FocusSearchIntent(),
          // #249：Apple ⇧⌘N = 新建列表（TC-UI-316 的快捷键入口）
          SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
              _NewListIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _NewReminderIntent: CallbackAction<_NewReminderIntent>(
              onInvoke: (_) {
                _controller.requestNewReminder();
                return null;
              },
            ),
            _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
              onInvoke: (_) {
                _controller.requestFocusSearch();
                return null;
              },
            ),
            _NewListIntent: CallbackAction<_NewListIntent>(
              onInvoke: (_) {
                _controller.requestNewList();
                return null;
              },
            ),
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _TaskShortcutsScope extends InheritedWidget {
  const _TaskShortcutsScope({
    required this.controller,
    required super.child,
  });

  final TaskShortcutsController controller;

  @override
  bool updateShouldNotify(_TaskShortcutsScope oldWidget) =>
      controller != oldWidget.controller;
}

class _NewReminderIntent extends Intent {
  const _NewReminderIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

/// #249：⌘⇧N → 新建列表。
class _NewListIntent extends Intent {
  const _NewListIntent();
}
