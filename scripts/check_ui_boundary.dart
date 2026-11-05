import 'dart:io';

/// UI 边界检查：自有 UI 只准用 cupertino_ui；Material 仅限显式岛。
///
/// 用法：
///   dart run scripts/check_ui_boundary.dart
///   dart run scripts/check_ui_boundary.dart --strict   # 迁移收口后：不再跳过 pending 包
///   dart run scripts/check_ui_boundary.dart --root `<dir>` --strict
///
/// 白名单逐文件写明原因与移除条件。

/// 扫描根自动发现：覆盖 `apps/*/{lib,test}` 与 `packages/*/{lib,test}`。
/// 原先硬编码 5 个根，静默漏掉 6 个包（含 feature_task_cloud 里那个 SDK Cupertino 登录页），
/// 使 `violations` 看起来比真实少。改为发现式，新增包自动纳管。
///
/// #317 把 `test/` 也纳进来，但**只在 test 根施 C1（SDK Cupertino）**：
/// 生产侧 `packages/*/lib` 早已 0，缺口全在测试侧——`find.byIcon(CupertinoIcons.circle)`
/// 断的是 SDK 那份常量，而渲染用的是 `cupertino_ui` 那份（两个库各有一份 `CupertinoIcons`）。
/// `IconData` 有值相等（`icon_data.dart` 里 override 了 `==`/`hashCode`），所以两半今天
/// 恰好相等、测试是绿的；一旦上游码位或 `fontPackage` 分叉，正向断言会响，
/// 而 `expect(find.byIcon(…), findsNothing)` 这类**负断言会静默恒真**。
/// 同一条「自有 UI 走 cupertino_ui」对测试不算豁免（铁律 #7）。
List<String> _discoverScanRoots(String root) {
  final found = <String>[];
  for (final base in const ['apps', 'packages']) {
    final dir = Directory('$root/$base');
    if (!dir.existsSync()) continue;
    for (final entry in dir.listSync().whereType<Directory>()) {
      for (final sub in const ['lib', 'test']) {
        final path = '${entry.path}/$sub';
        if (!Directory(path).existsSync()) continue;
        found.add(
          path.startsWith('$root/') ? path.substring(root.length + 1) : path,
        );
      }
    }
  }
  found.sort();
  return found;
}

/// 迁移中的包：#129/#130/#131 已全部收口，pending 清空。
/// 记名豁免不等于收口：`--strict` 仍会全量列出，台账要引 `scanned/pending/violations` 三元组。
const _pendingPackages = <String>{};

/// 允许出现 Material API 的文件（仅这些文件）。
const _materialAllowed = <String>{
  // ThemeData 供 Material 岛使用。
  'packages/app_core/lib/src/theme/life_tokens.dart',
  // Material 岛宿主。
  'packages/app_core/lib/src/theme/life_material_island.dart',
  // 测试宿主（#293）：只给各包 test/ 用，不进生产路径；它必须提供 MaterialApp
  // 祖先，否则 kalender/quill 等 Material 岛的 widget 测试无处可挂。
  'packages/app_core/lib/test_support.dart',
};

const _materialMarkers = <String>[
  'package:flutter/material.dart',
  'MaterialPageRoute',
  'ScaffoldMessenger',
  'showModalBottomSheet',
  'showDialog',
];

const _cupertinoMarkers = <String>['package:flutter/cupertino.dart'];

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

/// 一次扫描的结果（selftest 与真实门禁共用同一套判据）。
class UiBoundaryResult {
  int scanned = 0;
  final List<String> violations = [];
  final List<String> pending = [];
  final Map<String, int> hexByPackage = {};
}

/// 注释行不参与判据：`life_tokens.dart` 里就有一句解释「不用 fromSeed」的注释。
bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//');
}

/// 字面色 = **`Color(0xRRGGBB)` / `Color(0xAARRGGBB)` 形式**的写死颜色。
/// 纯 int 调色板（`colorArgb = 0xFF...`、`const <int>[...]`）是**数据**不是样式，
/// 与 kernel 的默认色同类，不应计入 UI 债（#268）。
final _bareHex = RegExp(r'Color\(0x[Ff]{2}[0-9A-Fa-f]{6}');

