import 'dart:convert';
import 'dart:typed_data';

import 'package:app_core/app_core.dart';
import 'package:dio/dio.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_task_cloud/feature_task_cloud.dart';

/// TC-SYNC-102/103/104（T-05）：登录页——跳过/成功/失败不落半态。
void main() {
  late _FakeStore store;
  late _SeqAdapter adapter;
  late Dio dio;

  setUp(() {
    store = _FakeStore();
    adapter = _SeqAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://lifeos.test'))
      ..httpClientAdapter = adapter;
  });

  Widget host() => ProviderScope(
        overrides: [authPortProvider.overrideWithValue(
          RestAuthPort(dio: dio, store: store),
        )],
        child: const CupertinoApp(home: CloudLoginPage()),
      );

  testWidgets('TC-SYNC-102 跳过：直接返回 false，无会话写入', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('login_skip')));
    await tester.pumpAndSettle();

    expect(store.session, isNull, reason: '跳过不产生会话');
  });

  testWidgets('TC-SYNC-103 登录成功：会话入 store', (tester) async {
    adapter.enqueue({
      'code': 0,
      'data': {'userId': 248, 'accessToken': 'tok', 'nickname': '仲'},
    });
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('login_mobile')), '15601691399');
    await tester.enterText(find.byKey(const ValueKey('login_password')), 'pw');
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();

    expect(store.session?.accessToken, 'tok');
  });

  testWidgets('TC-SYNC-104 登录失败：错误提示 + 不落半登录态', (tester) async {
    adapter.enqueue({'code': 1004003000, 'msg': '账号密码不正确'});
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('login_mobile')), '15601691399');
    await tester.enterText(find.byKey(const ValueKey('login_password')), 'bad');
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login_error')), findsOneWidget);
    expect(find.text('账号密码不正确'), findsOneWidget);
    expect(store.session, isNull, reason: '失败不得留半登录态');
  });
}

class _FakeStore implements SessionStore {
  MemberSession? session;

  @override
  Future<MemberSession?> read() async => session;

  @override
  Future<void> write(MemberSession s) async => session = s;

  @override
  Future<void> clear() async => session = null;
}

class _SeqAdapter implements HttpClientAdapter {
  final _queue = <dynamic>[];

  void enqueue(dynamic r) => _queue.add(r);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = _queue.isEmpty ? {'code': 0, 'data': null} : _queue.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}
