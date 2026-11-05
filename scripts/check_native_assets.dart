// 出包前的原生资产预检（#389）。
//
// 背景：`sqlite3` 包的 build hook 会在构建期从 GitHub Releases 下载预编译二进制
// （`https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<ver>/...`）。
// 该直链不可达时（网络受限/地区/临时故障），`flutter build` 会**跑到一半才红**：
//
//   Target build_hooks failed: Error: Building native assets failed
//   Execution failed for task ':app:compileFlutterBuildDebug'
//
// 一张 12 分钟的构建换来一句「Building native assets failed」——本脚本的作用是
// **在构建前**把话说清楚：要么通过（缓存/网络都就绪），要么红并给出可执行提示。
//
// 用法：
//   dart run scripts/check_native_assets.dart              # 预检（会联网探测）
//   dart run scripts/check_native_assets.dart --selftest   # 不联网，验证判据本身
//
// 注意：**不进 `melos run verify`**——verify 必须离线可跑（AGENTS.md 铁律 6：
// 测试禁止打真实网络）。这是出包前手动/CI 前置步骤。
import 'dart:io';

/// 出包目标平台 → 需要的资产文件名后缀。
///
/// **不硬编码文件名**：`sqlite3` 包的资产名在 `lib/src/hook/asset_hashes.dart` 里，
/// 版本一升就可能变（本脚本第一版把 `libsqlite3.arm64.android.so` 猜成
/// `libsqlite3.android.arm64.so`，导致 Android 被误判为不可达）。所以运行时去读那份清单。
const _platformSuffixes = <String, String>{
  'android-arm64': 'arm64.android.so',
  'android-arm': 'arm.android.so',
  'ios-arm64': 'arm64.ios.dylib',
  'ios-sim-arm64': 'arm64.ios_sim.dylib',
  'macos-arm64': 'arm64.macos.dylib',
  'linux-x64': 'x64.linux.so',
};

Future<void> main(List<String> args) async {
  if (args.contains('--selftest')) {
    exitCode = await _selftest();
    return;
  }

  final tag = _releaseTag();
  final assets = _assetNames();
  if (tag == null || assets.isEmpty) {
    stderr.writeln('FAIL  读不到 sqlite3 包的资产清单（lib/src/hook/asset_hashes.dart）');
    stderr.writeln('      包没装好？先跑 `dart pub get`。');
    exitCode = 1;
    return;
  }
  // 只探测「普通 sqlite3」资产（不含 sqlcipher/sqlite3mc 变体）
  final wanted = <String, String>{};
  for (final entry in _platformSuffixes.entries) {
    final name = assets.firstWhere(
      (a) => a.startsWith('libsqlite3.') && a.endsWith(entry.value),
      orElse: () => '',
    );
    if (name.isEmpty) {
      stderr.writeln('WARN  资产清单里找不到 ${entry.key} 对应的文件（后缀 '
          '${entry.value}），跳过');
      continue;
    }
    wanted[entry.key] = name;
  }
  final baseUrl = _argValue(args, '--base-url') ??
      'https://github.com/simolus3/sqlite3.dart/releases/download/$tag';
  final timeout = int.tryParse(_argValue(args, '--timeout') ?? '') ?? 20;

  stdout.writeln('sqlite3 $tag · 探测 $baseUrl');
  final unreachable = <String>[];
  for (final entry in wanted.entries) {
    final url = '$baseUrl/${entry.value}';
    final ok = await _probe(url, timeout);
    stdout.writeln('  ${ok ? 'OK  ' : 'FAIL'} ${entry.key.padRight(14)} ${entry.value}');
    if (!ok) unreachable.add(entry.key);
  }
  if (unreachable.isEmpty) {
    stdout.writeln('OK  原生资产直链可达，可以出包');
    exitCode = 0;
    return;
  }
  stderr
    ..writeln('')
    ..writeln('FAIL  以下平台的原生资产直链不可达：${unreachable.join(', ')}')
    ..writeln('      继续跑 `flutter build` 会在 build_hooks 阶段半途失败，')
    ..writeln('      报错只有一句 “Building native assets failed”，很难定位。')
    ..writeln('')
    ..writeln('  可选处理：')
    ..writeln('    1. 换网络（VPN/代理）后重跑本预检；')
    ..writeln('    2. 手动把对应文件下载到 sqlite3 的缓存目录，再重试：')
    ..writeln('       <仓库>/.dart_tool/hooks_runner/shared/sqlite3/build/download-*/')
    ..writeln('       （本仓已有先例：新建 worktree 后从主仓拷 libsqlite3.dylib 过来）')
    ..writeln('    3. 若长期不可达，考虑镜像/内网源（见 Issue #389 方案 1）。');
  exitCode = 1;
}

