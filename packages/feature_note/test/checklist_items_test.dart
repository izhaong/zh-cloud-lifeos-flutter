import 'package:feature_note/feature_note.dart';
import 'package:flutter_test/flutter_test.dart';

/// #222 清单面板按「行」取文本：Quill 把 list 属性挂在换行符上。
void main() {
  test('#222 行属性在换行符上时取到整行文字', () {
    final items = parseChecklistItems([
      {'insert': '买菜'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
    ]);

    expect(items, hasLength(1));
    expect(items.single.text, '买菜', reason: '旧实现取的是换行符本身，文字恒为空');
    expect(items.single.start, 2, reason: '勾选应改写该行换行符处的 list 属性');
    expect(items.single.done, isFalse);
  });

  test('#222 文本与换行同一 op 也能取到', () {
    final items = parseChecklistItems([
      {
        'insert': '牛奶\n',
        'attributes': {'list': 'checked'},
      },
    ]);

    expect(items, hasLength(1));
    expect(items.single.text, '牛奶');
    expect(items.single.start, 2);
    expect(items.single.done, isTrue);
  });

  test('#222 list 属性挂在文本 op 上（无换行）也归属该行', () {
    final items = parseChecklistItems([
      {
        'insert': '鸡蛋',
        'attributes': {'list': 'unchecked'},
      },
      {'insert': '\n'},
    ]);

    expect(items, hasLength(1));
    expect(items.single.text, '鸡蛋');
    expect(items.single.start, 2);
  });

  test('#222 普通段落不产生清单项，多行清单逐行产出', () {
    final items = parseChecklistItems([
      {'insert': '标题\n'},
      {'insert': '买菜'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
      {'insert': '备注\n'},
    ]);

    expect(items, hasLength(1));
    expect(items.single.text, '买菜');
    // 「标题\n」占 3，第二个换行符落在 3 + 2 = 5
    expect(items.single.start, 5);
  });
}
