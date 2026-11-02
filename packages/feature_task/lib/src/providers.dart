import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 仓库契约 Provider：feature_task 内定义与消费，组合根（life_launcher）注入实现。
///
/// 测试中用 `ProviderScope(overrides: [...])` 注入 [InMemoryReminderRepository]；
/// 正式组合根先完成 Drift 开库，再 override 注入。
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  throw UnimplementedError(
    'reminderRepositoryProvider 未注入：请在组合根 ProviderScope.overrides '
    '中 overrideWith 提供 ReminderRepository 实现。',
  );
}, name: 'reminderRepositoryProvider');

/// 全部列表（智能 + 我的）。
final reminderListsProvider = StreamProvider<List<ReminderList>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchLists();
});

/// 条目流家族：`ref.watch(itemsForListProvider(listId))`；
/// 智能列表（`smart.` 前缀）由仓库按语义过滤。
final itemsForListProvider = StreamProvider.family<List<ReminderItem>, String?>(
  (ref, listId) {
    return ref.watch(reminderRepositoryProvider).watchItems(listId: listId);
  },
);

/// 任务偏好端口（TC-UI-120 的持久半边，flutter#124 卡 4）。
///
/// 与其它仓库 Provider 不同，这里给的是**内存默认值**：开源包要能单独跑 UI 冒烟，
/// 偏好缺失不该让界面崩。真实组合根必须 override 成 Drift 实现
/// （`DriftTaskPreferenceRepository`），否则改动只在内存里、重启即丢。
final taskPreferenceRepositoryProvider = Provider<TaskPreferenceRepository>(
  (ref) => InMemoryTaskPreferenceRepository(),
  name: 'taskPreferenceRepositoryProvider',
);

/// 当前任务偏好（无行回契约默认；`.value` 在首帧即可读，UI 不等流）。
final taskPreferenceProvider = StreamProvider<TaskPreference>(
  (ref) => ref.watch(taskPreferenceRepositoryProvider).watchPreference(),
);

/// 全局搜索词（macOS 工具栏搜索 / ⌘F 聚焦；空串 = 不过滤）。
/// Riverpod 3 无 StateProvider，用最小 Notifier 承载可变搜索态。
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Pad/客户端提醒侧栏显隐（线框：隐藏后主区铺满，可再显示）。
///
/// 卡 4b（TC-UI-304/308/309）：视图态写进本地偏好行，冷启动/重开后读回。
final sidebarVisibleProvider = NotifierProvider<SidebarVisibleNotifier, bool>(
  SidebarVisibleNotifier.new,
);

class SidebarVisibleNotifier extends Notifier<bool>
    with _PreferenceBacked<bool> {
  @override
  bool get fallback => true;

  @override
  bool decode(TaskPreference p) => p.sidebarVisible;

  @override
  TaskPreference encode(TaskPreference base, bool value) =>
      base.copyWith(sidebarVisible: value);

  void set(bool value) => write(value);

  void toggle() => write(!state);
}

