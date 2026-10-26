import 'dart:async';
import 'dart:convert';

import '../models/note.dart';
import '../models/note_folder.dart';
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

  /// 全部标签。
  Stream<List<NoteTag>> watchTags();

  /// 新增或更新文件夹，返回 id。
  Future<String> upsertFolder(NoteFolder folder);

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
}

/// 内存实现：壳层与 UI 冒烟 + 仓库契约测试的参考实现。
final class InMemoryNoteRepository implements NoteRepository {
  /// 回收窗时长（Apple 口径 30 天）。
  static const Duration recycleWindow = Duration(days: 30);

  final _folders = <NoteFolder>[];
  final _notes = <Note>[];
  final _tags = <NoteTag>[];
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
  Stream<List<NoteTag>> watchTags() =>
      _watch(() => List<NoteTag>.unmodifiable(_tags));

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
    final kw = keyword.trim();
    if (kw.isEmpty) return const [];
    final hits = _notes
        .where((n) =>
            n.deletedAt == null &&
            !n.locked &&
            (n.title.contains(kw) || n.bodyText.contains(kw)))
        .take(limit)
        .toList(growable: false);
    return hits;
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
  static String extractPlainText(String bodyDelta) {
    final ops = _parseOps(bodyDelta);
    if (ops == null) return '';
    final sb = StringBuffer();
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is String) sb.write(insert);
    }
    return sb.toString();
  }

  /// attributes.list 非空计 total、checked 计 done（TC-NOTE-KR-105）。
  static List<int> countChecklist(String bodyDelta) {
    final ops = _parseOps(bodyDelta);
    if (ops == null) return const [0, 0];
    var total = 0;
    var done = 0;
    for (final op in ops) {
      final insert = op['insert'];
      final attrs = op['attributes'];
      if (insert is! String || attrs is! Map) continue;
      final list = attrs['list'];
      if (list is String && list.isNotEmpty) {
        total++;
        if (list == 'checked') done++;
      }
    }
    return [total, done];
  }

  static List<Map>? _parseOps(String bodyDelta) {
    if (bodyDelta.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(bodyDelta);
      if (decoded is! Map) return null;
      final ops = decoded['ops'];
      if (ops is! List) return null;
      return ops.whereType<Map>().toList(growable: false);
    } catch (_) {
      return null;
    }
  }
}