UiBoundaryResult scanBoundary(String root, {bool strict = false}) {
  final result = UiBoundaryResult();
  for (final rel in _discoverScanRoots(root)) {
    final isPending = _pendingPackages.any(
      (p) => rel == '$p/lib' || rel.startsWith('$p/'),
    );
    if (isPending && !strict) {
      result.pending.add(rel);
      continue;
    }
    final dir = Directory('$root/$rel');
    if (!dir.existsSync()) continue;
    // rel 形如 packages/feature_task/lib：取第二段才是包名
    final segs = rel.split('/');
    final pkg = segs.length > 1 ? segs[1] : rel;
    // #317：test/ 根只施 C1（SDK Cupertino）。字面色与 Material 越界两条在生产侧已收口，
    // 测试宿主天然要挂在 MaterialApp 下（#293 的 test_support.dart 同源原因），
    // 把它们套到 test/ 会一次涌出上百条与对等无关的红，反而把 C1 淹掉。
    final isTestRoot = rel.endsWith('/test');
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      result.scanned++;
      final relPath = file.path.startsWith('$root/')
          ? file.path.substring(root.length + 1)
          : file.path;
      final allowMaterial = _materialAllowed.contains(relPath);
      final lines = file.readAsLinesSync();
      // C3 的计数口径：只算**UI 层**的字面色。
      // - 纯数据层的 ARGB 常量（kernel 的默认色/同步兜底色）不是 UI 债：
      //   kernel 不依赖 Flutter，也不该 import Cupertino 令牌；
      // - 令牌文件本身就是字面色的唯一合法落点（`/theme/`、`/design/`）。
      final source = lines.join('\n');
      final isUiFile = source.contains('package:flutter/') ||
          source.contains('package:cupertino_ui/');
      final isTokenFile =
          relPath.contains('/theme/') || relPath.contains('/design/');
      final countHex = isUiFile && !isTokenFile && !isTestRoot;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isComment(line)) continue;
        for (final marker in _cupertinoMarkers) {
          if (line.contains(marker)) {
            result.violations.add(
              '$relPath:${i + 1}  SDK Cupertino（改 cupertino_ui）: $marker',
            );
          }
        }
        // C2：Material 3 的 fromSeed 会把 007AFF 调成灰蓝，岛必须逐字段显式给色
        if (line.contains('ColorScheme.fromSeed')) {
          result.violations.add(
            '$relPath:${i + 1}  ColorScheme.fromSeed（应逐字段显式 ColorScheme）',
          );
        }
        // C3：字面色（`Color(0x…)`）计数（尺子；本次不阻断，由 --max-hex 收口）
        if (countHex) {
          final hexCount = _bareHex.allMatches(line).length;
          if (hexCount > 0) {
            result.hexByPackage[pkg] =
                (result.hexByPackage[pkg] ?? 0) + hexCount;
          }
        }
        // test/ 不判 Material 越界（#317 有意收窄，selftest 里有负对照）：
        // 各包测试宿主必须挂在 MaterialApp 祖先下，否则 kalender/quill 岛无处可挂。
        if (isTestRoot || allowMaterial) continue;
        for (final marker in _materialMarkers) {
          if (line.contains(marker)) {
            result.violations.add('$relPath:${i + 1}  Material 越界: $marker');
          }
        }
      }
    }
  }
  return result;
}