/// 过滤后的条目流：在仓库语义过滤之上叠加本地文本匹配
/// （标题 / 备注 / 标签，大小写不敏感）+ 「显示已完成」视图偏好
/// （TC-UI-108：默认隐藏已完成；`smart.completed` 完成卡恒显示）。
final filteredItemsForListProvider =
    StreamProvider.family<List<ReminderItem>, String?>((ref, listId) {
      final query = ref.watch(searchQueryProvider).trim().toLowerCase();
      // #256：**严格按列表**取值（默认隐藏，与 TC-UI-108 一致）。
      // 不能再回落全局：全局那一格是「最后一次」，回落会让 A 的开关串到所有列表。
      final perList = ref.watch(showCompletedByListProvider);
      final showCompleted =
          (listId != null && (perList[listId] ?? false)) ||
          listId == 'smart.completed';
      final repo = ref.watch(reminderRepositoryProvider);

      // TC-UI-116 自定义智能列表（smart.custom.*）：filter 从列表元数据读取，
      // 命中集 = 全部未完成条目 ∩ SmartListFilter（首期标签+旗标）。
      // Stream.multi：onCancel 统一取消内层订阅（cursor PR#15 阻断1——
      // 旧 StreamController 版无 dispose，搜索重建 provider 时内层 listen 泄漏叠加）。
      if (listId != null && listId.startsWith('smart.custom.')) {
        return Stream.multi((listener) {
          SmartListFilter? latestFilter;
          List<ReminderItem>? latestAll;
          var hasFilter = false;
          var hasAll = false;

          void emit() {
            if (hasFilter && hasAll) {
              final f = latestFilter;
              final all = latestAll!;
              listener.addSync(
                f == null
                    ? const <ReminderItem>[]
                    : all.where(f.matches).toList(growable: false),
              );
            }
          }

          final subs = [
            repo.watchLists().listen((lists) {
              latestFilter = lists
                  .where((e) => e.id == listId)
                  .firstOrNull
                  ?.smartFilter;
              hasFilter = true;
              emit();
            }),
            repo.watchItems(listId: null).listen((all) {
              latestAll = all;
              hasAll = true;
              emit();
            }),
          ];
          // onCancel：取消两个内层订阅，防泄漏（生命周期归 Stream.multi 管）
          listener
            ..onCancel = () {
              for (final s in subs) {
                s.cancel();
              }
            }
            ..onPause = () {
              for (final s in subs) {
                s.pause();
              }
            }
            ..onResume = () {
              for (final s in subs) {
                s.resume();
              }
            };
        });
      }

      // parity#180：智能列表的完成过滤在仓库层，必须把开关透传下去，
      // 否则「显示已完成」打开后仓库仍不返回已完成项，UI 过滤无从显示。
      return repo
          .watchItems(listId: listId, includeCompleted: showCompleted)
          .map((items) {
            var out = items;
            if (!showCompleted) {
              // 隐藏已完成条目 = 隐藏其整棵子树（cursor PR#11 意见1：只藏父行会让
              // 子任务因 parentId 不在结果集而被孤儿提升为顶层渲染）。
              final byId = {for (final e in items) e.id: e};
              bool subtreeHidden(String id) {
                var cursor = byId[id];
                for (var depth = 0; depth < 64 && cursor != null; depth++) {
                  if (cursor.isCompleted && cursor.parentId == null) {
                    return true;
                  }
                  cursor = cursor.parentId == null
                      ? null
                      : byId[cursor.parentId];
                }
                return false;
              }

              out = items
                  .where((e) => !subtreeHidden(e.id))
                  .toList(growable: false);
            }
            if (query.isEmpty) {
              return List<ReminderItem>.unmodifiable(out);
            }
            return List<ReminderItem>.unmodifiable(
              out
                  .where(
                    (e) =>
                        e.title.toLowerCase().contains(query) ||
                        (e.notes ?? '').toLowerCase().contains(query) ||
                        e.tags.any((t) => t.toLowerCase().contains(query)),
                  )
                  .toList(growable: false),
            );
          });
    });

/// 任务区本地视图偏好存储（组合根注入 SharedPreferences；不参与同步）。
///
/// 与日历 `sidebarPrefsProvider` 同一套路：`dynamic` 规避外包对宿主偏好实现的
/// 耦合；未注入时所有本地记忆退化成「不记忆」，不影响任何主路径。
final taskViewPrefsProvider = Provider<dynamic>((ref) => null);

/// 「显示已完成」的**按列表**记忆（矩阵 row 11「列表内开关」= 对等）。
///
/// Apple：View ▸ Show Completed 是每个列表各自一份，切列表不串味、重开仍在。
/// 线上偏好行只有一个全局 `showCompleted`（服务端契约如此），所以：
/// - 每列表的取舍存在本地 prefs（`lifeos.task.showCompletedByList`，JSON 表）；
/// - 全局那份继续写「最后一次的选择」，维持 TC-UI-308 的读回与既有契约。
final showCompletedByListProvider =
    NotifierProvider<ShowCompletedByListNotifier, Map<String, bool>>(
      ShowCompletedByListNotifier.new,
    );

class ShowCompletedByListNotifier extends Notifier<Map<String, bool>> {
  static const _prefsKey = 'lifeos.task.showCompletedByList';

