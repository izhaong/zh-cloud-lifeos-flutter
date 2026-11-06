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

/// #661 标签批量改写的**唯一事实源**（InMemory 与 Drift 两侧共用）。
///
/// Apple 备忘录没有独立的标签实体：标签在正文键入 `#` + 单词时创建，
/// 「将标签从所有使用它的备忘录移除，该标签也会从『标签』中移除」；
/// 「重新命名标签」后「使用了该标签的所有备忘录和智能文件夹都会更新」，
/// 「删除标签」后「标签会从使用了这些标签的所有备忘录和智能文件夹中删除」。
/// 因此管理动作等价于**批量改写引用**，不新增表、不改 schema。
///
/// [replacement] 为 null = 删除该标签；非 null = 重命名成它。
/// 返回保序的新列表；源里没有 [name]（或新名与原名相同）时返回 null，
/// 调用方据此跳过写库，避免给每条无关笔记都发一次变更通知。
List<String>? rewriteTagNames(
  List<String> source, {
  required String name,
  required String? replacement,
}) {
  if (name.isEmpty || replacement == name) return null;
  if (!source.contains(name)) return null;
  final mapped = <String>[];
  for (final tag in source) {
    if (tag == name) {
      if (replacement != null) mapped.add(replacement);
    } else {
      mapped.add(tag);
    }
  }
  final out = <String>[];
  for (final tag in mapped) {
    // 重命名撞到已存在的标签名时合并成一条（Apple：两个名字变成一个）。
    // 其余重复项按存储层 verbatim 口径原样保留，不趁机改写无关数据。
    if (tag == replacement && out.contains(tag)) continue;
    out.add(tag);
  }
  return List<String>.unmodifiable(out);
}

/// 智能文件夹 [filterJson] 的 `tagNames` 条件做同样改写；无变化返回 null。
///
/// 只动 `tagNames` 一个键，`folderId` / `pinned` / `updatedWithinDays`
/// 与其它自定义键原样带回。条件指向的标签被删后留下空数组——按
/// [applyNoteSmartFilter] 的口径该智能文件夹会显示为空，而不是偷偷
/// 放宽成「全部备忘录」。
String? rewriteTagFilter(
  String? filterJson, {
  required String name,
  required String? replacement,
}) {
  if (filterJson == null || filterJson.trim().isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(filterJson);
  } catch (_) {
    return null; // 脏条件不猜、不改，与 _parseFilter 同口径
  }
  if (decoded is! Map) return null;
  final raw = decoded['tagNames'];
  if (raw is! List) return null;
  final next = rewriteTagNames(
    raw.whereType<String>().toList(growable: false),
    name: name,
    replacement: replacement,
  );
  if (next == null) return null;
  final updated = Map<String, dynamic>.from(decoded)..['tagNames'] = next;
  return jsonEncode(updated);
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
