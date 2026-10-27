import 'dart:io';

/// UI 边界检查：自有 UI 只准用 cupertino_ui；Material 仅限显式岛。
///
/// 用法：
///   dart run scripts/check_ui_boundary.dart
///   dart run scripts/check_ui_boundary.dart --strict   # 迁移收口后：不再跳过 pending 包
///   dart run scripts/check_ui_boundary.dart --root <dir> --strict
///
/// 白名单逐文件写明原因与移除条件。

const _scanRoots = <String>[
  'apps/life_launcher/lib',
  'packages/app_core/lib',
  'packages/feature_task/lib',
  'packages/feature_calendar/lib',
  'packages/feature_note/lib',
];

/// 迁移中的包：本轮 PR 只收口壳层，其余三包在各自 PR 内逐步从 pending 移除。
const _pendingPackages = <String>{
  'packages/feature_task',
  'packages/feature_calendar',
  'packages/feature_note',
};

/// 允许出现 Material API 的文件（仅这些文件）。
const _materialAllowed = <String>{
  // ThemeData 供 Material 岛使用。
  'packages/app_core/lib/src/theme/life_tokens.dart',
  // Material 岛宿主。
  'packages/app_core/lib/src/theme/life_material_island.dart',
  // 根 ScaffoldMessenger（过渡期，feature_note 迁移完成后移除）。
  'apps/life_launcher/lib/main.dart',
  // 未迁移 feature 的过渡岛 + 任务详情底部弹层（#129/#131 完成后移除）。
  'apps/life_launcher/lib/router/life_router.dart',
};

const _materialMarkers = <String>[
  'package:flutter/material.dart',
  'MaterialPageRoute',
  'ScaffoldMessenger',
  'showModalBottomSheet',
  'showDialog',
];

const _cupertinoMarkers = <String>[
  'package:flutter/cupertino.dart',
];

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

void main(List<String> args) {
  final root = _argValue(args, '--root') ?? '.';
  final strict = args.contains('--strict');
  final violations = <String>[];
  var scanned = 0;
  final pending = <String>[];

  for (final rel in _scanRoots) {
    final isPending =
        _pendingPackages.any((p) => rel == '$p/lib' || rel.startsWith('$p/'));
    if (isPending && !strict) {
      pending.add(rel);
      continue;
    }
    final dir = Directory('$root/$rel');
    if (!dir.existsSync()) continue;
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      scanned++;
      final relPath = file.path.startsWith('$root/')
          ? file.path.substring(root.length + 1)
          : file.path;
      final allowMaterial = _materialAllowed.contains(relPath);
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final marker in _cupertinoMarkers) {
          if (line.contains(marker)) {
            violations.add('$relPath:${i + 1}  SDK Cupertino（改 cupertino_ui）: $marker');
          }
        }
        if (allowMaterial) continue;
        for (final marker in _materialMarkers) {
          if (line.contains(marker)) {
            violations.add('$relPath:${i + 1}  Material 越界: $marker');
          }
        }
      }
    }
  }

  for (final p in pending) {
    stdout.writeln('PENDING  $p（迁移中，暂不检查）');
  }
  stdout.writeln('scanned=$scanned  pending=${pending.length}  violations=${violations.length}');
  if (violations.isEmpty) {
    stdout.writeln('UI boundary OK');
    return;
  }
  for (final v in violations) {
    stderr.writeln('FAIL  $v');
  }
  exitCode = 1;
}