  @override
  Map<String, bool> build() {
    final prefs = ref.watch(taskViewPrefsProvider);
    final raw = prefs?.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final e in decoded.entries)
          if (e.value is bool) e.key.toString(): e.value as bool,
      };
    } catch (_) {
      return const {};
    }
  }

  /// 记下某列表的取舍；同时把全局偏好写成「最后一次」（服务端同步的那一格）。
  void setFor(String listId, bool value) {
    state = {...state, listId: value};
    ref.read(taskViewPrefsProvider)?.setString(_prefsKey, jsonEncode(state));
    // 全局那一格写「最后一次」，维持 TC-UI-308 读回与既有服务端契约
    ref.read(showCompletedProvider.notifier).set(value);
  }

  bool forList(String? listId) =>
      listId == null ? false : (state[listId] ?? false);

  /// #256 审查：「还原默认」必须连按列表的记忆一起清，否则过滤仍按旧状态
  /// 显示已完成（TC-UI-309 要求视图态整体回默认）。
  void reset() {
    state = const {};
    ref.read(taskViewPrefsProvider)?.remove(_prefsKey);
  }
}

/// 「显示已完成」列表内开关（线框图2 工具行「显示」；TC-UI-108）。
/// 卡 4b：视图态持久（TC-UI-308），默认仍 false——`list_toolbar_test.dart` 钉的就是默认隐藏。
final showCompletedProvider = NotifierProvider<ShowCompletedNotifier, bool>(
  ShowCompletedNotifier.new,
);

class ShowCompletedNotifier extends Notifier<bool>
    with _PreferenceBacked<bool> {
  @override
  bool get fallback => false;

  @override
  bool decode(TaskPreference p) => p.showCompleted;

  @override
  TaskPreference encode(TaskPreference base, bool value) =>
      base.copyWith(showCompleted: value);

  void set(bool value) => write(value);

  void toggle() => write(!state);
}

/// 列表内排序模式（线框图2 工具行「排序」；TC-UI-111。
/// manual = 仓库排序契约 `sortOrder asc, id asc`）。
enum ListSortMode { manual, dueDate, createdDate, title, priority }

/// 卡 4b：排序模式持久（TC-UI-308）。未知存量串按 manual 处理，不炸界面。
ListSortMode listSortModeFromId(String? id) => ListSortMode.values.firstWhere(
  (m) => m.name == id,
  orElse: () => ListSortMode.manual,
);

final listSortModeProvider =
    NotifierProvider<ListSortModeNotifier, ListSortMode>(
      ListSortModeNotifier.new,
    );

class ListSortModeNotifier extends Notifier<ListSortMode>
    with _PreferenceBacked<ListSortMode> {
  @override
  ListSortMode get fallback => ListSortMode.manual;

  @override
  ListSortMode decode(TaskPreference p) => listSortModeFromId(p.sortMode);

  @override
  TaskPreference encode(TaskPreference base, ListSortMode value) =>
      base.copyWith(sortMode: value.name);

  void set(ListSortMode mode) => write(mode);
}

/// 折叠态键（TC-UI-309，flutter#124 卡 4b）：分区头与侧栏分组共用一张键集。
///
/// 键域：`'<listId>|<分区标题>'`（分区随列表，切列表不串味）与
/// `'group:<分组名>'`。日期桶标题（今天/明天/已过期）是**相对**标签，
/// 按标签折叠正是用户点的那一下语义，隔天仍折叠同一个桶。
final collapsedKeysProvider =
    NotifierProvider<CollapsedKeysNotifier, Set<String>>(
      CollapsedKeysNotifier.new,
    );

