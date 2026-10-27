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

/// 记录设置（默认文件夹 + 排序；本地偏好，不落服务端）。
class NoteSettings {
  const NoteSettings({this.defaultFolderId, this.sortMode = NoteSortMode.custom});

  final String? defaultFolderId;
  final NoteSortMode sortMode;
}

class NoteSettingsNotifier extends Notifier<NoteSettings> {
  @override
  NoteSettings build() => const NoteSettings();

  void setDefaultFolder(String? folderId) {
    state = NoteSettings(
      defaultFolderId: folderId,
      sortMode: state.sortMode,
    );
  }

  void setSortMode(NoteSortMode mode) {
    state = NoteSettings(
      defaultFolderId: state.defaultFolderId,
      sortMode: mode,
    );
  }
}

final noteSettingsProvider =
    NotifierProvider<NoteSettingsNotifier, NoteSettings>(
        NoteSettingsNotifier.new);


/// 共享端口（F-14；接口未合并时用假端口，开源包不打网络）。
abstract interface class NoteSharePort {
  Future<void> share({
    required String noteId,
    required String targetUserId,
    required bool writable,
  });
}

final class _UnavailableNoteSharePort implements NoteSharePort {
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
