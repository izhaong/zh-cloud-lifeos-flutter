import 'dart:convert';

import '../models/note.dart';
import '../models/note_folder.dart';

/// 记录（备忘录）仓储的**纯规则**（#280）。
///
/// 这些规则原本只写在 [InMemoryNoteRepository] 里；接入 Drift 持久化后两条
/// 实现必须同口径（保存归一 / 列表排序 / 智能文件夹过滤），否则「内存版绿、
/// 落盘版另一套行为」。抽到这里作为唯一事实源。

/// 保存归一（TC-NOTE-KR-102/105/107 开源包半）：
/// - 未锁定：正文抽纯文本、清点清单；
/// - 锁定：`bodyText` 强制空、清单清零（密文只在 `bodyDelta`）。
Note normalizeNoteForSave(Note n) {
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
  final text = extractNotePlainText(n.bodyDelta);
  final counts = countNoteChecklist(n.bodyDelta);
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

/// 列表排序契约（TC-NOTE-KR-103）：置顶优先 → `sortOrder` 升序 → `id` 升序。
List<Note> sortNotesForList(Iterable<Note> src) {
  final list = src.toList(growable: false)
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
  return List<Note>.unmodifiable(list);
}

/// 智能文件夹过滤（契约 §1：`tagNames` / `folderId` / `pinned` /
/// `updatedWithinDays`；空条件 = 全部未删除笔记）。
Iterable<Note> applyNoteSmartFilter(
  Iterable<Note> src,
  NoteFolder folder, {
  required DateTime now,
}) {
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
          now.subtract(Duration(days: days.toInt())).millisecondsSinceEpoch;
      result = result.where((n) => n.clientUpdatedAt >= cutoff);
    }
  }
  return result;
}

Map<dynamic, dynamic> _parseFilter(String? filterJson) {
  if (filterJson == null || filterJson.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(filterJson);
    return decoded is Map ? decoded : const {};
  } catch (_) {
    return const {};
  }
}

/// `ops[].insert` 串接（与服务端 QuillDeltaParser 同口径；TC-NOTE-KR-102）。
String extractNotePlainText(String bodyDelta) {
  final ops = _parseOps(bodyDelta);
  if (ops == null) return '';
  final sb = StringBuffer();
  for (final op in ops) {
    final insert = op['insert'];
    if (insert is String) sb.write(insert);
  }
  return sb.toString();
}

/// `attributes.list` 非空计 total、`checked` 计 done（TC-NOTE-KR-105）。
///
/// 兼容两种落点：Quill 行属性在行尾 `\n` op 上；内核夹具把 list 挂在文本 op 上。
/// 同一行两处都带相同 list 时只计一次（以 `\n` 为准）。
List<int> countNoteChecklist(String bodyDelta) {
  final ops = _parseOps(bodyDelta);
  if (ops == null) return const [0, 0];
  var total = 0;
  var done = 0;
  for (var i = 0; i < ops.length; i++) {
    final insert = ops[i]['insert'];
    if (insert is! String) continue;
    final attrs = ops[i]['attributes'];
    final list = attrs is Map ? attrs['list'] : null;
    if (list is! String || list.isEmpty) continue;
    final isLineEnd = insert.endsWith('\n');
    if (!isLineEnd) {
      final nextInsert = i + 1 < ops.length ? ops[i + 1]['insert'] : null;
      final nextAttrs = i + 1 < ops.length ? ops[i + 1]['attributes'] : null;
      final nextList = nextAttrs is Map ? nextAttrs['list'] : null;
      if (nextInsert is String &&
          nextInsert.endsWith('\n') &&
          nextList != null) {
        continue;
      }
    }
    total++;
    if (list == 'checked') done++;
  }
  return [total, done];
}

List<Map>? _parseOps(String bodyDelta) {
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
