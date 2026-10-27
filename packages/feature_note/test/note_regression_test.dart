// TC-NOTE-REG-102/103：包边界与生态文案回归（R-01）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TC-NOTE-REG-103 lib 不含生态绑定文案', () {
    const terms = ['icloud', 'siri', 'apple intelligence', 'handoff'];
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final text = entity.readAsStringSync().toLowerCase();
      for (final term in terms) {
        if (text.contains(term)) {
          offenders.add('${entity.path}: $term');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('TC-NOTE-REG-102 不 import feature_task / feature_calendar', () {
    final pattern = RegExp(r'''import\s+['"][^'"]*feature_(task|calendar)''');
    final offenders = <String>[];
    for (final dir in ['lib', 'test']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        for (final line in entity.readAsLinesSync()) {
          if (pattern.hasMatch(line)) {
            offenders.add('${entity.path}: ${line.trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('契约 §8：flutter_quill 固定 11.6.0 且不引入 flutter_quill_extensions', () {
    final pubspec = File('pubspec.yaml')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('#'))
        .join('\n');
    expect(pubspec, contains('flutter_quill: 11.6.0'));
    expect(pubspec, isNot(contains('flutter_quill_extensions')));
  });
}
