import 'dart:convert';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart'
    as kernel;

import 'note_cipher.dart';
import 'note_sync_models.dart';
import 'sync_http.dart';

/// 记录同步端口（契约 §6）：domain=note；未登录零请求；push 带 clientMutationId；
/// 冲突最多重试 3 次（同一 mutationId，clientUpdatedAt 取较大值）。
class RestSyncPort {
  RestSyncPort({
    required this.http,
    this.session,
    this.cipher = const NoteCipher(),
    this.maxAttempts = 3,
  });

  final NoteSyncHttp http;
  final NoteCipher cipher;
  final int maxAttempts;
  NoteSyncSession? session;

  static const String pushPath = '/app-api/lifeos/note/sync/push';
  static const String pullPath = '/app-api/lifeos/note/sync/pull';

  /// 推送变更；未登录直接返回（零请求）。
  Future<NotePushResult> push(
    List<NoteSyncChange> changes, {
    required String clientMutationId,
    int? clientUpdatedAt,
  }) async {
    if (session == null) {
      return const NotePushResult(attempts: 0, conflicts: 0);
    }
    var attempts = 0;
    var conflicts = 0;
    int? updatedAt = clientUpdatedAt;
    while (true) {
      attempts++;
      final response = await http.post(pushPath, {
        'domain': 'note',
        'clientMutationId': clientMutationId,
        'clientUpdatedAt': ?updatedAt,
        'changes': [
          for (final change in changes)
            {
              'entityType': change.entityType.name,
              'operation': change.operation,
              'data': change.payload,
            },
        ],
      });
      // #428：服务端把 `ok / accepted / conflicts / serverUpdatedAt` 放在 `data` 里；
      // 兼容老形态（直接平铺在顶层）——两处都读，避免因网关包装差异误判「全收」。
      final data = response['data'];
      final payload = data is Map ? Map<String, dynamic>.from(data) : response;
      final code = response['code'] ?? payload['code'];
      if (code == 220 && attempts < maxAttempts) {
        conflicts++;
        final serverUpdatedAt = payload['serverUpdatedAt'];
        final base = updatedAt ?? 0;
        updatedAt = serverUpdatedAt is num
            ? (serverUpdatedAt.toInt() > base ? serverUpdatedAt.toInt() : base + 1)
            : base + 1;
        continue;
      }
      final acceptedRaw = payload['accepted'];
      final acceptedIds = <String>{};
      if (acceptedRaw is List) {
        for (final item in acceptedRaw.whereType<Map>()) {
          final id = item['entityId']?.toString();
          if (id != null && id.isNotEmpty) acceptedIds.add(id);
        }
      }
      return NotePushResult(
        attempts: attempts,
        conflicts: conflicts,
        // `ok=true` = 整批受理；否则只认 accepted 里明确列出的 entityId
        allAccepted: payload['ok'] == true,
        acceptedEntityIds: acceptedIds,
      );
    }
  }

  /// 拉取服务端变更并解析为本地模型；未登录返回空（零请求）。
  Future<List<kernel.Note>> pull({String? cursor}) async {
    if (session == null) {
      return const [];
    }
    final response = await http.post(pullPath, {
      'domain': 'note',
      'cursor': ?cursor,
    });
    final data = response['data'];
    if (data is! Map) {
      return const [];
    }
    final changes = data['changes'];
    if (changes is! List) {
      return const [];
    }
    final notes = <kernel.Note>[];
    for (final change in changes.whereType<Map>()) {
      if (change['entityType'] != 'note') {
        continue;
      }
      final payload = change['data'];
      if (payload is! Map) {
        continue;
      }
      notes.add(_toNote(payload));
    }
    return notes;
  }