class CollapsedKeysNotifier extends Notifier<Set<String>>
    with _PreferenceBacked<Set<String>> {
  @override
  Set<String> get fallback => const {};

  @override
  Set<String> decode(TaskPreference p) => {...p.collapsedKeys};

  @override
  TaskPreference encode(TaskPreference base, Set<String> value) =>
      base.copyWith(collapsedKeys: value.toList());

  bool contains(String key) => state.contains(key);

  void toggle(String key) {
    final next = {...state};
    if (!next.remove(key)) next.add(key);
    write(next);
  }

  /// #537：「显示所有子任务 / 隐藏所有子任务」的整体开关，写进视图态键袋。
  ///
  /// 落在 `collapsedKeysJson` 这一列而不是新加 Drift 布尔列：该列已经是带
  /// 命名空间的视图态键袋（`<listId>|<分区标题>` 与 `group:<分组名>` 两类共存），
  /// 再加一个 `view:` 前缀即沿用同一条已测过的持久化与 revision 通路；
  /// 新加列要升 schemaVersion（`db.dart:401` 现为 23）+ 重跑 build_runner + 改掉
  /// 12 个 drift 测试文件里 17 处 `expect(db.schemaVersion, ...)` 硬编码断言
  /// （现读 develop 数的量；上一版这条注释写的「6 处」是错的，在置顶列表那刀一并订正），
  /// 换到的却是完全相同的持久化语义。
  void setSubtasksHidden(bool hidden) {
    final next = {...state}..remove(subtasksHiddenKey);
    if (hidden) next.add(subtasksHiddenKey);
    write(next);
  }

  /// #537：「置顶列表 / 取消置顶列表」。同一个列表一条键，取消即删。
  ///
  /// 同样落在视图态键袋（第三个命名空间 `pinned:`）：这是**本机的侧栏排序偏好**，
  /// 不是列表的业务字段。服务端那行账号级偏好（`zh-cloud-service` 的
  /// `LifeosTaskPreferenceDO` → `lifeos_task_preference`：defaultListId /
  /// allDayRemindTime / defaultReminderMinutes / timeZone / revision）里既没有
  /// 视图态列也没有置顶列，所以现在同步不过去；Apple 的 pin 是跟账户走的，
  /// 要对齐得先加服务端列与契约（已另立 service Issue）。
  void setListPinned(String listId, bool pinned) {
    final key = pinnedListKey(listId);
    final next = {...state}..remove(key);
    if (pinned) next.add(key);
    write(next);
  }
}

/// 子任务显隐开关在视图态键袋里的键（`view:` 命名空间）。
const String subtasksHiddenKey = 'view:subtasksHidden';

/// 视图态键袋里「某个列表被置顶」的键（`pinned:` 命名空间）。
///
/// 分区折叠键长成 `'<listId>|<分区标题>'`（必带 `|`），分组折叠带
/// `group:` 前缀，所以 `pinned:<listId>` 与它们不可能撞键。
String pinnedListKey(String listId) => 'pinned:$listId';

/// #537：把被置顶的自有列表排到前面，其余保持原序（仓库契约
/// `sortOrder asc, id asc`）。智能清单永不参与置顶（`isSmart` 直接留在原位）。
List<ReminderList> orderListsPinnedFirst(
  List<ReminderList> lists,
  Set<String> viewKeys,
) {
  final pinned = <ReminderList>[];
  final rest = <ReminderList>[];
  for (final l in lists) {
    if (!l.isSmart && viewKeys.contains(pinnedListKey(l.id))) {
      pinned.add(l);
    } else {
      rest.add(l);
    }
  }
  if (pinned.isEmpty) return lists;
  return [...pinned, ...rest];
}

/// 视图态 ↔ 本地偏好行的读写桥（flutter#124 卡 4b）。
///
/// `build()` 里必须 **listen** 偏好流：`taskPreferenceProvider` 首帧是
/// `AsyncLoading`，只 `read` 一次会把状态永久钉在默认值上——
/// 「硬编码默认值」那种探针因此测不出红（本卡实测就绿成了假象），
/// 真机上表现为冷启动不读回上次的显示已完成/排序/折叠/侧栏。
mixin _PreferenceBacked<T> on Notifier<T> {
  /// 偏好未落库时的默认值——要与改造前的硬编码默认逐字一致，
  /// 否则 `list_toolbar_test.dart` 那类「默认隐藏已完成」的断言会漂。
  T get fallback;

  /// 偏好行 → 本状态。
  T decode(TaskPreference p);

  /// 本状态 → 偏好行的那一格（其余列从当前行 copyWith，不整体覆盖成默认）。
  TaskPreference encode(TaskPreference base, T value);

  @override
  T build() {
    // ref.listen 的回调参数是 AsyncValue（Riverpod 3），不是裸值——
    // 直接把它喂给 decode 会编译成 Object?，泛型状态就漂了。
    ref.listen(taskPreferenceProvider, (_, next) {
      final p = next.value;
      state = p == null ? fallback : decode(p);
    });
    final p = ref.read(taskPreferenceProvider).value;
    return p == null ? fallback : decode(p);
  }

  void write(T value) {
    state = value;
    final base =
        ref.read(taskPreferenceProvider).value ?? TaskPreference.defaults;
    ref
        .read(taskPreferenceRepositoryProvider)
        .savePreference(encode(base, value));
  }
}

