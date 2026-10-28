// 守卫：lifeos 测试不得被**静默跳过**（#355）。
//
// 由来：台账里 302 条「已自动化」的判据是「测试存在且在跑」；一旦有人在测试里加
// `skip: true`（调试遗留、临时跳过、或「先把基线当素材」），套件仍然绿，
// 那些「已自动化」立刻变成空话。这类漂移靠人肉扫才发现，所以固定成检查。
//
// 用法：
//   dart run scripts/check_skipped_tests.dart            # 扫真实测试目录
//   dart run scripts/check_skipped_tests.dart --selftest # 造坏样本，证明能判红
//
// 白名单 `skipAllowed` 为空；将来若确有必要（例如平台专属测试），往这里加并写明理由。
import 'dart:io';

/// 允许出现的 `skip`（键：`相对路径:行号`，值：理由）。空 = 一律不许。
const skipAllowed = <String, String>{};

/// 命中模式：`skip:` 后跟 true/非 false 的表达式都算跳过。
final _skipPattern = RegExp(r'\bskip\s*:\s*(?!false\b)\S');

Future<void> main(List<String> args) async {
  final selftest = args.contains('--selftest');
  if (selftest) {
    final ok = await _selftest();
    exit(ok ? 0 : 1);
  }
  final hits = _scan(Directory.current);
  if (hits.isEmpty) {
    stdout.writeln('OK  没有被静默跳过的测试（scan 完 packages/*/test 与 apps/*/test）');
    return;
  }
  var red = 0;
  for (final hit in hits) {
    if (skipAllowed.containsKey(hit)) {
      stdout.writeln('  note  $hit —— ${skipAllowed[hit]}');
      continue;
    }
    stdout.writeln('  RED   $hit');
    red++;
  }
  if (red > 0) {
    stderr.writeln('FAIL  发现 $red 处 skip（测试会被静默跳过；确需跳过请加白名单并写理由）');
    exit(1);
  }
  stdout.writeln('OK  仅存在白名单内的 skip');
}

/// 扫 `packages/*/test` 与 `apps/*/test` 下的 .dart，返回 `相对路径:行号`。
List<String> _scan(Directory root) {
  final hits = <String>[];
  for (final top in ['packages', 'apps']) {
    final dir = Directory('${root.path}/$top');
    if (!dir.existsSync()) continue;
    for (final pkg in dir.listSync().whereType<Directory>()) {
      final tests = Directory('${pkg.path}/test');
      if (!tests.existsSync()) continue;
      for (final file in tests.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//')) continue; // 注释里提到 skip 不算
          if (_skipPattern.hasMatch(line)) {
            hits.add('${file.path.substring(root.path.length + 1)}:${i + 1}');
          }
        }
      }
    }
  }
  hits.sort();
  return hits;
}

Future<bool> _selftest() async {
  var ok = true;
  final tmp = Directory.systemTemp.createTempSync('skip_guard_');
  try {
    final pkgTest = Directory('${tmp.path}/packages/probe/test')
      ..createSync(recursive: true);
    File('${pkgTest.path}/a_test.dart').writeAsStringSync(
      'void main() {\n  testWidgets(\'x\', (t) async {}, skip: true);\n}\n',
    );
    final red = _scan(tmp);
    if (red.length != 1) {
      stderr.writeln('SELFTEST FAIL：含 skip: true 的样本应命中 1 处，实际 ${red.length}');
      ok = false;
    }

    // 显式 skip: false 不该命中；注释里的 skip 也不该命中
    File('${pkgTest.path}/b_test.dart').writeAsStringSync(
      '// 这里只是提到 skip: true 的注释\n'
      "void main() {\n  testWidgets('y', (t) async {}, skip: false);\n}\n",
    );
    File('${pkgTest.path}/a_test.dart').deleteSync();
    final clean = _scan(tmp);
    if (clean.isNotEmpty) {
      stderr.writeln('SELFTEST FAIL：skip: false 与注释不应命中，实际 $clean');
      ok = false;
    }
  } finally {
    tmp.deleteSync(recursive: true);
  }
  if (ok) stdout.writeln('SELFTEST OK（skip: true 判红；skip: false 与注释不误报）');
  return ok;
}
