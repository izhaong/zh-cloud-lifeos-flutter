// #575：显示 → 前往。feature_task 把清单发布给壳菜单；菜单点击只写 id，
// 页面消费后切到该清单（壳不持有选择态）。
import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:feature_task/feature_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/life_test_app.dart';

void main() {
  testWidgets('发布清单快照并消费「前往」请求（#575）', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final repo = InMemoryReminderRepository(seedSampleData: false);
    await repo.upsertList(const ReminderList(id: 'list.a', title: '工作'));
    final goToLists = ValueNotifier<List<LifeMenuGoToTarget>>(const []);
    final goToRequest = ValueNotifier<String?>(null);
    String? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          lifeMenuGoToListsProvider.overrideWithValue(goToLists),
          lifeMenuGoToRequestProvider.overrideWithValue(goToRequest),
        ],
        child: lifeTestHost(
          TaskScaffold(
            openListId: 'list.a',
            onOpenList: (id) => opened = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      goToLists.value.where((e) => e.id == 'list.a').map((e) => e.title),
      contains('工作'),
      reason: '清单要发布给壳的「前往」子菜单',
    );

    goToRequest.value = 'smart.today';
    await tester.pumpAndSettle();
    expect(opened, 'smart.today', reason: '页面要消费前往请求并切列表');
    expect(goToRequest.value, isNull, reason: '命令消费后清零，避免重复切换');
  });
}
