import 'package:app_ui/app_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// #279 / Epic #126 A3：分区头两态（静态 / 可折叠）与键位保持。
void main() {
  Widget host(Widget child) => CupertinoApp(
    home: CupertinoPageScaffold(child: Center(child: child)),
  );

  testWidgets('静态形态：只渲染标题，不带 chevron', (tester) async {
    await tester.pumpWidget(
      host(
        const LifeSectionHeader(
          title: '订阅',
          sectionKey: ValueKey('header_sub'),
        ),
      ),
    );
    expect(find.text('订阅'), findsOneWidget);
    expect(find.byKey(const ValueKey('header_sub')), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_down), findsNothing);
    expect(find.byIcon(CupertinoIcons.chevron_up), findsNothing);
  });

  testWidgets('可折叠形态：chevron 随状态转向、点击触发回调、可带计数', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(
      host(
        LifeSectionHeader(
          title: '今天',
          count: 3,
          collapsed: false,
          sectionKey: const ValueKey('section_今天'),
          onToggle: () => toggles++,
        ),
      ),
    );
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_up), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('section_今天')));
    expect(toggles, 1);

    await tester.pumpWidget(
      host(
        LifeSectionHeader(
          title: '今天',
          count: 3,
          collapsed: true,
          sectionKey: const ValueKey('section_今天'),
          onToggle: () {},
        ),
      ),
    );
    expect(find.byIcon(CupertinoIcons.chevron_down), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_up), findsNothing);
  });
}
