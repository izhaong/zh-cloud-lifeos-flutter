// 辅助功能对等：Apple「粗体文本」（Bold Text）必须在主题层生效。
//
// 局限（与实现注释一致）：只覆盖主题层字重，控件里硬编码的 TextStyle 不受影响。
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

int _weight(TextStyle style) =>
    (style.fontWeight ?? FontWeight.w400).value;

void main() {
  test('Cupertino 主题：粗体开时各槽位字重提高', () {
    final normal = LifeTokens.cupertino(Brightness.light);
    final bold = LifeTokens.cupertino(Brightness.light, false, true);

    // navTitle 默认已是 w600，粗体不会更重——用它验证「不误伤已够重的槽位」。
    expect(_weight(normal.textTheme.navTitleTextStyle), FontWeight.w600.value);
    expect(_weight(bold.textTheme.navTitleTextStyle), FontWeight.w600.value);
    // 正文与标签默认 lighter，必须被提到 w600。
    expect(_weight(normal.textTheme.textStyle),
        lessThan(FontWeight.w600.value));
    expect(_weight(bold.textTheme.textStyle), FontWeight.w600.value);
    expect(_weight(bold.textTheme.tabLabelTextStyle), FontWeight.w600.value);
  });

  test('Cupertino 主题：默认态不受影响（不误伤 1.0 基线）', () {
    final normal = LifeTokens.cupertino(Brightness.light);
    expect(_weight(normal.textTheme.textStyle),
        _weight(const CupertinoThemeData().textTheme.textStyle));
  });

  test('Material 岛：粗体开时字重 +200', () {
    final normal = LifeTokens.materialIsland(Brightness.light);
    final bold = LifeTokens.materialIsland(Brightness.light, false, true);
    expect(_weight(bold.textTheme.bodyMedium!),
        _weight(normal.textTheme.bodyMedium!) + 200);
  });
}
