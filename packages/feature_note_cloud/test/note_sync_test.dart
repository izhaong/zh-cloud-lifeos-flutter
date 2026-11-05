import 'package:feature_note_cloud/feature_note_cloud.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-SYNC：假 HTTP 同步（F-16；契约 §6）。不打真实网络。
void main() {
  const session = NoteSyncSession(token: 'token', userId: '1');

  Note note({String id = 'n1', bool locked = false}) => Note(
        id: id,
        folderId: 'f1',
        title: '标题',
        bodyDelta: '{"ops":[{"insert":"秘密正文\\n"}]}',
        bodyText: '秘密正文',
        locked: locked,
        revision: 1,
        clientUpdatedAt: 1000,
      );

  // TC-NOTE-SYNC-101：push 请求体含 clientMutationId 与 clientUpdatedAt
  test('TC-NOTE-SYNC-101 离线新建再推：请求体含 mutationId 与 clientUpdatedAt',
      () async {
    final http = _FakeHttp([{'code': 0}]);
    final port = RestSyncPort(http: http, session: session);

    final result = await port.push(
      [port.noteChange(note())],
      clientMutationId: 'm-101',
      clientUpdatedAt: 123456,
    );

    expect(result.attempts, 1);
    final body = http.calls.single.body;
    expect(body['domain'], 'note');
    expect(body['clientMutationId'], 'm-101');
    expect(body['clientUpdatedAt'], 123456);
    final changes = body['changes'] as List;
    expect(changes.single['entityType'], 'note');
  });

  // TC-NOTE-SYNC-102：pull 解析进本地模型
  test('TC-NOTE-SYNC-102 拉取一条 note 并解析', () async {
    final http = _FakeHttp([
      {
        'code': 0,
        'data': {
          'changes': [
            {
              'entityType': 'note',
              'data': {
                'id': 'n9',
                'folderId': 'f1',
                'title': '远端',
                'bodyDelta': '{"ops":[{"insert":"远端正文\\n"}]}',
                'bodyText': '远端正文',
                'pinned': true,
                'locked': false,
                'checklistTotal': 0,
                'checklistDone': 0,
                'tagNames': ['工作'],
                'sortOrder': 2,
                'revision': 3,
                'clientUpdatedAt': 2000,
              },
            },
          ],
        },
      }
    ]);
    final port = RestSyncPort(http: http, session: session);

    final notes = await port.pull();

    expect(notes, hasLength(1));
    expect(notes.single.id, 'n9');
    expect(notes.single.title, '远端');
    expect(notes.single.bodyText, '远端正文');
    expect(notes.single.pinned, isTrue);
    expect(notes.single.tagNames, ['工作']);
    expect(notes.single.revision, 3);
  });

  // TC-NOTE-SYNC-103：冲突后整条重推，最多 3 次，clientUpdatedAt 递增
  test('TC-NOTE-SYNC-103 冲突重推最多 3 次', () async {
    final http = _FakeHttp([
      {'code': 220, 'serverUpdatedAt': 5000},
      {'code': 220, 'serverUpdatedAt': 8000},
      {'code': 0},
    ]);
    final port = RestSyncPort(http: http, session: session);

    final result = await port.push(
      [port.noteChange(note())],
      clientMutationId: 'm-103',
      clientUpdatedAt: 1000,
    );

    expect(result.attempts, 3);
    expect(result.conflicts, 2);
    final updatedAts = http.calls
        .map((c) => (c.body['clientUpdatedAt'] as num).toInt())
        .toList();
    expect(updatedAts.first, 1000);
    expect(updatedAts.last, greaterThan(updatedAts.first));
  });

  // TC-NOTE-SYNC-103（上限）：连续冲突到第 3 次仍失败则停手
  test('TC-NOTE-SYNC-103 第 3 次仍冲突则不再重试', () async {
    final http = _FakeHttp([
      {'code': 220},
      {'code': 220},
      {'code': 220},
    ]);
    final port = RestSyncPort(http: http, session: session);

    final result = await port.push(
      [port.noteChange(note())],
      clientMutationId: 'm-103b',
      clientUpdatedAt: 1000,
    );

    expect(result.attempts, 3);
    expect(http.calls, hasLength(3));
  });

  // TC-NOTE-SYNC-104：重试复用同一 clientMutationId
  test('TC-NOTE-SYNC-104 同一 mutationId 重试不换键', () async {
    final http = _FakeHttp([
      {'code': 220},
      {'code': 0},
    ]);
    final port = RestSyncPort(http: http, session: session);

    await port.push([port.noteChange(note())],
        clientMutationId: 'm-104', clientUpdatedAt: 1000);

    expect(http.calls, hasLength(2));
    expect(
      http.calls.map((c) => c.body['clientMutationId']).toSet(),
      {'m-104'},
    );
  });

  // TC-NOTE-SYNC-105：未登录零请求
  test('TC-NOTE-SYNC-105 无会话 push/pull 零请求', () async {
    final http = _FakeHttp(const []);
    final port = RestSyncPort(http: http);

    final result = await port.push([port.noteChange(note())],
        clientMutationId: 'm-105');
    final pulled = await port.pull();

    expect(result.attempts, 0);
    expect(pulled, isEmpty);
    expect(http.calls, isEmpty);
  });

  // TC-NOTE-SYNC-106：锁定笔记 payload 只含密文
  test('TC-NOTE-SYNC-106 锁定只传密文，可解密还原', () async {
    final http = _FakeHttp([{'code': 0}]);
    final port = RestSyncPort(http: http, session: session);
    final locked = note(locked: true);

    final change = port.noteChange(locked, passphrase: 'pw-106');
    final payload = change.payload;
    expect('${payload['bodyText']}', isEmpty);
    expect('${payload['bodyDelta']}', isNot(contains('秘密正文')));
    expect('${payload['bodyDelta']}', isNot(contains('ops')));

    final restored = port.decryptLocked(
      Note(
        id: locked.id,
        folderId: locked.folderId,
        title: locked.title,
        bodyDelta: '${payload['bodyDelta']}',
        bodyText: '',
        locked: true,
      ),
      'pw-106',
    );
    expect(restored, locked.bodyDelta);
  });
}

class _FakeHttp implements NoteSyncHttp {
  _FakeHttp(this.responses);

  final List<Map<String, dynamic>> responses;
  final List<({String path, Map<String, dynamic> body})> calls = [];

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    calls.add((path: path, body: body));
    if (responses.isEmpty) {
      return {'code': 0};
    }
    final index = calls.length - 1;
    return responses[index < responses.length ? index : responses.length - 1];
  }
}