/// sqlite3 包在 pub cache 里的根目录（经 `.dart_tool/package_config.json` 解析）。
String? _sqlite3PackageRoot() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final text = config.readAsStringSync();
  // 轻量解析：找 `"name": "sqlite3"` 附近那段里的 rootUri
  final m = RegExp(
    r'"name"\s*:\s*"sqlite3"[^}]*?"rootUri"\s*:\s*"([^"]+)"',
    dotAll: true,
  ).firstMatch(text);
  final raw = m?.group(1);
  if (raw == null) return null;
  final uri = Uri.parse(raw);
  if (uri.isScheme('file')) return uri.toFilePath();
  // 相对路径：相对于 .dart_tool/
  final resolved = File('.dart_tool/package_config.json').absolute.parent.uri
      .resolve(raw);
  return resolved.isScheme('file') ? resolved.toFilePath() : null;
}

/// 从包的 `asset_hashes.dart` 读 `releaseTag`。
String? _releaseTag() {
  final root = _sqlite3PackageRoot();
  if (root == null) return null;
  final file = File('$root/lib/src/hook/asset_hashes.dart');
  if (!file.existsSync()) return null;
  final m = RegExp(r"releaseTag\s*=\s*'([^']+)'")
      .firstMatch(file.readAsStringSync());
  return m?.group(1);
}

/// 从包的 `asset_hashes.dart` 读全部资产文件名。
List<String> _assetNames() {
  final root = _sqlite3PackageRoot();
  if (root == null) return const [];
  final file = File('$root/lib/src/hook/asset_hashes.dart');
  if (!file.existsSync()) return const [];
  return RegExp(r"'([^']+)'\s*:\s*'[0-9a-f]{64}'")
      .allMatches(file.readAsStringSync())
      .map((m) => m.group(1)!)
      .toList();
}

/// HEAD 请求探测（跟随重定向）。**不下载正文**：只关心可达性。
Future<bool> _probe(String url, int timeoutSeconds) async {
  final client = HttpClient()
    ..connectionTimeout = Duration(seconds: timeoutSeconds);
  try {
    final request = await client.headUrl(Uri.parse(url));
    request.followRedirects = true;
    final response = await request.close().timeout(
          Duration(seconds: timeoutSeconds),
        );
    // 丢弃正文（HEAD 通常没有正文，保险起见）
    await response.drain<void>();
    return response.statusCode >= 200 && response.statusCode < 400;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

String? _argValue(List<String> args, String name) {
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == name) return args[i + 1];
  }
  return null;
}

/// 自检：**不联网**，用「必unreachable 的地址」与「本机临时 HTTP 服务」验证判据。
Future<int> _selftest() async {
  // 1) 不可达地址必须判红
  const deadUrl = 'http://127.0.0.1:1/never.ics';
  final dead = await _probe(deadUrl, 2);
  if (dead) {
    stderr.writeln('SELFTEST FAIL：不可达地址被判成可达');
    return 1;
  }
  // 2) 可达地址必须判绿（本机起一个只回 200 的 server）
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final sub = server.listen((request) {
    request.response.statusCode = 200;
    request.response.close();
  });
  final liveUrl = 'http://127.0.0.1:${server.port}/ok';
  final live = await _probe(liveUrl, 5);
  await sub.cancel();
  await server.close(force: true);
  if (!live) {
    stderr.writeln('SELFTEST FAIL：可达地址被判成不可达');
    return 1;
  }
  stdout.writeln('SELFTEST OK（不可达判红、可达判绿）');
  return 0;
}
