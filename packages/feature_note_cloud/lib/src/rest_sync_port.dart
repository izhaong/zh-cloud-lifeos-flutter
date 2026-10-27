import 'dart:convert';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

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
      final code = response['code'];
      if (code == 220 && attempts < maxAttempts) {
        conflicts++;
        final serverUpdatedAt = response['serverUpdatedAt'];
        final base = updatedAt ?? 0;
        updatedAt = serverUpdatedAt is num
            ? (serverUpdatedAt.toInt() > base ? serverUpdatedAt.toInt() : base + 1)
            : base + 1;
        continue;
      }
      return NotePushResult(attempts: attempts, conflicts: conflicts);
    }
  }

  /// 拉取服务端变更并解析为本地模型；未登录返回空（零请求）。
  Future<List<Note>> pull({String? cursor}) async {
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
    final notes = <Note>[];
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

  /// 笔记变更载荷：锁定笔记只上传密文（bodyText 强制空）。
  NoteSyncChange noteChange(Note note, {String? passphrase}) {
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
  String decryptLocked(Note note, String passphrase) =>
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

  Note _toNote(Map payload) {
    return Note(
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
