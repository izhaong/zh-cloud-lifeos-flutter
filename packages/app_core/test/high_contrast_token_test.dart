// 辅助功能对等：Apple「提高对比度」（Increase Contrast）时必须取到高对比档色值。
//
// 改前应红：`LifeTokens` 只按 brightness 取 `color`/`darkColor`，高对比两档从未被取。
//
// 注意 token 选择：不是每个 Apple 动态色四档都互不相同（例：`label` 亮档与
// 高对比档都是纯黑；`secondarySystemGroupedBackground` 亮档两档都是白）。
// 这里只用**实测有差异**的三个：systemGroupedBackground / secondarySystemGroupedBackground / systemRed。
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('亮档 + 提高对比度：scaffold 背景切到 systemGroupedBackground.highContrastColor', () {
    final normal = LifeTokens.materialIsland(Brightness.light);
    final contrast = LifeTokens.materialIsland(Brightness.light, true);

    expect(normal.scaffoldBackgroundColor,
        CupertinoColors.systemGroupedBackground.color);
    expect(contrast.scaffoldBackgroundColor,
        CupertinoColors.systemGroupedBackground.highContrastColor);
    expect(contrast.scaffoldBackgroundColor,
        isNot(normal.scaffoldBackgroundColor));
  });

  test('暗档 + 提高对比度：surface 切到 secondarySystemGroupedBackground.darkHighContrastColor', () {
    final contrast = LifeTokens.materialIsland(Brightness.dark, true);
    expect(contrast.colorScheme.surface,
        CupertinoColors.secondarySystemGroupedBackground.darkHighContrastColor);
    expect(contrast.colorScheme.surface,
        isNot(CupertinoColors.secondarySystemGroupedBackground.darkColor));
  });

  test('错误色跟随高对比', () {
    expect(LifeTokens.materialIsland(Brightness.light, true).colorScheme.error,
        CupertinoColors.systemRed.highContrastColor);
    expect(LifeTokens.materialIsland(Brightness.light).colorScheme.error,
        CupertinoColors.systemRed.color);
  });

  test('Cupertino 根主题也带高对比档', () {
    final normal = LifeTokens.cupertino(Brightness.light);
    final contrast = LifeTokens.cupertino(Brightness.light, true);
    expect(normal.barBackgroundColor, CupertinoColors.systemGroupedBackground);
    expect(contrast.barBackgroundColor,
        CupertinoColors.systemGroupedBackground.highContrastColor);
  });
}
