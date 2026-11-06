import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// #658：列表行内相对日期的时钟注入缝。
///
/// 生产取 `DateTime.now`；测试用 `ProviderScope.overrides` 固定到某一刻，
/// 否则「今天 / 昨天 / 星期三」会随运行当天漂移，断言钉不死。
final noteClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'noteClockProvider',
);

/// 仓库契约 Provider：feature_note 内定义与消费，组合根（life_launcher）注入实现。
///
/// 默认抛错：未注入即显式失败（照 reminderRepositoryProvider 口径，契约 §5）。
/// 组合根用 ProviderScope.overrides 注入 InMemoryNoteRepository（F-03）或
/// DriftNoteRepository（F-02 之后的 Drift 实现随 F-04 接线）。
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  throw StateError(
    'NoteRepository 未注入：请在组合根 ProviderScope.overrides '
    '中 overrideWith 提供 NoteRepository 实现。',
  );
}, name: 'noteRepositoryProvider');

/// 全部文件夹（侧栏树数据；UI 按 parentId 还原层级）。
final noteFoldersProvider = StreamProvider<List<NoteFolder>>((ref) {
  return ref.watch(noteRepositoryProvider).watchFolders();
});

/// 「最近删除」（F-06：删除进回收、可恢复）。
final deletedNotesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchDeleted();
});

/// 全部标签。
final noteTagsProvider = StreamProvider<List<NoteTag>>((ref) {
  return ref.watch(noteRepositoryProvider).watchTags();
});

/// 当前选中文件夹（null = 全部未删除笔记）。Riverpod 3 无 StateProvider，
/// 用 Notifier 承载（照日历 anchorDateProvider 口径）。
class SelectedNoteFolderNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? folderId) => state = folderId;
}

final selectedNoteFolderIdProvider =
    NotifierProvider<SelectedNoteFolderNotifier, String?>(
        SelectedNoteFolderNotifier.new);

/// 侧栏「标签」分区的选中标签名（null = 不按标签过滤；#393）。
///
/// 与 [selectedNoteFolderIdProvider] 互斥（由侧栏在点选时清另一侧）：Apple 的
/// 侧栏一次只有一个高亮项，若允许「文件夹 + 标签」同时高亮，列表到底按哪个过滤
/// 从界面上读不出来。
class SelectedNoteTagNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? tagName) => state = tagName;
}

final selectedNoteTagProvider =
    NotifierProvider<SelectedNoteTagNotifier, String?>(
        SelectedNoteTagNotifier.new);

/// 侧栏数量徽章的读数（#393）。
class NoteSidebarCounts {
  const NoteSidebarCounts({
    required this.total,
    required this.byFolder,
    required this.byTag,
  });

  const NoteSidebarCounts.empty()
    : total = 0,
      byFolder = const <String, int>{},
      byTag = const <String, int>{};

  /// 全部未删除笔记（「所有备忘录」的徽章）。
  final int total;

  /// folderId → 该文件夹直接持有的笔记数（子文件夹不算进父级，与 Apple 一致）。
  final Map<String, int> byFolder;

  /// 标签名 → 打了该标签的笔记数。
  final Map<String, int> byTag;

  int folderCount(String folderId) => byFolder[folderId] ?? 0;

  int tagCount(String tagName) => byTag[tagName] ?? 0;
}

/// 侧栏徽章计数（#393）：一次订阅全量未删除笔记，就地按 folderId / tagNames 计数。
///
/// 智能文件夹的徽章要按 `filterJson` 求值（矩阵 N14 的降级口径另单跟），这里不猜
/// 数字——侧栏对智能行不摆徽章，避免把一个算错的数量当成事实。
final noteSidebarCountsProvider = StreamProvider<NoteSidebarCounts>((ref) {
  return ref.watch(noteRepositoryProvider).watchNotes(folderId: null).map((notes) {
    final byFolder = <String, int>{};
    final byTag = <String, int>{};
    for (final note in notes) {
      byFolder[note.folderId] = (byFolder[note.folderId] ?? 0) + 1;
      for (final tag in note.tagNames.toSet()) {
        byTag[tag] = (byTag[tag] ?? 0) + 1;
      }
    }
    return NoteSidebarCounts(
      total: notes.length,
      byFolder: byFolder,
      byTag: byTag,
    );
  });
});

/// 搜索词（空 = 不搜索；F-07）。
class NoteSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final noteSearchQueryProvider =
    NotifierProvider<NoteSearchQueryNotifier, String>(
        NoteSearchQueryNotifier.new);

