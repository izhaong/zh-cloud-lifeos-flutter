import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// #234：Cupertino 弹层用 SDK 常量样式（fontFamily: CupertinoSystemText），
/// 不吃 CupertinoThemeData.textTheme；回退必须叠在常量样式之下。
void main() {
  const noto = 'Noto Sans SC';

  Widget host(Widget child) => CupertinoApp(home: Center(child: child));

  Iterable<TextStyle> stylesOf(WidgetTester tester, String text) =>
      tester
          .widgetList<RichText>(find.byType(RichText))
          .where((rt) => rt.text.toPlainText() == text)
          .map((rt) => rt.text.style)
          .whereType<TextStyle>();

  testWidgets('帮衬：裸 CupertinoAlertDialog 不带 CJK 回退（本单要修的缺口）', (tester) async {
    await tester.pumpWidget(
      host(
        const CupertinoAlertDialog(
          title: Text('导出'),
          content: Text('购物清单'),
          actions: [
            CupertinoDialogAction(onPressed: null, child: Text('关闭')),
          ],
        ),
      ),
    );

    for (final label in ['导出', '购物清单', '关闭']) {
      final styles = stylesOf(tester, label).toList();
      expect(styles, isNotEmpty, reason: '找不到 $label 的 RichText');
      expect(
        styles.any((s) => (s.fontFamilyFallback ?? const []).contains(noto)),
        isFalse,
        reason: 'SDK 常量样式本就没有回退；若这里变真说明前提已变',
      );
    }
  });

  testWidgets('LifeAlertDialog 标题/正文/按钮都带 CJK 回退', (tester) async {
    await tester.pumpWidget(
      host(
        const LifeAlertDialog(
          title: Text('导出'),
          content: Text('购物清单'),
          actions: [
            LifeDialogAction(onPressed: null, child: Text('关闭')),
          ],
        ),
      ),
    );

    for (final label in ['导出', '购物清单', '关闭']) {
      final styles = stylesOf(tester, label).toList();
      expect(styles, isNotEmpty, reason: '找不到 $label 的 RichText');
      expect(
        styles.any((s) => (s.fontFamilyFallback ?? const []).contains(noto)),
        isTrue,
        reason: '$label 缺 CJK 回退',
      );
    }
  });

  testWidgets('回退不覆盖弹层原有字体与字号', (tester) async {
    await tester.pumpWidget(
      host(
        const LifeAlertDialog(
          title: Text('导出'),
          content: Text('购物清单'),
          actions: [
            LifeDialogAction(onPressed: null, child: Text('关闭')),
          ],
        ),
      ),
    );

    for (final label in ['导出', '购物清单', '关闭']) {
      final style = stylesOf(tester, label).first;
      expect(style.fontFamily, 'CupertinoSystemText', reason: '$label 字体被改写');
      expect(style.fontSize, isNotNull, reason: '$label 字号丢失');
    }
  });
}
