import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_core/app_core.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';

/// flutter#570：清单共享端口的契约测试（服务端见 zh-cloud-service #587 / #589）。
void main() {
  late _FakeStore store;
  late _RecAdapter adapter;
  late RestTaskCollabPort port;

  setUp(() {
    store = _FakeStore();
    adapter = _RecAdapter();
    port = RestTaskCollabPort(
      dio: Dio(BaseOptions(baseUrl: 'https://lifeos.test'))
        ..httpClientAdapter = adapter,
      store: store,
    );
  });

  Future<void> loggedIn() => store.write(
    const MemberSession(userId: '1', tenantId: '1', accessToken: 'tok'),
  );

  test('listMembers：走服务端编号路径、带 Bearer 与 tenant-id，并解析昵称', () async {
    await loggedIn();
    adapter.enqueue({
      'code': 0,
      'data': [
        {'memberUserId': 1, 'role': 'owner', 'status': 'active'},
        {
          'memberUserId': 2,
          'role': 'viewer',
          'status': 'active',
          'memberNickname': '李四',
        },
      ],
    });

    final members = await port.listMembers('100');

    expect(adapter.lastMethod, 'GET');
    expect(adapter.lastPath, '/app-api/lifeos/task/list/100/members');
    expect(adapter.lastHeaders['Authorization'], 'Bearer tok');
    expect(adapter.lastHeaders['tenant-id'], '1');
    expect(members.map((e) => e.role).toList(), ['owner', 'viewer']);
    expect(members.firstWhere((e) => e.memberUserId == '2').nickname, '李四');
    expect(members.first.canWrite, isTrue, reason: 'owner 可写');
    expect(members.lastWhere((e) => e.memberUserId == '2').isActive, isTrue);
  });

  test('业务信封 code!=0 要抛异常，不能折成空列表', () async {
    await loggedIn();
    adapter.enqueue({'code': 1070014, 'msg': '无权操作该清单（仅所有者可邀请/改角色/移除）'});

    await expectLater(
      port.listMembers('100'),
      throwsA(
        isA<TaskCollabException>().having(
          (e) => e.message,
          'message',
          contains('仅所有者'),
        ),
      ),
    );
  });

  test('未登录：直接抛「未登录」，不发请求', () async {
    await expectLater(
      port.listMembers('100'),
      throwsA(isA<TaskCollabException>()),
    );
    expect(adapter.requests, isEmpty, reason: '没会话就不该打网络');
  });

  test('本地清单没有 remoteId：给出人话错误，且不打网络', () async {
    await loggedIn();
    await expectLater(
      port.listMembers('local-uuid-abc'),
      throwsA(
        isA<TaskCollabException>().having(
          (e) => e.message,
          'message',
          contains('还没有服务端编号'),
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('inviteMembers：memberUserIds 发数字数组，role 原样带上', () async {
    await loggedIn();
    adapter.enqueue({'code': 0, 'data': true});

    await port.inviteMembers('100', userIds: ['2', '3'], role: 'editor');

    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/app-api/lifeos/task/list/100/members');
    final sent = jsonDecode(adapter.lastBody!) as Map<String, dynamic>;
    expect(sent['memberUserIds'], [2, 3], reason: '服务端是 bigint，不能发字符串');
    expect(sent['role'], 'editor');
  });

  test('resolveUserByMobile：mobile 去空格进 query，只取 userId', () async {
    await loggedIn();
    adapter.enqueue({
      'code': 0,
      'data': {'userId': 7, 'nickname': '王五'},
    });

    final id = await port.resolveUserByMobile(' 13800000007 ');

    expect(adapter.lastPath, '/app-api/lifeos/task/list-member/resolve');
    expect(adapter.lastQuery['mobile'], '13800000007');
    expect(id, '7');
  });

  test('resolveUserByMobile：服务端没数据时抛，不返回空串', () async {
    await loggedIn();
    adapter.enqueue({'code': 0, 'data': null});

    await expectLater(
      port.resolveUserByMobile('13900000000'),
      throwsA(isA<TaskCollabException>()),
    );
  });

  test('mySharedLists：解析 listId/name/role', () async {
    await loggedIn();
    adapter.enqueue({
      'code': 0,
      'data': [
        {
          'listId': 100,
          'name': '家庭',
          'ownerUserId': 1,
          'role': 'editor',
          'status': 'active',
        },
      ],
    });

    final lists = await port.mySharedLists();

    expect(adapter.lastPath, '/app-api/lifeos/task/list-member/my-lists');
    expect(lists.single.listId, '100');
    expect(lists.single.name, '家庭');
    expect(lists.single.role, 'editor');
  });

  test('sharedListTasks：走 task/page 读侧，解析条目与完成态（#600 路线 B）',
      () async {
    await loggedIn();
    adapter.enqueue({
      'code': 0,
      'data': {
        'list': [
          {
            'id': 5001,
            'listId': 100,
            'title': '买牛奶',
            'dueAt': 1762022400000,
            'allDay': true,
            'priority': 3,
            'isFlagged': true,
            'isCompleted': false,
            'tagNames': ['家'],
          },
          {'id': 5002, 'listId': 100, 'title': '已完成', 'isCompleted': true},
        ],
        'total': 2,
      },
    });

    final items = await port.sharedListTasks('100');

    expect(adapter.lastPath, '/app-api/lifeos/task/task/page');
    expect(adapter.lastQuery['listId'], '100', reason: 'bigint，按字符串发即可');
    expect(items.length, 2);
    expect(items.first.id, '5001');
    expect(items.first.title, '买牛奶');
    expect(items.first.flagged, isTrue);
    expect(items.first.completed, isFalse);
    expect(items.first.tagNames, ['家']);
    // epoch 毫秒与 ISO 字符串两种序列化都要能落
    expect(items.first.dueAt, isNotNull);
    expect(items.last.completed, isTrue);
    expect(items.last.dueAt, isNull);
  });

  test('sharedListTasks：非成员被服务端拒时抛错，不折成空表', () async {
    await loggedIn();
    adapter.enqueue({'code': 1_005_000_001, 'msg': '没有该清单的访问权限'});

    await expectLater(
      port.sharedListTasks('100'),
      throwsA(isA<TaskCollabException>()),
    );
  });

  test('join / exit / 改角色 / 移除：路径与方法各就各位', () async {
    await loggedIn();
    for (var i = 0; i < 4; i++) {
      adapter.enqueue({'code': 0, 'data': true});
    }

    await port.joinList('100');
    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/app-api/lifeos/task/list/100/member/join');

    await port.exitList('100');
    expect(adapter.lastPath, '/app-api/lifeos/task/list/100/member/exit');

    await port.updateMemberRole('100', '2', 'viewer');
    expect(adapter.lastMethod, 'PATCH');
    expect(adapter.lastPath, '/app-api/lifeos/task/list/100/members/2');
    expect(jsonDecode(adapter.lastBody!)['role'], 'viewer');

    await port.removeMember('100', '2');
    expect(adapter.lastMethod, 'DELETE');
    expect(adapter.lastPath, '/app-api/lifeos/task/list/100/members/2');
  });

  test('whoAmI：读会话不读网络；未登录返回 null', () async {
    expect(await port.whoAmI(), isNull);
    await loggedIn();
    expect(await port.whoAmI(), '1');
    expect(adapter.requests, isEmpty);
  });
}

class _FakeStore implements SessionStore {
  MemberSession? _session;

  @override
  Future<MemberSession?> read() async => _session;

  @override
  Future<void> write(MemberSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

class _Req {
  _Req(this.method, this.path, this.query, this.headers, this.body);

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic> headers;
  final String? body;
}

/// 记录请求的假 adapter：顺序出队响应。
class _RecAdapter implements HttpClientAdapter {
  final _queue = <dynamic>[];
  final requests = <_Req>[];

  void enqueue(dynamic response) => _queue.add(response);

  String get lastMethod => requests.last.method;
  String get lastPath => requests.last.path;
  Map<String, dynamic> get lastQuery => requests.last.query;
  Map<String, dynamic> get lastHeaders => requests.last.headers;
  String? get lastBody => requests.last.body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String? body;
    if (requestStream != null) {
      final bytes = await requestStream.fold(
        BytesBuilder(),
        (BytesBuilder b, List<int> d) => b..add(d),
      );
      body = utf8.decode(bytes.takeBytes());
    }
    requests.add(
      _Req(
        options.method,
        options.uri.path,
        Map<String, dynamic>.from(options.queryParameters),
        Map<String, dynamic>.from(options.headers),
        body,
      ),
    );
    final resp = _queue.isEmpty
        ? {'code': 0, 'data': true}
        : _queue.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(resp),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}
