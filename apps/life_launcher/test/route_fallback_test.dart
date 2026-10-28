import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_launcher/router/life_router.dart';
import 'package:life_launcher/shell/route_not_found_page.dart';

/// parity#187：`#/task` 深链可进任务；未知路由给中文 Cupertino 兜底，
/// 且不得回显 `GoException` 之类的内部字符串。
void main() {
  group('lifeRedirect', () {
    test('/task 与 /tasks 都进任务分支', () {
      expect(lifeRedirect('/task', ['task']), '/');
      expect(lifeRedirect('/tasks', ['task']), '/');
    });

    test('旧 /tasks/list/<id> 迁到壳内 /list/<id>', () {
      expect(lifeRedirect('/tasks/list/smart.today', ['task']), '/list/smart.today');
    });

    test('冷启动 / 且任务未固定 → 首个固定分支', () {
      expect(lifeRedirect('/', ['calendar', 'note']), '/calendar');
      expect(lifeRedirect('/', []), '/more');
    });

    test('未知路径不重定向（交给 errorBuilder）', () {
      expect(lifeRedirect('/nope', ['task']), isNull);
    });
  });

  testWidgets('兜底页是中文 Cupertino 且不泄漏内部异常', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: RouteNotFoundPage(onHome: () => tapped = true),
      ),
    );

    expect(find.text('页面不存在'), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);
    expect(find.textContaining('no routes'), findsNothing);
    expect(find.text('Page Not Found'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('route_not_found_home')));
    expect(tapped, isTrue);
  });
}
