import 'package:app_ui/app_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Epic #126 / B2：设置行收编后的两态（普通行 / 开关行）。
///
/// 这两条同时把「迁移不改观感」的关键点钉住：标题 16、副标题 12、整行可点、
/// 开关点击即切换（与迁移前 `_SwitchRow` 的 GestureDetector 语义一致）。
void main() {
  Widget host(Widget child) => CupertinoApp(
    home: CupertinoPageScaffold(child: Center(child: child)),
  );

  testWidgets('普通行：标题+副标题+尾部，点击触发回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        LifeSettingsRow(
          title: '默认日历',
          subtitle: '新建日程落到这本',
          trailing: const Text('日历'),
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('默认日历'), findsOneWidget);
    expect(find.text('新建日程落到这本'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);

    final titleStyle = tester.widget<Text>(find.text('默认日历')).style!;
    expect(titleStyle.fontSize, 16, reason: '迁移前后标题字号必须一致');
    final subStyle = tester.widget<Text>(find.text('新建日程落到这本')).style!;
    expect(subStyle.fontSize, 12, reason: '副标题 12');

    await tester.tap(find.text('默认日历'));
    expect(taps, 1);
  });

  testWidgets('开关行：整行可点即切换，且开关本身也在', (tester) async {
    var value = false;
    await tester.pumpWidget(
      host(
        LifeSwitchRow(
          title: '全天提醒时点',
          value: value,
          onChanged: (v) => value = v,
        ),
      ),
    );

    expect(find.byType(CupertinoSwitch), findsOneWidget);

    await tester.tap(find.text('全天提醒时点'));
    expect(value, isTrue, reason: '点标题（整行）应当切换，与迁移前的 GestureDetector 一致');
  });

  testWidgets('开关行的开关不参与收缩（窄屏标题不折行）', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      host(LifeSwitchRow(title: '全天提醒时点', value: true, onChanged: (_) {})),
    );

    // 开关外层不得再包 Flexible（否则会与标题列平分宽度）
    final flexibleAncestors = find.ancestor(
      of: find.byType(CupertinoSwitch),
      matching: find.byType(Flexible),
    );
    expect(flexibleAncestors, findsNothing);

    final titleWidth = tester.getSize(find.text('全天提醒时点')).width;
    final switchWidth = tester.getSize(find.byType(CupertinoSwitch)).width;
    expect(
      titleWidth,
      greaterThan(switchWidth),
      reason: '标题列应拿到剩余宽度，而不是和开关平分',
    );
  });

  testWidgets('divider=false 时不画分隔线（最后一行用）', (tester) async {
    await tester.pumpWidget(
      host(const LifeSettingsRow(title: '关于', divider: false)),
    );
    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.decoration, isNull);
  });
}
