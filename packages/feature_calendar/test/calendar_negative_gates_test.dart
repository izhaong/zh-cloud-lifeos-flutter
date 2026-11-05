import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R-01 负向门禁（TC-CAL-REG-901/902/903/904/905；契约 §9 剥离清单）。
///
/// 断言的是「仓库里不存在」，所以路径缺失一律判红——静默跳过会把门禁变成假绿。
void main() {
  /// 本包在 melos 工作区里的兄弟包目录（测试 cwd = 本包根）。
  List<String> scanRoots(List<String> relative) {
    final roots = <String>[];
    for (final r in relative) {
      final dir = Directory(r);
      if (!dir.existsSync()) {
        fail('门禁扫描路径不存在：$dir（工作区结构变化会让本用例失去判别力）');
      }
      roots.add(r);
    }
    return roots;
  }

  /// 收集待检查源码：只看 Dart 与 Vue 模板，注释也一并算（剥离清单要求「不留文案」）。
  List<File> dartFiles(List<String> roots) => [
    for (final root in roots)
      ...Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ];

  String hits(Iterable<File> files, List<String> tokens) {
    final found = <String>[];
    for (final f in files) {
      final text = f.readAsStringSync();
      for (final token in tokens) {
        final index = text.toLowerCase().indexOf(token.toLowerCase());
        if (index >= 0) {
          final line = text.substring(0, index).split('\n').length;
          found.add('${f.path}:$line 命中「$token」');
        }
      }
    }
    return found.join('\n');
  }

  test('TC-CAL-REG-901 无 iCloud 文案（含注释）', () {
    final files = dartFiles(
      scanRoots([
        'lib',
        '../feature_calendar_cloud/lib',
        '../feature_productivity_kernel/lib',
        '../feature_productivity_drift/lib',
      ]),
    );
    expect(files, isNotEmpty);
    expect(hits(files, ['iCloud']), isEmpty);
  });

  test('TC-CAL-REG-902 无 Siri / Apple Intelligence', () {
    final files = dartFiles(
      scanRoots(['lib', '../feature_calendar_cloud/lib']),
    );
    expect(hits(files, ['Siri', 'Apple Intelligence']), isEmpty);
  });

  test('TC-CAL-REG-903 无「生日」日历入口', () {
    final files = dartFiles(
      scanRoots(['lib', '../feature_calendar_cloud/lib']),
    );
    expect(hits(files, ['生日']), isEmpty);
  });

  test('TC-CAL-REG-904 无 FaceTime / Exchange / CarPlay', () {
    final files = dartFiles(
      scanRoots(['lib', '../feature_calendar_cloud/lib']),
    );
    expect(hits(files, ['FaceTime', 'Exchange', 'CarPlay']), isEmpty);
  });

  test('TC-CAL-REG-905 日历与任务包互不 import', () {
    final calendarFiles = dartFiles(scanRoots(['lib']));
    final taskFiles = dartFiles(scanRoots(['../feature_task/lib']));
    expect(
      hits(taskFiles, ['package:feature_calendar']),
      isEmpty,
      reason: '任务包不得依赖日历包（日历只依赖 kernel）',
    );
    expect(
      hits(calendarFiles, ['package:feature_task']),
      isEmpty,
      reason: '日历包不得依赖任务包',
    );
  });
}