void main(List<String> args) {
  if (args.contains('--selftest')) {
    _selfTest();
    return;
  }
  final root = _argValue(args, '--root') ?? '.';
  final strict = args.contains('--strict');
  final maxHex = int.tryParse(_argValue(args, '--max-hex') ?? '');
  final result = scanBoundary(root, strict: strict);
  final violations = result.violations;
  var scanned = result.scanned;
  final pending = result.pending;

  final hexTotal = result.hexByPackage.values.fold<int>(0, (a, b) => a + b);
  if (result.hexByPackage.isNotEmpty) {
    final detail = (result.hexByPackage.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
    stdout.writeln('hex(bare)=$hexTotal  $detail');
  }
  if (maxHex != null && hexTotal > maxHex) {
    violations.add('裸 hex 超预算：$hexTotal > $maxHex（只减不增）');
  }
  for (final p in pending) {
    stdout.writeln('PENDING  $p（迁移中，暂不检查）');
  }
  stdout.writeln(
    'scanned=$scanned  pending=${pending.length}  violations=${violations.length}',
  );
  if (violations.isEmpty) {
    stdout.writeln('UI boundary OK');
    return;
  }
  for (final v in violations) {
    stderr.writeln('FAIL  $v');
  }
  exitCode = 1;
}


/// C4：每条判据都必须能判红（新尺首跑先证明它会红，否则绿也说明不了什么）。
void _selfTest() {
  final tmp = Directory.systemTemp.createTempSync('ui_boundary_selftest_');
  try {
    final lib = Directory('${tmp.path}/packages/demo/lib')..createSync(recursive: true);
    File('${lib.path}/bad.dart').writeAsStringSync('''
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
final scheme = ColorScheme.fromSeed(seedColor: 0xFF007AFF);
const c = Color(0xFF007AFF); // 裸色（写着色）
''');
    // 反向对照：令牌/主题目录里的字面色**不该**被计数（那是唯一合法落点）
    final tokens =
        Directory('${tmp.path}/packages/demo/lib/src/theme')..createSync(recursive: true);
    File('${tokens.path}/tokens.dart').writeAsStringSync('''
import 'package:flutter/painting.dart';
const systemBlue = Color(0xFF007AFF);
''');
    // #317 正对照：`test/` 根里的 SDK Cupertino import 必须同样判红，且这条红要能
    // 归因到 test/ 路径本身——否则它可能只是 lib/ 那条坏样本在替它说话（恒真）。
    final testDir = Directory('${tmp.path}/packages/demo/test')
      ..createSync(recursive: true);
    File('${testDir.path}/bad_test.dart').writeAsStringSync('''
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('icon', () => find.byIcon(CupertinoIcons.circle));
}
''');
    // #317 负对照：`test/` 不判 Material 越界是**刻意的收窄**（测试宿主天然要挂
    // MaterialApp）。哪天有人把 Material 判据也套到 test/ 上，这条会红，逼着去
    // #126 面 D 正面对待，而不是静默涌出上百条把 C1 淹掉。
    File('${testDir.path}/host_test.dart').writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('host', () => debugPrint(MaterialApp.toString()));
}
''');
    final result = scanBoundary(tmp.path, strict: true);
    final all = result.violations.join('\n');
    final cases = <String, bool>{
      'C1 SDK Cupertino 导入': all.contains('SDK Cupertino'),
      'C1 test/ 根同样判红（#317，归因到 test 路径）': result.violations.any(
        (v) =>
            v.startsWith('packages/demo/test/bad_test.dart:') &&
            v.contains('SDK Cupertino'),
      ),
      'test/ 不判 Material 越界（#317 负对照）': result.violations.every(
        (v) => !v.startsWith('packages/demo/test/host_test.dart:'),
      ),
      'C2 fromSeed': all.contains('ColorScheme.fromSeed'),
      'Material 越界': all.contains('Material 越界'),
      // 坏样本里 UI 文件 1 处（`Color(0xFF007AFF)` 字面色）；
      // `fromSeed(seedColor: 0xFF…)` 的 int seed 由 C2 单独判，不计入 C3；令牌目录那 1 处被排除
      'C3 字面色（Color() 形式，排除令牌/数据层）':
          (result.hexByPackage['demo'] ?? 0) == 1,
    };
    var failed = 0;
    for (final entry in cases.entries) {
      stdout.writeln(
        '${entry.value ? 'RED-as-expected' : 'GREEN?!'}  ${entry.key}',
      );
      if (!entry.value) failed++;
    }
    if (failed > 0) {
      stderr.writeln('SELFTEST FAIL：$failed 条判据没能判红');
      exitCode = 1;
      return;
    }
    stdout.writeln('selftest OK（全部判据都能判红）');
  } finally {
    tmp.deleteSync(recursive: true);
  }
}
