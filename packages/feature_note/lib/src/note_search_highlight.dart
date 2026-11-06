import 'package:cupertino_ui/cupertino_ui.dart';

/// 命中片段：[text] 是原文切片，[hit] 标记它是否为匹配词。
typedef NoteMatchPart = ({String text, bool hit});

/// 搜索命中切分（#660，大小写不敏感）。
///
/// 空查询、空文本或整串未命中都返回 null，表示「按普通文本渲染」——无搜索词时
/// 列表结构与改动前完全相同，`test/note_golden_test.dart` 的基线因此不必重录。
///
/// 逐窗口比较而不是整串 `toLowerCase()`：个别字符（如 `İ`）大小写折叠后长度会变，
/// 整串折叠会让下标对不上原文，高亮就会切错字。
List<NoteMatchPart>? splitNoteMatches(String text, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty || text.isEmpty) return null;
  final parts = <NoteMatchPart>[];
  var done = 0; // 已切出的尾部下标
  var scan = 0; // 扫描位置
  while (scan + needle.length <= text.length) {
    if (text.substring(scan, scan + needle.length).toLowerCase() != needle) {
      scan++;
      continue;
    }
    if (scan > done) {
      parts.add((text: text.substring(done, scan), hit: false));
    }
    parts.add((text: text.substring(scan, scan + needle.length), hit: true));
    scan += needle.length;
    done = scan;
  }
  if (parts.isEmpty) return null;
  if (done < text.length) parts.add((text: text.substring(done), hit: false));
  return parts;
}

/// 标题/摘要文本：搜索态下把匹配词加底色，其余原样。
class NoteMatchText extends StatelessWidget {
  const NoteMatchText(
    this.text, {
    required this.query,
    super.key,
    this.style,
    this.maxLines,
  });

  final String text;

  /// 搜索词（内部再 trim；空 = 不高亮）。
  final String query;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final parts = splitNoteMatches(text, query);
    if (parts == null) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    final hit = TextStyle(
      backgroundColor: CupertinoColors.secondarySystemFill.resolveFrom(context),
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final p in parts)
            TextSpan(text: p.text, style: p.hit ? hit : null),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
