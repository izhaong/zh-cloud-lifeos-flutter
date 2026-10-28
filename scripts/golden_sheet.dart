// 生成 golden 对照页（HTML），供 #127 的目视走查一次看完。
//
// 用法：dart run scripts/golden_sheet.dart [--out build/golden-sheet]
//
// 为什么需要：四层视觉基线散在三个包的 test/goldens/ 下，逐张打开成本高、容易漏。
// 这里只做「找图 + 拼一页」——不引入图片依赖、不做像素比对（那是 golden 测试本身的事）。
import 'dart:io';

const _groups = <String, String>{
  'apps/life_launcher': '壳（App Shell）',
  'packages/feature_task': '任务（Reminders）',
  'packages/feature_calendar': '日历（Calendar）',
  'packages/feature_note': '记录（Notes）',
};

/// Apple 参考图按文件名关键词归组；`docs/ui-evidence` 下的截图是**本地文件、
/// 不入库**（Apple 版权素材不该提交），所以只在本地存在时才并排。
const _evidenceHints = <String, List<String>>{
  'apps/life_launcher': ['shell'],
  'packages/feature_task': ['reminders'],
  'packages/feature_calendar': ['calendar'],
  'packages/feature_note': ['notes', 'note'],
};

Future<void> main(List<String> args) async {
  var outDir = 'build/golden-sheet';
  var includeEvidence = false;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) outDir = args[i + 1];
    if (args[i] == '--include-evidence') includeEvidence = true;
  }

  final found = <String, List<String>>{};
  for (final root in _groups.keys) {
    final dir = Directory('$root/test/goldens');
    if (!dir.existsSync()) continue;
    final pngs = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.png'))
        .toList()
      ..sort();
    if (pngs.isNotEmpty) found[root] = pngs;
  }

  final evidence = <String, List<String>>{};
  if (includeEvidence) {
    final dir = Directory('docs/ui-evidence');
    if (dir.existsSync()) {
      final pngs = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.endsWith('.png') && p.toLowerCase().contains('reference'))
          .toList()
        ..sort();
      for (final path in pngs) {
        final lower = path.toLowerCase();
        String? group;
        for (final entry in _evidenceHints.entries) {
          if (entry.value.any(lower.contains)) {
            group = entry.key;
            break;
          }
        }
        evidence.putIfAbsent(group ?? '_other', () => []).add(path);
      }
      if (evidence.isEmpty) {
        stdout.writeln('（docs/ui-evidence 里没有 *reference* 截图）');
      }
    } else {
      stdout.writeln('（没有 docs/ui-evidence，跳过参考图）');
    }
  }

  if (found.isEmpty) {
    stderr.writeln('没找到任何 golden（在仓库根跑？期望 apps/*/test/goldens/*.png）');
    exitCode = 1;
    return;
  }

  final out = Directory(outDir)..createSync(recursive: true);
  // 从 build/golden-sheet/ 回到仓库根的相对前缀（与 golden 用同一套）
  const rel = '../../';
  final buffer = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="zh-CN"><head><meta charset="utf-8">')
    ..writeln('<title>LifeOS golden 对照页</title>')
    ..writeln('<style>')
    ..writeln('body{font:14px/1.5 -apple-system,system-ui,sans-serif;margin:24px;background:#fafafa;color:#111}')
    ..writeln('h1{font-size:18px;margin:0 0 4px}')
    ..writeln('p.hint{color:#666;margin:0 0 24px}')
    ..writeln('h2{font-size:15px;margin:28px 0 8px;padding-bottom:4px;border-bottom:1px solid #e5e5e5}')
    ..writeln('.grid{display:flex;flex-wrap:wrap;gap:16px}')
    ..writeln('figure{margin:0;background:#fff;border:1px solid #e8e8e8;border-radius:8px;padding:8px}')
    ..writeln('figure img{display:block;max-width:360px;height:auto;border-radius:4px}')
    ..writeln('figcaption{margin-top:6px;font-size:12px;color:#555;max-width:360px;word-break:break-all}')
    ..writeln('figure.ref{border-color:#f0c36d;background:#fffdf5}')
    ..writeln('figure.ref figcaption b{color:#a9761a}')
    ..writeln('</style></head><body>')
    ..writeln('<h1>LifeOS golden 对照页</h1>')
    ..writeln('<p class="hint">${_total(found)} 张基线；与 Apple 参考图并排比：暗色档 / 间距圆角 / 图标 / 三档断点。</p>');

  for (final entry in _groups.entries) {
    final pngs = found[entry.key];
    if (pngs == null) continue;
    buffer.writeln('<h2>${entry.value}</h2><div class="grid">');
    for (final ref in evidence[entry.key] ?? const <String>[]) {
      final name = ref.split('/').last;
      buffer
        ..writeln('<figure class="ref">')
        ..writeln('<img src="$rel$ref" alt="$name">')
        ..writeln('<figcaption><b>Apple 参考</b><br>$name</figcaption>')
        ..writeln('</figure>');
    }
    for (final path in pngs) {
      final src = '$rel$path';
      final name = path.split('/').last;
      buffer
        ..writeln('<figure>')
        ..writeln('<img src="$src" alt="$name">')
        ..writeln('<figcaption>$name<br>$path</figcaption>')
        ..writeln('</figure>');
    }
    buffer.writeln('</div>');
  }
  final other = evidence['_other'];
  if (other != null && other.isNotEmpty) {
    buffer.writeln('<h2>其他参考图</h2><div class="grid">');
    for (final ref in other) {
      final name = ref.split('/').last;
      buffer
        ..writeln('<figure class="ref">')
        ..writeln('<img src="$rel$ref" alt="$name">')
        ..writeln('<figcaption>$name</figcaption>')
        ..writeln('</figure>');
    }
    buffer.writeln('</div>');
  }
  buffer.writeln('</body></html>');

  final file = File('${out.path}/index.html')..writeAsStringSync(buffer.toString());
  stdout.writeln('已生成 ${file.path}（${_total(found)} 张）');
}

int _total(Map<String, List<String>> found) =>
    found.values.fold(0, (sum, list) => sum + list.length);
