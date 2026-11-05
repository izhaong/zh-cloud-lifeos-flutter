import 'dart:convert';

/// Markdown 编解码（F-15；契约 §3 导出标题+纯文本，清单 `- [ ]`/`- [x]`）。
///
/// 开源包本地实现；服务端 commonmark 版在 S-11。
class NoteMarkdownCodec {
  const NoteMarkdownCodec._();

  /// Delta JSON → Markdown（标题 + 段落/清单）。
  ///
  /// 行属性（`header`/`list`）在 Quill 规范落点里挂在含 `\n` 的那个 op 上，
  /// 旧落点则挂在同一行的文本 op 上；两种都认，否则规范落点的清单会导出成
  /// 没有 `- [ ]` 前缀的普通段落（#237）。
  static String toMarkdown(String title, String bodyDelta) {
    final sb = StringBuffer();
    if (title.trim().isNotEmpty) {
      sb.writeln('# ${title.trim()}');
      sb.writeln();
    }
    final line = StringBuffer();
    Map? lineAttrs;
    void flush() {
      final text = line.toString();
      line.clear();
      final attrs = lineAttrs;
      lineAttrs = null;
      if (text.isEmpty) return;
      var prefix = '';
      if (attrs != null) {
        final header = attrs['header'];
        if (header is num) {
          prefix = '${'#' * header.toInt()} ';
        } else if (attrs['list'] is String) {
          prefix = switch (attrs['list'] as String) {
            'checked' => '- [x] ',
            'unchecked' => '- [ ] ',
            'ordered' => '1. ',
            _ => '- ',
          };
        }
      }
      sb.writeln('$prefix$text');
      if (prefix.isNotEmpty) sb.writeln();
    }

    for (final op in _ops(bodyDelta)) {
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = op['attributes'];
      if (attrs is Map &&
          (attrs['list'] is String || attrs['header'] is num)) {
        lineAttrs = attrs;
      }
      final link = attrs is Map ? attrs['link'] : null;
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) flush(); // 换行 → 上一行结束
        final seg = parts[i];
        if (seg.isEmpty) continue;
        // #397：链接段导成 commonmark 的 `[文字](url)`，否则正文里链接消失。
        line.write(
          link is String && link.isNotEmpty ? '[$seg]($link)' : seg,
        );
      }
    }
    flush();
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
        _addLine(ops, text, {
          'header': level < 1 ? 1 : line.substring(0, level).length,
        });
        continue;
      }
      final task = RegExp(r'^[-*]\s+\[( |x|X)\]\s*(.*)$').firstMatch(line);
      if (task != null) {
        _addLine(ops, task.group(2) ?? '', {
          'list': task.group(1) == ' ' ? 'unchecked' : 'checked',
        });
        continue;
      }
      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        _addLine(ops, bullet.group(1) ?? '', {'list': 'bullet'});
        continue;
      }
      _addLine(ops, line);
    }
    if (ops.isEmpty) {
      ops.add({'insert': '\n'});
    }
    return (
      title: (title == null || title.isEmpty) ? '导入的备忘录' : title,
      deltaJson: jsonEncode({'ops': ops}),
    );
  }

  static final RegExp _linkPattern = RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)');

  /// 一行 → 若干 op（#397）：行内 `[文字](url)` 拆成带 `link` 的段，行属性
  /// （`header`/`list`）只挂在末尾那个含 `\n` 的 op 上。
  ///
  /// 不能把行内属性和行属性挤在同一个 op：quill 11.6.0 的 `Line.insert` 对
  /// 「行上带行内属性」会断言；而 #237 已定口径是行属性必须落含 `\n` 的 op，
  /// 否则渲染不出勾选框。
  static void _addLine(
    List<Map<String, Object>> ops,
    String text, [
    Map<String, Object>? lineAttrs,
  ]) {
    var cursor = 0;
    for (final m in _linkPattern.allMatches(text)) {
      if (m.start > cursor) {
        ops.add({'insert': text.substring(cursor, m.start)});
      }
      ops.add({
        'insert': m.group(1)!,
        'attributes': <String, Object>{'link': m.group(2)!},
      });
      cursor = m.end;
    }
    if (cursor < text.length) {
      ops.add({'insert': text.substring(cursor)});
    }
    ops.add({'insert': '\n', 'attributes': ?lineAttrs});
  }

  /// 把「清单属性挂在文本 op 上、行尾 `\n` 单独成 op」的旧落点，改成 Quill
  /// 规范落点（行属性只认含 `\n` 的那个 op）。
  ///
  /// #237：quill 11.6.0 的 `Line.insert` 只在遇到 `\n` 时才 `_format(style)`，
  /// 才会把该行包进 `Block(list)`；只有 `Block` 分支才渲染行首勾选框。
  /// 旧落点因此渲染不出勾选框（行内一行纯文字），只靠内核
  /// `countChecklist` 的兼容分支计数——渲染与计数口径不一致。
  ///
  /// 只搬 `list` 一个键，其余行内属性留在原 op 上（否则会触发 quill
  /// 「行上不许有行内属性」的断言）。无法识别或没有可搬的键时原样返回。
  static String normalizeListAttributes(String bodyDelta) {
    final ops = _ops(bodyDelta);
    if (ops.isEmpty) return bodyDelta;
    final out = <Map<String, Object?>>[];
    var changed = false;
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final insert = op['insert'];
      final attrs = op['attributes'];
      if (insert is String &&
          !insert.contains('\n') &&
          attrs is Map &&
          attrs['list'] is String &&
          i + 1 < ops.length) {
        final next = ops[i + 1];
        final nextAttrs = next['attributes'];
        if (next['insert'] == '\n' &&
            (nextAttrs == null || (nextAttrs is Map && nextAttrs.isEmpty))) {
          final rest = Map<String, Object?>.from(attrs)..remove('list');
          out.add({
            'insert': insert,
            if (rest.isNotEmpty) 'attributes': rest,
          });
          out.add({
            'insert': '\n',
            'attributes': <String, Object?>{'list': attrs['list']},
          });
          i++; // 行尾 op 已被合并进上面那条
          changed = true;
          continue;
        }
      }
      out.add(Map<String, Object?>.from(op));
    }
    if (!changed) return bodyDelta;
    return jsonEncode({'ops': out});
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
