import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

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
final visibleNotesProvider = StreamProvider<List<Note>>((ref) {
  final folderId = ref.watch(selectedNoteFolderIdProvider);
  return ref.watch(noteRepositoryProvider).watchNotes(folderId: folderId);
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

/// 记录设置（默认文件夹 + 排序；本地偏好，不落服务端）。
class NoteSettings {
  const NoteSettings({
    this.defaultFolderId,
    this.sortMode = NoteSortMode.custom,
  });

  final String? defaultFolderId;
  final NoteSortMode sortMode;
}

/// 记录设置读写（#394：改完要能重启读回）。
///
/// `Notifier.build()` 里不能起异步副作用，所以初值取流的 `.value`、再用
/// `ref.listen` 把后续推送写回状态——与任务侧 `_PreferenceBacked` 同形状。
class NoteSettingsNotifier extends Notifier<NoteSettings> {
  @override
  NoteSettings build() {
    ref.listen(notePreferenceProvider, (_, next) {
      state = _decode(next.value);
    });
    return _decode(ref.read(notePreferenceProvider).value);
  }

  static NoteSettings _decode(NotePreference? p) => NoteSettings(
    defaultFolderId: p?.defaultFolderId,
    sortMode: noteSortModeFromId(p?.sortMode),
  );

  /// 写库；其余格子从当前行原样带过，不整体覆盖成默认。
  Future<void> _write(NoteSettings next) async {
    state = next;
    final base =
        ref.read(notePreferenceProvider).value ?? NotePreference.defaults;
    await ref.read(notePreferenceRepositoryProvider).savePreference(
      base.copyWith(
        defaultFolderId: next.defaultFolderId,
        // 「默认文件夹 = null」是「跟随当前文件夹」，只能走显式清空通道。
        clearDefaultFolderId: next.defaultFolderId == null,
        sortMode: next.sortMode.name,
      ),
    );
  }

  void setDefaultFolder(String? folderId) {
    _write(NoteSettings(defaultFolderId: folderId, sortMode: state.sortMode));
  }

  void setSortMode(NoteSortMode mode) {
    _write(
      NoteSettings(defaultFolderId: state.defaultFolderId, sortMode: mode),
    );
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