  /// 拉增量变更，返回**入站变更向量 + 下一页游标**（#415）。
  ///
  /// 与 [pull] 的区别：`pull` 只把 note 解析成模型（供旧调用方），
  /// 这里把原始 `SyncIncomingChange` 交出去，好让协调器统一走 applier——
  /// applier 才知道「delete 要进回收站」「folder 要落表」。
  Future<NotePullPage> pullChanges({String? cursor}) async {
    if (session == null) {
      return const NotePullPage(changes: [], nextCursor: null, hasMore: false);
    }
    final response = await http.post(pullPath, {
      'domain': 'note',
      'cursor': ?cursor,
    });
    final data = response['data'];
    if (data is! Map) {
      return const NotePullPage(changes: [], nextCursor: null, hasMore: false);
    }
    final raw = data['changes'];
    final changes = <kernel.SyncIncomingChange>[];
    if (raw is List) {
      for (final change in raw.whereType<Map>()) {
        final entityType = change['entityType']?.toString();
        final entityId = change['entityId']?.toString();
        if (entityType == null || entityId == null) continue;
        if (entityType != 'note' && entityType != 'folder') continue;
        final payload = change['data'];
        changes.add(kernel.SyncIncomingChange(
          entityType: entityType,
          entityId: entityId,
          operation: (change['operation']?.toString() ?? 'upsert').toLowerCase(),
          payload: payload is Map ? Map<String, dynamic>.from(payload) : const {},
        ));
      }
    }
    return NotePullPage(
      changes: changes,
      nextCursor: data['nextCursor']?.toString(),
      hasMore: data['hasMore'] == true,
    );
  }

  /// 笔记变更载荷：锁定笔记只上传密文（bodyText 强制空）。
  NoteSyncChange noteChange(kernel.Note note, {String? passphrase}) {
    final locked = note.locked;
    String bodyDelta = note.bodyDelta;
    if (locked) {
      if (passphrase == null || passphrase.isEmpty) {
        throw ArgumentError('锁定笔记推送需要加密口令');
      }
      // 开源包的假锁只存明文 Delta：上传前在 cloud 包做 AES-GCM
      if (_looksLikePlainDelta(bodyDelta)) {
        bodyDelta = cipher.encrypt(bodyDelta, passphrase);
      }
    }
    return NoteSyncChange(
      entityType: NoteSyncEntityType.note,
      payload: {
        'id': note.id,
        'folderId': note.folderId,
        'title': note.title,
        'bodyDelta': bodyDelta,
        'bodyText': locked ? '' : note.bodyText,
        'pinned': note.pinned,
        'locked': locked,
        'checklistTotal': locked ? 0 : note.checklistTotal,
        'checklistDone': locked ? 0 : note.checklistDone,
        'tagNames': locked ? const <String>[] : note.tagNames,
        'sortOrder': note.sortOrder,
        'revision': note.revision,
        'clientUpdatedAt': note.clientUpdatedAt,
        if (note.deletedAt != null)
          'deletedAt': note.deletedAt!.millisecondsSinceEpoch,
      },
    );
  }

  /// 用口令解开锁定笔记的密文（cloud 包内唯一解密入口）。
  String decryptLocked(kernel.Note note, String passphrase) =>
      cipher.decrypt(note.bodyDelta, passphrase);

  static bool _looksLikePlainDelta(String value) {
    final text = value.trim();
    if (!text.startsWith('{')) {
      return false;
    }
    try {
      return jsonDecode(text) is Map;
    } catch (_) {
      return false;
    }
  }

  kernel.Note _toNote(Map payload) {
    return kernel.Note(
      id: '${payload['id']}',
      folderId: '${payload['folderId']}',
      title: '${payload['title'] ?? ''}',
      bodyDelta: '${payload['bodyDelta'] ?? ''}',
      bodyText: '${payload['bodyText'] ?? ''}',
      pinned: payload['pinned'] == true,
      locked: payload['locked'] == true,
      checklistTotal: (payload['checklistTotal'] as num?)?.toInt() ?? 0,
      checklistDone: (payload['checklistDone'] as num?)?.toInt() ?? 0,
      tagNames: (payload['tagNames'] as List?)?.whereType<String>().toList() ??
          const [],
      sortOrder: (payload['sortOrder'] as num?)?.toInt() ?? 0,
      clientUpdatedAt: (payload['clientUpdatedAt'] as num?)?.toInt() ?? 0,
      revision: (payload['revision'] as num?)?.toInt() ?? 0,
    );
  }
}
