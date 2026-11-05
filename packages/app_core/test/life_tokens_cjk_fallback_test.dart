import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// #195：Web（CanvasKit）不读系统字体，主题文本必须带随包 CJK 回退字体。
void main() {
  test('Cupertino 主题各档文本都带 Noto Sans SC 回退', () {
    for (final brightness in Brightness.values) {
      final t = LifeTokens.cupertino(brightness).textTheme;
      final styles = <String, TextStyle>{
        'textStyle': t.textStyle,
        'actionTextStyle': t.actionTextStyle,
        'actionSmallTextStyle': t.actionSmallTextStyle,
        'tabLabelTextStyle': t.tabLabelTextStyle,
        'navTitleTextStyle': t.navTitleTextStyle,
        'navLargeTitleTextStyle': t.navLargeTitleTextStyle,
        'navActionTextStyle': t.navActionTextStyle,
        'pickerTextStyle': t.pickerTextStyle,
        'dateTimePickerTextStyle': t.dateTimePickerTextStyle,
      };
      for (final entry in styles.entries) {
        expect(
          entry.value.fontFamilyFallback,
          contains('Noto Sans SC'),
          reason: '$brightness ${entry.key} 缺 CJK 回退',
        );
      }
    }
  });

  test('Material 岛同样带 CJK 回退', () {
    final t = LifeTokens.materialIsland().textTheme;
    expect(t.bodyMedium?.fontFamilyFallback, contains('Noto Sans SC'));
  });
}
