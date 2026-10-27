import 'dart:convert';

/// Markdown 编解码（F-15；契约 §3 导出标题+纯文本，清单 `- [ ]`/`- [x]`）。
///
/// 开源包本地实现；服务端 commonmark 版在 S-11。
class NoteMarkdownCodec {
  const NoteMarkdownCodec._();

  /// Delta JSON → Markdown（标题 + 段落/清单）。
  static String toMarkdown(String title, String bodyDelta) {
    final sb = StringBuffer();
    if (title.trim().isNotEmpty) {
      sb.writeln('# ${title.trim()}');
      sb.writeln();
    }
    final ops = _ops(bodyDelta);
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = op['attributes'];
      var prefix = '';
      if (attrs is Map) {
        final header = attrs['header'];
        if (header is num) {
          prefix = '${'#' * header.toInt()} ';
        } else if (attrs['list'] is String) {
          final list = attrs['list'] as String;
          prefix = switch (list) {
            'checked' => '- [x] ',
            'unchecked' => '- [ ] ',
            'ordered' => '1. ',
            _ => '- ',
          };
        }
      }
      final text = insert.endsWith('\n') ? insert.substring(0, insert.length - 1) : insert;
      if (text.isEmpty) continue;
      sb.writeln('$prefix$text');
      if (prefix.isNotEmpty) sb.writeln();
    }
    return sb.toString();
  }

  /// Markdown → (title, Delta JSON)。支持 `#` 标题、`- [ ]`/`- [x]` 清单与段落。
  static ({String title, String deltaJson}) fromMarkdown(String markdown) {
    String? title;
    final ops = <Map<String, Object>>[];
    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;
      if (title == null && line.startsWith('# ')) {
        title = line.substring(2).trim();
        continue;
      }
      if (line.startsWith('#')) {
        final level = line.indexOf(' ');
        final text = level > 0 ? line.substring(level + 1).trim() : line;
        if (text.isEmpty) continue;
        ops.add({
          'insert': '$text\n',
          'attributes': {'header': level < 1 ? 1 : line.substring(0, level).length},
        });
        continue;
      }
      final task = RegExp(r'^[-*]\s+\[( |x|X)\]\s*(.*)$').firstMatch(line);
      if (task != null) {
        ops.add({
          'insert': '${task.group(2)}\n',
          'attributes': {
            'list': task.group(1) == ' ' ? 'unchecked' : 'checked',
          },
        });
        continue;
      }
      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        ops.add({
          'insert': '${bullet.group(1)}\n',
          'attributes': {'list': 'bullet'},
        });
        continue;
      }
      ops.add({'insert': '$line\n'});
    }
    if (ops.isEmpty) {
      ops.add({'insert': '\n'});
    }
    return (
      title: (title == null || title.isEmpty) ? '导入的备忘录' : title,
      deltaJson: jsonEncode({'ops': ops}),
    );
  }

  static List<Map> _ops(String bodyDelta) {
    if (bodyDelta.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(bodyDelta);
      if (decoded is! Map) return const [];
      final ops = decoded['ops'];
      if (ops is! List) return const [];
      return ops.whereType<Map>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
