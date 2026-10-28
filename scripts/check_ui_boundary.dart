import 'dart:io';

/// UI 边界检查：自有 UI 只准用 cupertino_ui；Material 仅限显式岛。
///
/// 用法：
///   dart run scripts/check_ui_boundary.dart
///   dart run scripts/check_ui_boundary.dart --strict   # 迁移收口后：不再跳过 pending 包
///   dart run scripts/check_ui_boundary.dart --root `<dir>` --strict
///
/// 白名单逐文件写明原因与移除条件。

/// 扫描根自动发现：覆盖 `apps/*/lib` 与 `packages/*/lib`。
/// 原先硬编码 5 个根，静默漏掉 6 个包（含 feature_task_cloud 里那个 SDK Cupertino 登录页），
/// 使 `violations` 看起来比真实少。改为发现式，新增包自动纳管。
List<String> _discoverScanRoots(String root) {
  final found = <String>[];
  for (final base in const ['apps', 'packages']) {
    final dir = Directory('$root/$base');
    if (!dir.existsSync()) continue;
    for (final entry in dir.listSync().whereType<Directory>()) {
      final lib = '${entry.path}/lib';
      if (!Directory(lib).existsSync()) continue;
      found.add(
        lib.startsWith('$root/') ? lib.substring(root.length + 1) : lib,
      );
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
      final countHex = isUiFile && !isTokenFile;
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
        // C3：裸 hex 计数（尺子；本次不阻断，由 --max-hex 收口）
        if (countHex) {
          final hexCount = _bareHex.allMatches(line).length;
          if (hexCount > 0) {
            result.hexByPackage[pkg] =
                (result.hexByPackage[pkg] ?? 0) + hexCount;
          }
        }
        if (allowMaterial) continue;
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
    final result = scanBoundary(tmp.path, strict: true);
    final all = result.violations.join('\n');
    final cases = <String, bool>{
      'C1 SDK Cupertino 导入': all.contains('SDK Cupertino'),
      'C2 fromSeed': all.contains('ColorScheme.fromSeed'),
      'Material 越界': all.contains('Material 越界'),
      // 坏样本里 UI 文件 2 处（fromSeed 的 seed + 裸色），令牌目录那 1 处被排除
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
