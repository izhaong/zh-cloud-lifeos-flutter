import 'dart:async';
import 'dart:convert';

import '../models/note.dart';
import '../models/note_folder.dart';
import '../logic/note_rules.dart';
import '../models/note_tag.dart';

/// 记录数据端口（契约 §5；开源包唯一数据入口，禁止依赖 HTTP）。
///
/// 编辑语义对齐提醒/日历端口：全字段编辑 = UI 层构造/复制模型 +
/// [upsertNote]/[upsertFolder] 全量回写。`watch*` 返回 [Stream]，
/// 任何写操作后订阅方收到新快照。
abstract interface class NoteRepository {
  /// 全部文件夹（树数据；UI 按 parentId 还原层级）。
  Stream<List<NoteFolder>> watchFolders();

  /// 笔记查询；[folderId] 为普通文件夹 = 该文件夹内容，为智能文件夹
  /// id = 按 [NoteFolder.filterJson] 过滤（tagNames/folderId/pinned/
  /// updatedWithinDays），空 = 全部未删除笔记。
  Stream<List<Note>> watchNotes({String? folderId});

  /// 「最近删除」：全部软删笔记（按删除时间倒序；F-06 恢复入口）。
  Stream<List<Note>> watchDeleted();

  /// 全部标签。
  Stream<List<NoteTag>> watchTags();

  /// 新增或更新文件夹，返回 id。
  Future<String> upsertFolder(NoteFolder folder);

  /// 删除文件夹（#373）。
  ///
  /// **语义**：调用方负责先把文件夹内的笔记 [softDelete]（Apple：删除文件夹会把
  /// 里面的备忘录移到「最近删除」），本方法只负责把文件夹本身移除。
  Future<void> deleteFolder(String folderId);

  /// 新增或更新笔记（全量回写；归一纯文本/清单计数在内核做同口径），
  /// 返回 id。
  Future<String> upsertNote(Note note);

  /// 软删笔记（进「最近删除」30 天回收窗）。
  Future<void> softDelete(String noteId);

  /// 从「最近删除」恢复（30 天内）。
  Future<void> restore(String noteId);

  /// 硬删回收窗超期（>30 天）笔记，返回清理条数。
  Future<int> purgeExpired();

  /// 标题/纯文本搜索（跳过锁定笔记密文）。
  Future<List<Note>> search(String keyword, {int limit = 50});

  /// 重新命名标签（#661）：所有使用 [oldName] 的备忘录与智能文件夹条件同步
  /// 改为 [newName]。空 [newName] 或与原名相同 = 忽略。
  ///
  /// 标签是从存活笔记的 `tagNames` 派生的视图，没有独立实体；改名就是批量
  /// 改写引用。UI 负责把当前选中的标签一起迁移，否则列表会被旧名过滤成空。
  Future<void> renameTag(String oldName, String newName);

  /// 删除标签（#661）：从所有使用了 [name] 的备忘录与智能文件夹条件移除。
  ///
  /// 含「最近删除」里的笔记也一并改写：Apple 说从「所有使用了这些标签的
  /// 备忘录」中删除，只改活笔记会让恢复的笔记把已删标签复活出来。
  Future<void> deleteTag(String name);
}

/// 内存实现：壳层与 UI 冒烟 + 仓库契约测试的参考实现。
final class InMemoryNoteRepository implements NoteRepository {
  /// 回收窗时长（Apple 口径 30 天）。
  static const Duration recycleWindow = Duration(days: 30);

  final _folders = <NoteFolder>[];
  final _notes = <Note>[];
  final _emitters = <void Function()>[];
  DateTime? _nowForTest;

  /// 测试注入「当前时间」（purge 判定用）。
  set nowForTest(DateTime? value) => _nowForTest = value;

  DateTime get _now => _nowForTest ?? DateTime.now();