/// 搜索结果（标题或 bodyText；跳过锁定笔记）。
final noteSearchResultsProvider = FutureProvider<List<Note>>((ref) async {
  final query = ref.watch(noteSearchQueryProvider).trim();
  if (query.isEmpty) {
    return const <Note>[];
  }
  return ref.watch(noteRepositoryProvider).search(query);
});

/// 当前文件夹的笔记列表（folderId 为智能文件夹 id 时按条件求值；
/// 排序由仓库保证：pinned 前、sortOrder asc、id asc）。
///
/// #393：侧栏「标签」分区选中时，在同一条流上再按标签过滤。标签为 null 时
/// 直接返回仓库的原始流，不额外 `map`——避免给既有列表加一层无谓的重建。
final visibleNotesProvider = StreamProvider<List<Note>>((ref) {
  final folderId = ref.watch(selectedNoteFolderIdProvider);
  final tagName = ref.watch(selectedNoteTagProvider);
  final notes = ref
      .watch(noteRepositoryProvider)
      .watchNotes(folderId: folderId);
  if (tagName == null) return notes;
  return notes.map(
    (list) => list.where((n) => n.tagNames.contains(tagName)).toList(),
  );
});


/// 选图端口（F-09）：返回本地文件路径；测试注入假实现，不触盘。
final noteImagePickerProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    return file?.path;
  };
});


/// 列表 / 画廊视图（F-10）；false = 列表。
class NoteGalleryModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final noteGalleryModeProvider =
    NotifierProvider<NoteGalleryModeNotifier, bool>(
        NoteGalleryModeNotifier.new);


/// 列表排序方式（F-13 本地偏好）。
enum NoteSortMode { custom, title, updated }

/// 档位名串 → 枚举；存量脏值退回 `custom`，不让一条坏值炸了设置页
/// （照任务侧 `listSortModeFromId` 的口径）。
NoteSortMode noteSortModeFromId(String? id) => NoteSortMode.values.firstWhere(
  (m) => m.name == id,
  orElse: () => NoteSortMode.custom,
);

/// 记录偏好端口（TC-NOTE-UI-111 的持久半边，#394）。
///
/// 与其它仓库 Provider 不同，这里给的是**内存默认值**：开源包要能单独跑 UI
/// 冒烟。真实组合根必须 override 成 Drift 实现（`DriftNotePreferenceRepository`），
/// 否则改动只在内存里、重启即丢（就是 #394 的缺陷形态）。
final notePreferenceRepositoryProvider = Provider<NotePreferenceRepository>(
  (ref) => InMemoryNotePreferenceRepository(),
  name: 'notePreferenceRepositoryProvider',
);

/// 当前记录偏好（无行回契约默认；`.value` 在首帧即可读，UI 不等流）。
final notePreferenceProvider = StreamProvider<NotePreference>(
  (ref) => ref.watch(notePreferenceRepositoryProvider).watchPreference(),
);

/// 新备忘录开头格式（#392，Apple「新备忘录开头格式」弹出菜单四档）。
///
/// `nothing` = 空白正文（老行为）；`title`/`body` 只挪光标；`checklist` 真的往
/// 正文种一个未勾选清单项——所以这四档都有可观察后果，不摆空控件。
enum NoteBeginWithMode { nothing, title, body, checklist }

NoteBeginWithMode noteBeginWithModeFromId(String? id) =>
    NoteBeginWithMode.values.firstWhere(
      (m) => m.name == id,
      orElse: () => NoteBeginWithMode.nothing,
    );

/// 记录设置（默认文件夹 + 排序 + 分组 + 开头格式；本地偏好，不落服务端）。
class NoteSettings {
  const NoteSettings({
    this.defaultFolderId,
    this.sortMode = NoteSortMode.custom,
    this.groupByDate = true,
    this.beginWith = NoteBeginWithMode.nothing,
    this.defaultTextSize = 16,
  });

  final String? defaultFolderId;
  final NoteSortMode sortMode;

  /// 列表是否按日期分组（Apple「按日期分组备忘录」）。
  final bool groupByDate;

  final NoteBeginWithMode beginWith;

  /// 默认正文文本大小（磅；#463，Apple「默认文本大小」滑块）。
  final int defaultTextSize;

  /// 设置页每次只改一格，其余格子必须原样带过；格子加到第四个之后，逐个手写
  /// 实参的写法早晚会把某格打回默认，所以收在这里。
  NoteSettings copyWith({
    String? defaultFolderId,
    bool clearDefaultFolderId = false,
    NoteSortMode? sortMode,
    bool? groupByDate,
    NoteBeginWithMode? beginWith,
    int? defaultTextSize,
  }) {
    return NoteSettings(
      defaultFolderId: clearDefaultFolderId
          ? null
          : (defaultFolderId ?? this.defaultFolderId),
      sortMode: sortMode ?? this.sortMode,
      groupByDate: groupByDate ?? this.groupByDate,
      beginWith: beginWith ?? this.beginWith,
      defaultTextSize: defaultTextSize ?? this.defaultTextSize,
    );
  }
}

