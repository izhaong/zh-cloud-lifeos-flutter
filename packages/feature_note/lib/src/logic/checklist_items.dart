/// 清单面板的 Delta → 行级清单项（#222）。
///
/// Quill 把行属性 `list` 挂在换行符上，delta 形如
/// `[{insert:"买菜"}, {insert:"\n", attributes:{list:"unchecked"}}]`。
/// 逐 op 取文字的旧实现命中的是 "\n" 本身，面板行文字恒为空；
/// 这里按「行」拼文本，并把换行符偏移作为 formatText 的目标。
library;

class ChecklistItem {
  const ChecklistItem({
    required this.start,
    required this.text,
    required this.done,
  });

  /// 该行换行符在 delta 中的偏移（勾选即改写此处的 list 属性）。
  final int start;
  final String text;
  final bool done;
}

List<ChecklistItem> parseChecklistItems(List<dynamic> deltaJson) {
  var offset = 0;
  final buffer = StringBuffer();
  String? pendingList;
  final items = <ChecklistItem>[];

  for (final raw in deltaJson) {
    if (raw is! Map) {
      continue;
    }
    final insert = raw['insert'];
    final attrs = raw['attributes'];
    final list = attrs is Map ? attrs['list'] : null;
    final listName = list is String && list.isNotEmpty ? list : null;

    if (insert is! String) {
      pendingList = listName ?? pendingList;
      offset += 1;
      continue;
    }

    var index = 0;
    while (true) {
      final newline = insert.indexOf('\n', index);
      if (newline < 0) {
        buffer.write(insert.substring(index));
        break;
      }
      buffer.write(insert.substring(index, newline));
      final lineList = listName ?? pendingList;
      if (lineList != null) {
        items.add(
          ChecklistItem(
            start: offset + newline,
            text: buffer.toString().trim(),
            done: lineList == 'checked',
          ),
        );
      }
      buffer.clear();
      pendingList = null;
      index = newline + 1;
    }
    if (!insert.contains('\n')) {
      pendingList = listName ?? pendingList;
    }
    offset += insert.length;
  }
  return items;
}