/// 最近一次「完成」前的条目快照，供一步撤销（TC-UI-122）。重做不做。
final completionUndoProvider =
    NotifierProvider<CompletionUndoNotifier, ReminderItem?>(
      CompletionUndoNotifier.new,
    );

class CompletionUndoNotifier extends Notifier<ReminderItem?> {
  Timer? _timer;

  @override
  ReminderItem? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void offer(ReminderItem item) {
    _timer?.cancel();
    state = item;
    _timer = Timer(const Duration(seconds: 4), () {
      if (state?.id == item.id) state = null;
    });
  }

  void clear() {
    _timer?.cancel();
    state = null;
  }
}

/// 勾选完成。未完成 → 完成时记下快照；已完成再勾只是取消完成，不记撤销。
///
/// #418：这里同时是 `markComplete` 的消费者——开着时勾掉某父提醒的**最后一个**
/// 子任务，会把父提醒一并标记完成（Apple「完成时标记为已完成」）；关掉时父提醒
/// 只跟着子任务进度显示 `2/2`，不会自己变成已完成。
Future<void> completeReminder(WidgetRef ref, ReminderItem item) async {
  final repo = ref.read(reminderRepositoryProvider);
  final justCompleted = !item.isCompleted;
  if (justCompleted) {
    ref.read(completionUndoProvider.notifier).offer(item);
  }
  await repo.toggleCompleted(item.id);
  final parentId = item.parentId;
  if (!justCompleted || parentId == null) {
    return;
  }
  await _cascadeParentCompleted(ref, repo, parentId);
}

Future<void> _cascadeParentCompleted(
  WidgetRef ref,
  ReminderRepository repo,
  String parentId,
) async {
  final pref = await ref
      .read(taskPreferenceRepositoryProvider)
      .watchPreference()
      .first;
  if (!pref.markComplete) {
    return;
  }
  final items = await repo.watchItems(listId: null).first;
  final siblings = items.where((e) => e.parentId == parentId);
  if (siblings.isEmpty || !siblings.every((e) => e.isCompleted)) {
    return;
  }
  final parents = items.where((e) => e.id == parentId);
  if (parents.isEmpty || parents.first.isCompleted) {
    return;
  }
  await repo.toggleCompleted(parentId);
}

/// 子任务进度（parity#166）：父 id → (已完成数, 总数)。
///
/// 不依赖当前列表的过滤结果——智能视图会按 dueAt 过滤掉子任务，若从
/// `items` 现算，父行在「今天/计划」里永远显示不出 `1/2`。
final subtaskProgressProvider =
    StreamProvider<Map<String, ({int done, int total})>>((ref) {
      return ref.watch(reminderRepositoryProvider).watchItems(listId: null).map(
        (items) {
          final byParent = <String, ({int done, int total})>{};
          for (final e in items) {
            final parent = e.parentId;
            if (parent == null || e.deletedAt != null) continue;
            final cur = byParent[parent] ?? (done: 0, total: 0);
            byParent[parent] = (
              done: cur.done + (e.isCompleted ? 1 : 0),
              total: cur.total + 1,
            );
          }
          return byParent;
        },
      );
    }, name: 'subtaskProgressProvider');

/// 可注入的挂钟（#333）。
///
/// 生产默认 `DateTime.now`；测试 override 成固定时刻，让「已过期/今天/上午/下午」
/// 分组与 golden 基线**确定化**——与 `feature_calendar` 的 `clockProvider` 同形状
/// （不急着抽到 `app_core`：等第三个模块也要用时再说）。
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// #486：智能列表可见性（侧栏显示/隐藏 今天/计划/全部 等）。
final smartListsVisibleProvider = NotifierProvider<SmartListsVisibleNotifier, bool>(
  SmartListsVisibleNotifier.new,
);

class SmartListsVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