/// 记录设置读写（#394：改完要能重启读回）。
///
/// `Notifier.build()` 里不能起异步副作用，所以初值取流的 `.value`、再用
/// `ref.listen` 把后续推送写回状态——与任务侧 `_PreferenceBacked` 同形状。
class NoteSettingsNotifier extends Notifier<NoteSettings> {
  /// 本地是否已经写过。写过之后，偏好流的回推不再覆盖本地状态。
  ///
  /// 四格并存之后这条必须留：一笔保存的回推带的是「只有前一格改了」的旧行，
  /// 它在下一笔写之后才到达时，会把刚写的那格打回旧档（连点排序 + 分组 +
  /// 开头格式即可复现）。记录偏好是本地单用户一行、不同步到服务端，
  /// 不存在别处的写入需要靠这条回推同步，所以以本地为准是安全的。
  bool _localWriteIssued = false;

  @override
  NoteSettings build() {
    ref.listen(notePreferenceProvider, (_, next) {
      if (_localWriteIssued) return;
      state = _decode(next.value);
    });
    return _decode(ref.read(notePreferenceProvider).value);
  }

  static NoteSettings _decode(NotePreference? p) => NoteSettings(
    defaultFolderId: p?.defaultFolderId,
    sortMode: noteSortModeFromId(p?.sortMode),
    groupByDate: p?.groupByDate ?? true,
    beginWith: noteBeginWithModeFromId(p?.beginWith),
    defaultTextSize: p?.defaultTextSize ?? 16,
  );

  /// 写库；其余格子从当前行原样带过，不整体覆盖成默认。
  Future<void> _write(NoteSettings next) async {
    state = next;
    _localWriteIssued = true;
    final base =
        ref.read(notePreferenceProvider).value ?? NotePreference.defaults;
    await ref.read(notePreferenceRepositoryProvider).savePreference(
      base.copyWith(
        defaultFolderId: next.defaultFolderId,
        // 「默认文件夹 = null」是「跟随当前文件夹」，只能走显式清空通道。
        clearDefaultFolderId: next.defaultFolderId == null,
        sortMode: next.sortMode.name,
        groupByDate: next.groupByDate,
        beginWith: next.beginWith.name,
        defaultTextSize: next.defaultTextSize,
      ),
    );
  }

  void setDefaultFolder(String? folderId) {
    _write(
      state.copyWith(
        defaultFolderId: folderId,
        clearDefaultFolderId: folderId == null,
      ),
    );
  }

  void setSortMode(NoteSortMode mode) {
    _write(state.copyWith(sortMode: mode));
  }

  void setGroupByDate(bool value) {
    _write(state.copyWith(groupByDate: value));
  }

  void setBeginWith(NoteBeginWithMode mode) {
    _write(state.copyWith(beginWith: mode));
  }

  /// 默认文本大小（#463）：夹到 13..24，越界值不写库。
  void setDefaultTextSize(int size) {
    if (size < 13 || size > 24) return;
    _write(state.copyWith(defaultTextSize: size));
  }
}

final noteSettingsProvider =
    NotifierProvider<NoteSettingsNotifier, NoteSettings>(
        NoteSettingsNotifier.new);


/// 共享端口（F-14；接口未合并时用假端口，开源包不打网络）。
abstract interface class NoteSharePort {
  /// 端口是否真的能共享。假端口为 false，界面据此不摆出共享入口（#396）。
  bool get isAvailable;

  Future<void> share({
    required String noteId,
    required String targetUserId,
    required bool writable,
  });
}

final class _UnavailableNoteSharePort implements NoteSharePort {
  @override
  bool get isAvailable => false;

  @override
  Future<void> share({
    required String noteId,
    required String targetUserId,
    required bool writable,
  }) async {
    throw UnsupportedError('共享客户端未接入');
  }
}

final noteSharePortProvider = Provider<NoteSharePort>((ref) {
  return _UnavailableNoteSharePort();
});

/// 三栏宿主里「当前选中的备忘录」（#421；null = 未选/新建态）。
///
/// 窄屏仍是推入页，这个 provider 只在宽屏内嵌宿主里用。
final selectedNoteIdProvider = NotifierProvider<SelectedNoteIdNotifier, String?>(
  SelectedNoteIdNotifier.new,
  name: 'selectedNoteIdProvider',
);

class SelectedNoteIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}
