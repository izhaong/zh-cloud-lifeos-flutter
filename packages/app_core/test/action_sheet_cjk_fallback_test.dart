import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// #236：`CupertinoActionSheet` 与 `CupertinoActionSheetAction` 同样用 SDK
/// 常量样式（`CupertinoSystemText` / `CupertinoSystemDisplay`，`inherit: false`），
/// 标题/正文/按钮都要叠一层 CJK 回退。
void main() {
  const noto = 'Noto Sans SC';

  Widget host(Widget child) => CupertinoApp(home: Center(child: child));

  Iterable<TextStyle> stylesOf(WidgetTester tester, String text) =>
      tester
          .widgetList<RichText>(find.byType(RichText))
          .where((rt) => rt.text.toPlainText() == text)
          .map((rt) => rt.text.style)
          .whereType<TextStyle>();

  testWidgets('帮衬：裸 CupertinoActionSheet 不带 CJK 回退（本单要修的缺口）', (tester) async {
    await tester.pumpWidget(
      host(
        CupertinoActionSheet(
          title: const Text('导出'),
          message: const Text('购物清单'),
          actions: [
            CupertinoActionSheetAction(onPressed: () {}, child: const Text('删除')),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {},
            child: const Text('取消'),
          ),
        ),
      ),
    );

    for (final label in ['导出', '购物清单', '删除', '取消']) {
      final styles = stylesOf(tester, label).toList();
      expect(styles, isNotEmpty, reason: '找不到 $label 的 RichText');
      expect(
        styles.any((s) => (s.fontFamilyFallback ?? const []).contains(noto)),
        isFalse,
        reason: 'SDK 常量样式本就没有回退；若这里变真说明前提已变',
      );
    }
  });

  testWidgets('LifeActionSheet 标题/正文/按钮都带 CJK 回退', (tester) async {
    await tester.pumpWidget(
      host(
        LifeActionSheet(
          title: const Text('导出'),
          message: const Text('购物清单'),
          actions: [
            LifeActionSheetAction(onPressed: () {}, child: const Text('删除')),
          ],
          cancelButton: LifeActionSheetAction(
            onPressed: () {},
            child: const Text('取消'),
          ),
        ),
      ),
    );

    for (final label in ['导出', '购物清单', '删除', '取消']) {
      final styles = stylesOf(tester, label).toList();
      expect(styles, isNotEmpty, reason: '找不到 $label 的 RichText');
      expect(
        styles.any((s) => (s.fontFamilyFallback ?? const []).contains(noto)),
        isTrue,
        reason: '$label 缺 CJK 回退',
      );
    }
  });

  testWidgets('回退不覆盖操作表原有字体与字号', (tester) async {
    await tester.pumpWidget(
      host(
        LifeActionSheet(
          title: const Text('导出'),
          message: const Text('购物清单'),
          actions: [
            LifeActionSheetAction(onPressed: () {}, child: const Text('删除')),
          ],
          cancelButton: LifeActionSheetAction(
            onPressed: () {},
            child: const Text('取消'),
          ),
        ),
      ),
    );

    const textRoles = {'导出': 'CupertinoSystemText', '购物清单': 'CupertinoSystemText'};
    const actionRoles = {'删除': 'CupertinoSystemDisplay', '取消': 'CupertinoSystemDisplay'};
    for (final entry in {...textRoles, ...actionRoles}.entries) {
      final label = entry.key;
      final style = stylesOf(tester, label).first;
      expect(style.fontFamily, entry.value, reason: '$label 字体被改写');
      expect(style.fontSize, isNotNull, reason: '$label 字号丢失');
    }
  });
}
