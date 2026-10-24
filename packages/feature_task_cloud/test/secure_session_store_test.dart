import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_core/app_core.dart';
import 'package:feature_task_cloud/feature_task_cloud.dart';

/// cursor PR#17 阻断1 测试缺口：SecureSessionStore 编解码契约
/// （JSON 编码；token/displayName 含 `|` 不截断；损坏数据按未登录）。
void main() {
  late _MemSecureStorage storage;
  late SecureSessionStore store;

  setUp(() {
    storage = _MemSecureStorage();
    store = SecureSessionStore(storage: storage);
  });

  test('会话写入后读回一致', () async {
    const session = MemberSession(
      userId: '248',
      tenantId: '1',
      accessToken: 'tok_abc',
      displayName: '仲灏',
    );
    await store.write(session);
    expect(await store.read(), session);
  });

  test('token 含管道符不截断（cursor PR#17 阻断1）', () async {
    const session = MemberSession(
      userId: '248',
      tenantId: '1',
      accessToken: 'tok|with|pipes',
      displayName: null,
    );
    await store.write(session);
    final read = await store.read();
    expect(read?.accessToken, 'tok|with|pipes');
  });

  test('displayName 含管道符与特殊字符不丢', () async {
    const session = MemberSession(
      userId: '1',
      tenantId: '1',
      accessToken: 't',
      displayName: '名字|带竖线|"引号"',
    );
    await store.write(session);
    expect((await store.read())?.displayName, '名字|带竖线|"引号"');
  });

  test('clear 后 read 为 null', () async {
    await store.write(const MemberSession(
      userId: '1', tenantId: '1', accessToken: 't',
    ));
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('损坏数据按未登录处理（不炸，离线优先）', () async {
    storage.map['lifeos.member.session.v1'] = 'not-json{{{';
    expect(await store.read(), isNull);
  });

  test('空存储 read 为 null', () async {
    expect(await store.read(), isNull);
  });
}

/// 内存假 secure storage（不触平台通道；编解码契约与平台无关）。
class _MemSecureStorage implements FlutterSecureStorage {
  final map = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async =>
      map[key];

  @override
  Future<void> write({
    required String key,
    String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
  }) async {
    map.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
