import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, OrderingTerm, StringExpressionOperators, Value;

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'db.dart' as db;
import 'drift_sync_outbox.dart';

/// [kernel.NoteRepository] 的 Drift 实现（#280：记录本机持久化）。
///
/// 保存归一 / 列表排序 / 智能文件夹过滤三条规则走 kernel 的
/// `normalizeNoteForSave` / `sortNotesForList` / `applyNoteSmartFilter`，
/// 与内存实现同口径——避免「内存版绿、落盘版另一套行为」。
class DriftNoteRepository implements kernel.NoteRepository, kernel.SyncApplier {
  DriftNoteRepository(this._db);

  final db.LifeProductivityDb _db;

  /// 测试注入「当前时间」（回收窗判定用）。
  DateTime? nowForTest;

  DateTime get _now => nowForTest ?? DateTime.now();

  @override
  Stream<List<kernel.NoteFolder>> watchFolders() {
    return (_db.select(_db.noteFolders)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch()
        .map((rows) => List<kernel.NoteFolder>.unmodifiable(
              rows.map(_folderModel),
            ));
  }

  @override
  Stream<List<kernel.Note>> watchNotes({String? folderId}) {
    // 智能文件夹的过滤条件在文件夹行上，需要同时 watch 两侧。
    final folders$ = (_db.select(_db.noteFolders)
          ..where((t) => t.deletedAt.isNull()))
        .watch();
    final notes$ = (_db.select(_db.notes)
          ..where((t) => t.deletedAt.isNull()))
        .watch();
    return _combineLatest2<List<db.NoteFolder>, List<db.Note>, List<kernel.Note>>(
      folders$,
      notes$,
      (folderRows, noteRows) {
        final folders = folderRows.map(_folderModel).toList(growable: false);
        Iterable<kernel.Note> scoped =
            noteRows.map(_noteModel).toList(growable: false);
        kernel.NoteFolder? folder;
        for (final f in folders) {
          if (f.id == folderId) {
            folder = f;
            break;
          }
        }
        if (folder != null && folder.smart) {
          scoped = kernel.applyNoteSmartFilter(scoped, folder, now: _now);
        } else if (folderId != null) {
          scoped = scoped.where((n) => n.folderId == folderId);
        }
        return kernel.sortNotesForList(scoped);
      },
    );
  }

  @override
  Stream<List<kernel.Note>> watchDeleted() {
    return (_db.select(_db.notes)
          ..where((t) => t.deletedAt.isNotNull()))
        .watch()
        .map((rows) {
      final list = rows.map(_noteModel).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      return List<kernel.Note>.unmodifiable(list);
    });
  }

  @override
  Stream<List<kernel.NoteTag>> watchTags() {
    // 标签从存活笔记的 tagNames 派生（内存实现的 _tags 一直是空列表，
    // 那是它自己的缺口；落盘版按 UI 语义给出真实结果）。
    return (_db.select(_db.notes)..where((t) => t.deletedAt.isNull()))
        .watch()
        .map((rows) {
      final names = <String>{};
      for (final row in rows) {
        for (final name in _decodeTags(row.tagNames)) {
          if (name.isNotEmpty) names.add(name);
        }
      }
      final sorted = names.toList()..sort();
      return List<kernel.NoteTag>.unmodifiable(
        sorted.map((n) => kernel.NoteTag(id: n, name: n)),
      );
    });
  }

  @override
  Future<String> upsertFolder(kernel.NoteFolder folder) async {
    // kernel 模型不含 remoteId / deletedAt（存储层字段），全量回写时保留既有
    // remoteId、并显式把 deletedAt 置空（文件夹删除走各自业务，不由此端口）。
    final existing = await (_db.select(_db.noteFolders)
          ..where((t) => t.id.equals(folder.id)))
        .getSingleOrNull();
    await _db.into(_db.noteFolders).insertOnConflictUpdate(
          db.NoteFoldersCompanion.insert(
            id: folder.id,
            remoteId: Value(existing?.remoteId),
            parentId: Value(folder.parentId),
            name: folder.name,
            smart: Value(folder.smart),
            filterJson: Value(folder.filterJson),
            sortOrder: Value(folder.sortOrder),
            deletedAt: const Value(null),
          ),
        );
    await _enqueueFolderOutbox([folder.id]);
    return folder.id;
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    // #373：文件夹本身不做软删（Notes 的 deletedAt 只服务「最近删除」里的笔记），
    // 调用方要先把文件夹内的笔记 softDelete 再调这里。
    await (_db.delete(_db.noteFolders)..where((t) => t.id.equals(folderId))).go();
    // 删除后行已不在，用最小载荷记一条 delete（服务端只需 id）。
    await _enqueueFolderOutbox([folderId], forceDeleted: true);
  }

  @override
  Future<String> upsertNote(kernel.Note note) async {
    final normalized = kernel.normalizeNoteForSave(note);
    final existing = await (_db.select(_db.notes)
          ..where((t) => t.id.equals(normalized.id)))
        .getSingleOrNull();
    // 防复活：软删行只经 restore 恢复；全量回写丢掉 deletedAt 时保留原标记
    final deletedAt = existing != null &&
            existing.deletedAt != null &&
            normalized.deletedAt == null
        ? existing.deletedAt
        : normalized.deletedAt;
    await _db.into(_db.notes).insertOnConflictUpdate(
          _noteCompanion(normalized, deletedAt: deletedAt),
        );
    // #413：本地变更进发件箱（push 半边的前置）。此前 note 侧 0 处写 outbox，
    // 于是 RestSyncPort 没有数据源、登录后备忘录根本不上传。
    await _enqueueNoteOutbox([normalized.id]);
    return normalized.id;
  }

  @override
  Future<void> softDelete(String noteId) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId)))
        .write(db.NotesCompanion(deletedAt: Value(_now)));
    await _enqueueNoteOutbox([noteId]);
  }

  @override
  Future<void> restore(String noteId) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId)))
        .write(const db.NotesCompanion(deletedAt: Value(null)));
    await _enqueueNoteOutbox([noteId]);
  }

  @override
  Future<int> purgeExpired() async {
    final cutoff = _now.subtract(kernel.InMemoryNoteRepository.recycleWindow);
    final doomed = await (_db.select(_db.notes)
          ..where((t) => t.deletedAt.isNotNull()))
        .get();
    var removed = 0;
    for (final row in doomed) {
      if (!row.deletedAt!.isAfter(cutoff)) {
        await (_db.delete(_db.notes)..where((t) => t.id.equals(row.id))).go();
        removed++;
      }
    }
    return removed;
  }

  // ---- 入站落库（#414 / 契约 §6）----

  /// 落一批服务端下推的变更。
  ///
  /// **必须绕开 [upsertNote] / [softDelete] 等写方法**：它们会顺手 `enqueue`
  /// 一条出站变更（#413），而 pull 落库再 enqueue → push 推回服务端 →
  /// 两端自己造出无限往返。所以这里直接写行。
  ///
  /// 同事务：一条落不完就整体回滚，调用方（协调器 #415）据此决定游标是否前进。
  @override
  Future<void> applyAll(Iterable<kernel.SyncIncomingChange> changes) async {
    final batch = changes.toList(growable: false);
    if (batch.isEmpty) return;
    await _db.transaction(() async {
      for (final change in batch) {
        switch (change.entityType) {
          case 'note':
            if (change.operation == 'delete') {
              await _applyInboundNoteDelete(change);
            } else {
              await _applyInboundNoteUpsert(change);
            }
          case 'folder':
            if (change.operation == 'delete') {
              await _applyInboundFolderDelete(change);
            } else {
              await _applyInboundFolderUpsert(change);
            }
          default:
            // 未知实体：忽略而不抛——一条新实体类型的脏数据不该卡死整轮同步。
            break;
        }
      }
    });
  }

  Future<void> _applyInboundNoteUpsert(kernel.SyncIncomingChange c) async {
    final payload = c.payload;
    final existing = await (_db.select(_db.notes)
          ..where((t) => t.id.equals(c.entityId)))
        .getSingleOrNull();
    final note = kernel.Note(
      id: c.entityId,
      folderId: payload['folderId']?.toString() ?? existing?.folderId ?? '',
      title: payload['title']?.toString() ?? existing?.title ?? '',
      bodyDelta: payload['bodyDelta']?.toString() ?? existing?.bodyDelta ?? '',
      bodyText: payload['bodyText']?.toString() ?? existing?.bodyText ?? '',
      pinned: payload['pinned'] is bool
          ? payload['pinned'] as bool
          : (existing?.pinned ?? false),
      locked: payload['locked'] is bool
          ? payload['locked'] as bool
          : (existing?.locked ?? false),
      checklistTotal: (payload['checklistTotal'] as num?)?.toInt() ??
          existing?.checklistTotal ??
          0,
      checklistDone: (payload['checklistDone'] as num?)?.toInt() ??
          existing?.checklistDone ??
          0,
      tagNames: payload['tagNames'] is List
          ? (payload['tagNames'] as List).whereType<String>().toList()
          : _decodeTags(existing?.tagNames),
      sortOrder: (payload['sortOrder'] as num?)?.toInt() ??
          existing?.sortOrder ??
          0,
      deletedAt: _epochMilli(payload['deletedAt']) ?? existing?.deletedAt,
      revision: (payload['revision'] as num?)?.toInt() ?? existing?.revision ?? 0,
      clientUpdatedAt: (payload['clientUpdatedAt'] as num?)?.toInt() ??
          existing?.clientUpdatedAt ??
          _now.millisecondsSinceEpoch,
    );
    await _db.into(_db.notes).insertOnConflictUpdate(
          _noteCompanion(note, deletedAt: note.deletedAt),
        );
  }

  Future<void> _applyInboundNoteDelete(kernel.SyncIncomingChange c) async {
    // 服务端删除 → 本地进「最近删除」（不是硬删），与 Apple/仓库语义一致。
    await (_db.update(_db.notes)..where((t) => t.id.equals(c.entityId))).write(
      db.NotesCompanion(
        deletedAt: Value(_epochMilli(c.payload['deletedAt']) ?? _now),
      ),
    );
  }

  Future<void> _applyInboundFolderUpsert(kernel.SyncIncomingChange c) async {
    final payload = c.payload;
    final existing = await (_db.select(_db.noteFolders)
          ..where((t) => t.id.equals(c.entityId)))
        .getSingleOrNull();
    await _db.into(_db.noteFolders).insertOnConflictUpdate(
          db.NoteFoldersCompanion.insert(
            id: c.entityId,
            remoteId: Value(existing?.remoteId),
            parentId: Value(payload['parentId']?.toString()),
            name: payload['name']?.toString() ?? existing?.name ?? '文件夹',
            smart: Value(payload['smart'] is bool
                ? payload['smart'] as bool
                : (existing?.smart ?? false)),
            filterJson:
                Value(payload['filterJson']?.toString() ?? existing?.filterJson),
            sortOrder: Value((payload['sortOrder'] as num?)?.toInt() ??
                existing?.sortOrder ??
                0),
            deletedAt: const Value(null),
          ),
        );
  }

  Future<void> _applyInboundFolderDelete(kernel.SyncIncomingChange c) async {
    await (_db.delete(_db.noteFolders)..where((t) => t.id.equals(c.entityId)))
        .go();
  }

  /// 入队一批备忘录变更（#413）。
  ///
  /// 与任务侧同口径：同实体未推条目由 `DriftSyncOutbox.enqueue` 合并；
  /// 幂等键首次生成后沿用。入站落库（子卡 #414）必须**绕开**这里，
  /// 否则 pull 写一次就顺手 enqueue，push 再推回服务端，造成无限往返。
  Future<void> _enqueueNoteOutbox(Iterable<String> noteIds) async {
    final outbox = DriftSyncOutbox(_db);
    for (final id in noteIds) {
      final row = await (_db.select(_db.notes)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) continue;
      final at = _now;
      final note = _noteModel(row);
      await outbox.enqueue(
        kernel.SyncOutboxEntry(
          entityType: 'note',
          entityId: id,
          operation: row.deletedAt != null ? 'delete' : 'upsert',
          payload: kernel.noteSyncPayload(note),
          clientMutationId: 'note-$id-${at.microsecondsSinceEpoch}',
          clientUpdatedAt: at.millisecondsSinceEpoch,
        ),
      );
    }
  }

  /// 入队一批文件夹变更（#413）。
  Future<void> _enqueueFolderOutbox(Iterable<String> folderIds,
      {bool forceDeleted = false}) async {
    final outbox = DriftSyncOutbox(_db);
    for (final id in folderIds) {
      final at = _now;
      final row = forceDeleted
          ? null
          : await (_db.select(_db.noteFolders)..where((t) => t.id.equals(id)))
              .getSingleOrNull();
      if (row == null && !forceDeleted) continue;
      await outbox.enqueue(
        kernel.SyncOutboxEntry(
          entityType: 'folder',
          entityId: id,
          operation: forceDeleted ? 'delete' : 'upsert',
          payload: row == null
              ? {'id': id}
              : kernel.noteFolderSyncPayload(_folderModel(row)),
          clientMutationId: 'folder-$id-${at.microsecondsSinceEpoch}',
          clientUpdatedAt: at.millisecondsSinceEpoch,
        ),
      );
    }
  }

  @override
  Future<List<kernel.Note>> search(String keyword, {int limit = 50}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return const [];
    final rows = await (_db.select(_db.notes)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.locked.equals(false) &
              (t.title.contains(kw) | t.bodyText.contains(kw)))
          ..limit(limit))
        .get();
    return rows.map(_noteModel).toList(growable: false);
  }

  // ---- 内部 ----

  kernel.NoteFolder _folderModel(db.NoteFolder row) => kernel.NoteFolder(
        id: row.id,
        parentId: row.parentId,
        name: row.name,
        smart: row.smart,
        filterJson: row.filterJson,
        sortOrder: row.sortOrder,
      );

  kernel.Note _noteModel(db.Note row) => kernel.Note(
        id: row.id,
        folderId: row.folderId,
        title: row.title,
        bodyDelta: row.bodyDelta,
        bodyText: row.bodyText,
        pinned: row.pinned,
        locked: row.locked,
        checklistTotal: row.checklistTotal,
        checklistDone: row.checklistDone,
        tagNames: _decodeTags(row.tagNames),
        sortOrder: row.sortOrder,
        deletedAt: row.deletedAt,
        revision: row.revision,
        clientUpdatedAt: row.clientUpdatedAt,
      );

  db.NotesCompanion _noteCompanion(
    kernel.Note n, {
    DateTime? deletedAt,
  }) =>
      db.NotesCompanion.insert(
        id: n.id,
        folderId: n.folderId,
        title: n.title,
        bodyDelta: Value(n.bodyDelta),
        bodyText: Value(n.bodyText),
        pinned: Value(n.pinned),
        locked: Value(n.locked),
        checklistTotal: Value(n.checklistTotal),
        checklistDone: Value(n.checklistDone),
        tagNames: Value(jsonEncode(n.tagNames)),
        sortOrder: Value(n.sortOrder),
        deletedAt: Value(deletedAt),
        clientUpdatedAt: Value(n.clientUpdatedAt),
        revision: Value(n.revision),
      );

  /// 载荷里的 epoch 毫秒 → 本地时间（`noteSyncPayload` 的正向编码见 kernel）。
  DateTime? _epochMilli(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  List<String> _decodeTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList(growable: false);
    } catch (_) {}
    return const [];
  }

  static Stream<R> _combineLatest2<A, B, R>(
    Stream<A> a,
    Stream<B> b,
    R Function(A, B) combine,
  ) {
    late StreamController<R> controller;
    A? latestA;
    B? latestB;
    var hasA = false, hasB = false;
    final subs = <StreamSubscription<dynamic>>[];

    void emit() {
      if (hasA && hasB) controller.add(combine(latestA as A, latestB as B));
    }

    void listen() {
      subs.add(a.listen((v) {
        latestA = v;
        hasA = true;
        emit();
      }));
      subs.add(b.listen((v) {
        latestB = v;
        hasB = true;
        emit();
      }));
    }

    controller = StreamController<R>.broadcast(
      onListen: listen,
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
        subs.clear();
        hasA = hasB = false;
      },
    );
    return controller.stream;
  }
}