  /// 测试助手：把指定笔记的删除时间回拨 [age]（模拟过期删除）。
  void debugAgeDeletion(String noteId, Duration age) {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i < 0 || _notes[i].deletedAt == null) return;
    _notes[i] = _copyWithDeletedAt(_notes[i], _now.subtract(age));
  }

  @override
  Stream<List<NoteFolder>> watchFolders() =>
      _watch(() => List<NoteFolder>.unmodifiable(_folders));

  @override
  Stream<List<Note>> watchNotes({String? folderId}) =>
      _watch(() => _notesSnapshot(folderId));

  @override
  Stream<List<Note>> watchDeleted() => _watch(() {
        final deleted = _notes.where((n) => n.deletedAt != null).toList()
          ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
        return List<Note>.unmodifiable(deleted);
      });

  @override
  Stream<List<NoteTag>> watchTags() => _watch(() {
        // #393：侧栏「标签」分区要读这里。此前 `_tags` 从来没有写入口，
        // 参考实现恒返回空列表——落盘版 DriftNoteRepository 早已改成「从存活
        // 笔记的 tagNames 派生」，内存版照同一口径派生，两套实现给 UI 的答案一致。
        final names = <String>{};
        for (final note in _notesSnapshot(null)) {
          for (final name in note.tagNames) {
            if (name.isNotEmpty) names.add(name);
          }
        }
        final sorted = names.toList()..sort();
        return List<NoteTag>.unmodifiable(
          sorted.map((name) => NoteTag(id: name, name: name)),
        );
      });

  @override
  Future<String> upsertFolder(NoteFolder folder) async {
    final i = _folders.indexWhere((f) => f.id == folder.id);
    if (i >= 0) {
      _folders[i] = folder;
    } else {
      _folders.add(folder);
    }
    _notify();
    return folder.id;
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((f) => f.id == folderId);
    _notify();
  }

  @override
  Future<String> upsertNote(Note note) async {
    final normalized = _normalize(note);
    final i = _notes.indexWhere((n) => n.id == normalized.id);
    if (i >= 0) {
      // 防复活：软删行只经 restore 恢复；全量回写丢失 deletedAt 时保留标记
      final existing = _notes[i];
      _notes[i] = existing.deletedAt != null && normalized.deletedAt == null
          ? _copyWithDeletedAt(normalized, existing.deletedAt!)
          : normalized;
    } else {
      _notes.add(normalized);
    }
    _notify();
    return normalized.id;
  }

  @override
  Future<void> softDelete(String noteId) async {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    _notes[i] = _copyWithDeletedAt(_notes[i], _now);
    _notify();
  }

  @override
  Future<void> restore(String noteId) async {
    final i = _notes.indexWhere((n) => n.id == noteId);
    if (i < 0) return;
    final n = _notes[i];
    if (n.deletedAt == null) return;
    _notes[i] = Note(
      id: n.id,
      folderId: n.folderId,
      title: n.title,
      bodyDelta: n.bodyDelta,
      bodyText: n.bodyText,
      pinned: n.pinned,
      locked: n.locked,
      checklistTotal: n.checklistTotal,
      checklistDone: n.checklistDone,
      tagNames: n.tagNames,
      sortOrder: n.sortOrder,
      revision: n.revision,
      clientUpdatedAt: n.clientUpdatedAt,
    ); // deletedAt 置空
    _notify();
  }

  @override
  Future<int> purgeExpired() async {
    final cutoff = _now.subtract(recycleWindow);
    final before = _notes.length;
    _notes.removeWhere(
        (n) => n.deletedAt != null && !n.deletedAt!.isAfter(cutoff));
    final removed = before - _notes.length;
    if (removed > 0) _notify();
    return removed;
  }

  @override
  Future<List<Note>> search(String keyword, {int limit = 50}) async {
    // 大小写不敏感，与 Drift 侧 SQLite LIKE、#660 的高亮切段同口径。
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return const [];
    final hits = _notes
        .where((n) =>
            n.deletedAt == null &&
            !n.locked &&
            (n.title.toLowerCase().contains(kw) ||
                n.bodyText.toLowerCase().contains(kw)))
        .take(limit)
        .toList(growable: false);
    return hits;
  }

  @override
  Future<void> renameTag(String oldName, String newName) async {
    _rewriteTags(oldName, newName);
  }

  @override
  Future<void> deleteTag(String name) async {
    _rewriteTags(name, null);
  }

  /// 两端实现共用 [rewriteTagNames]/[rewriteTagFilter] 纯规则，保证「内存版绿、
  /// 落盘版另一套行为」不会重演。整轮只在真的改动后才 [_notify]。
  void _rewriteTags(String name, String? replacement) {
    if (name.isEmpty || replacement == name) return;
    if (replacement != null && replacement.isEmpty) return;
    var changed = false;

    // 含「最近删除」里的笔记：只改活笔记的话，恢复后旧标签会复活。
    for (var i = 0; i < _notes.length; i++) {
      final next = rewriteTagNames(
        _notes[i].tagNames,
        name: name,
        replacement: replacement,
      );
      if (next == null) continue;
      _notes[i] = _copyWithTags(_notes[i], next);
      changed = true;
    }

    for (var i = 0; i < _folders.length; i++) {
      final folder = _folders[i];
      if (!folder.smart) continue;
      final next = rewriteTagFilter(
        folder.filterJson,
        name: name,
        replacement: replacement,
      );
      if (next == null) continue;
      _folders[i] = NoteFolder(
        id: folder.id,
        parentId: folder.parentId,
        name: folder.name,
        smart: folder.smart,
        filterJson: next,
        sortOrder: folder.sortOrder,
      );
      changed = true;
    }
    if (changed) _notify();
  }

  // ---- 内部 ----

  /// 保存归一（TC-NOTE-KR-102/105）：未锁定抽纯文本 + 清点清单；
  /// 锁定 bodyText 强制空、清单清零（TC-NOTE-KR-107 开源包半）。
  Note _normalize(Note n) {
    if (n.locked) {
      return Note(
        id: n.id,
        folderId: n.folderId,
        title: n.title,
        bodyDelta: n.bodyDelta,
        bodyText: '',
        pinned: n.pinned,
        locked: true,
        tagNames: n.tagNames,
        sortOrder: n.sortOrder,
        deletedAt: n.deletedAt,
        revision: n.revision,
        clientUpdatedAt: n.clientUpdatedAt,
      );
    }
    final text = extractPlainText(n.bodyDelta);
    final counts = countChecklist(n.bodyDelta);
    return Note(
      id: n.id,
      folderId: n.folderId,
      title: n.title,
      bodyDelta: n.bodyDelta,
      bodyText: text,
      pinned: n.pinned,
      locked: false,
      checklistTotal: counts[0],
      checklistDone: counts[1],
      tagNames: n.tagNames,
      sortOrder: n.sortOrder,
      deletedAt: n.deletedAt,
      revision: n.revision,
      clientUpdatedAt: n.clientUpdatedAt,
    );
  }

  Note _copyWithDeletedAt(Note n, DateTime at) => Note(
        id: n.id,
        folderId: n.folderId,
        title: n.title,
        bodyDelta: n.bodyDelta,
        bodyText: n.bodyText,
        pinned: n.pinned,
        locked: n.locked,
        checklistTotal: n.checklistTotal,
        checklistDone: n.checklistDone,
        tagNames: n.tagNames,
        sortOrder: n.sortOrder,
        deletedAt: at,
        revision: n.revision,
        clientUpdatedAt: n.clientUpdatedAt,
      );

  /// [Note] 没有 copyWith（模型是 immutable 且字段与落库表一一对应），
  /// 标签批量改写只能全量重建；其余字段原样带过，尤其 `deletedAt`/`revision`。
  Note _copyWithTags(Note n, List<String> tags) => Note(
        id: n.id,
        folderId: n.folderId,
        title: n.title,
        bodyDelta: n.bodyDelta,
        bodyText: n.bodyText,
        pinned: n.pinned,
        locked: n.locked,
        checklistTotal: n.checklistTotal,
        checklistDone: n.checklistDone,
        tagNames: tags,
        sortOrder: n.sortOrder,
        deletedAt: n.deletedAt,
        revision: n.revision,
        clientUpdatedAt: n.clientUpdatedAt,
      );

  List<Note> _notesSnapshot(String? folderId) {
    final alive = _notes.where((n) => n.deletedAt == null);
    Iterable<Note> scoped = alive;
    NoteFolder? folder;
    for (final f in _folders) {
      if (f.id == folderId) {
        folder = f;
        break;
      }
    }
    if (folder != null && folder.smart) {
      scoped = _applySmartFilter(scoped, folder);
    } else if (folderId != null) {
      scoped = scoped.where((n) => n.folderId == folderId);
    }
    // 排序：pinned desc → sortOrder asc → id asc（TC-NOTE-KR-103）
    final list = scoped.toList(growable: false)
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return List<Note>.unmodifiable(list);
  }

  /// 智能文件夹过滤（契约 §1：tagNames/folderId/pinned/updatedWithinDays；
  /// 空条件 = 全部未删除笔记——alive 已过滤未删）。
  Iterable<Note> _applySmartFilter(Iterable<Note> src, NoteFolder folder) {
    final filter = _parseFilter(folder.filterJson);
    Iterable<Note> result = src;
    if (filter.containsKey('tagNames')) {
      final names = (filter['tagNames'] as List).whereType<String>().toSet();
      result = result.where((n) => n.tagNames.any(names.contains));
    }
    if (filter.containsKey('folderId')) {
      final fid = filter['folderId'];
      if (fid is String && fid.isNotEmpty) {
        result = result.where((n) => n.folderId == fid);
      }
    }
    if (filter.containsKey('pinned')) {
      final pinned = filter['pinned'] == true;
      result = result.where((n) => n.pinned == pinned);
    }
    if (filter.containsKey('updatedWithinDays')) {
      final days = filter['updatedWithinDays'];
      if (days is num && days > 0) {
        final cutoff =
            _now.subtract(Duration(days: days.toInt())).millisecondsSinceEpoch;
        result = result.where((n) => n.clientUpdatedAt >= cutoff);
      }
    }
    return result;
  }

  Map _parseFilter(String? filterJson) {
    if (filterJson == null || filterJson.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(filterJson);
      return decoded is Map ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  // ---- 订阅 ----

  /// 每个订阅持有自己的 controller 与重算闭包；写后 ping 全部。
  Stream<List<T>> _watch<T>(List<T> Function() snapshot) {
    late final StreamController<List<T>> controller;
    void emit() => controller.add(snapshot());
    controller = StreamController<List<T>>.broadcast(onListen: emit);
    _emitters.add(emit);
    controller.onCancel = () {
      _emitters.remove(emit);
    };
    return controller.stream;
  }

  void _notify() {
    for (final emit in _emitters.toList(growable: false)) {
      emit();
    }
  }

  // ---- Delta 解析（公开静态：Drift/UI 复用同一口径） ----

  /// ops[].insert 串接（与服务端 QuillDeltaParser 同口径；TC-NOTE-KR-102）。
  static String extractPlainText(String bodyDelta) =>
      extractNotePlainText(bodyDelta);

  /// attributes.list 非空计 total、checked 计 done（TC-NOTE-KR-105）。
  ///
  /// 兼容两种落点：Quill 行属性在行尾 `\n` op 上；内核夹具把 list 挂在文本 op 上。
  /// 同一行两处都带相同 list 时只计一次（以 `\n` 为准）。
  static List<int> countChecklist(String bodyDelta) =>
      countNoteChecklist(bodyDelta);
}
