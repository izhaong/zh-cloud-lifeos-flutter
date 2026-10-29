// 守卫（#304）：paint 通道不得直接收到**未解算**的 Apple 动态色。
//
// 背景：`ColoredBox` / `Container(color:)` / `BoxDecoration` / `BorderSide` / `Border.all`
// 这几条通道**都不解算** `CupertinoDynamicColor`，暗色档会画亮档值。#295 修了侧栏背板与
// 发丝线，#304 收了其余 20 处；本测试把口径固定下来，防止新代码再漏。
//
// 同时盯住另一种更隐蔽的漂移：`CalendarTokens.systemRed/systemBlue` 是**静态** Color
// （写死亮档值），暗色档需要动态版本 → 必须用 `CupertinoColors.*.resolveFrom(context)`。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 会画到屏幕上的通道；每条都要求色值先 resolveFrom。
final _channels = <String, RegExp>{
  'ColoredBox': RegExp(r'ColoredBox\([\s\S]{0,120}?color:\s*'
      r'((?:CalendarTokens|CupertinoColors)\.[A-Za-z0-9_]+)'),
  'BorderSide': RegExp(r'BorderSide\([\s\S]{0,120}?color:\s*'
      r'((?:CalendarTokens|CupertinoColors)\.[A-Za-z0-9_]+)'),
  'Border.all': RegExp(r'Border\.all\([\s\S]{0,80}?color:\s*'
      r'((?:CalendarTokens|CupertinoColors)\.[A-Za-z0-9_]+)'),
  'BoxDecoration': RegExp(r'BoxDecoration\([\s\S]{0,120}?color:\s*'
      r'((?:CalendarTokens|CupertinoColors)\.[A-Za-z0-9_]+)'),
};

void main() {
  test('动态色交给 paint 前必须 resolveFrom（#304）', () {
    final violations = <String>[];
    final dir = Directory('lib/src');
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final entry in _channels.entries) {
        for (final match in entry.value.allMatches(text)) {
          // 允许的两种写法：紧跟着 .resolveFrom(…)，或本行已含 resolveFrom
          final tail = text.substring(match.end, (match.end + 40).clamp(0, text.length));
          final lineStart = text.lastIndexOf('\n', match.start) + 1;
          final lineEnd = text.indexOf('\n', match.end);
          final line = text.substring(lineStart, lineEnd == -1 ? text.length : lineEnd);
          if (tail.startsWith('.resolveFrom') || line.contains('resolveFrom')) {
            continue;
          }
          final lineNo = text.substring(0, match.start).split('\n').length;
          violations.add('${file.path}:$lineNo ${entry.key}=${match.group(1)}');
        }
      }
    }
    expect(violations, isEmpty,
        reason: '这些位置把未解算的 Apple 动态色直接交给了 paint，暗色档会画亮档值：\n'
            '${violations.join('\n')}');
  });

  test('静态 token 不得冒充动态色（systemRed/systemBlue 需用 CupertinoColors 动态版）', () {
    final dir = Directory('lib/src');
    final hits = <String>[];
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      // CalendarTokens.systemRed/systemBlue 是 const Color（亮档写死），
      // 只有 calendar_tokens.dart 自己可以定义它们。
      if (file.path.endsWith('calendar_tokens.dart')) continue;
      for (final m in RegExp(r'CalendarTokens\.(systemRed|systemBlue)')
          .allMatches(text)) {
        final lineNo = text.substring(0, m.start).split('\n').length;
        final lineEnd = text.indexOf('\n', m.end);
        final line = text.substring(
            text.lastIndexOf('\n', m.start) + 1,
            lineEnd == -1 ? text.length : lineEnd);
        // 允许在非 paint 语境（例如传给 Calendar 模型、用作字重判断等）——
        // 这里只拦「直接当 paint 色」的写法。
        if (RegExp(r'(color:|Color\()').hasMatch(line) &&
            !line.contains('resolveFrom')) {
          hits.add('${file.path}:$lineNo $line');
        }
      }
    }
    expect(hits, isEmpty,
        reason: '这些位置用了静态 systemRed/systemBlue 当 paint 色，暗色档不会跟随：\n'
            '${hits.join('\n')}');
  });
}
