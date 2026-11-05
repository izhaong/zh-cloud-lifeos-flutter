import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-105：搜索标题与 bodyText，空结果显示「无匹配结果」（F-07）。
void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('搜正文命中；无关词显示无匹配结果', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '购物',
        bodyDelta: '{"ops":[{"insert":"牛奶\\n"}]}',
      ),
    );
    await repo.upsertNote(
      const Note(
        id: 'n2',
        folderId: 'f1',
        title: '烘焙',
        bodyDelta: '{"ops":[{"insert":"面包\\n"}]}',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 搜正文命中
    await tester.enterText(
      find.byKey(const ValueKey('note_search_field')),
      '牛奶',
    );
    await tester.pumpAndSettle();
    expect(find.text('购物'), findsOneWidget);
    expect(find.text('烘焙'), findsNothing);

    // 无关词 → 空结果文案
    await tester.enterText(
      find.byKey(const ValueKey('note_search_field')),
      '找不到',
    );
    await tester.pumpAndSettle();
    expect(find.text('无匹配结果'), findsOneWidget);
    expect(find.text('购物'), findsNothing);

    // 清空 → 恢复全部
    await tester.enterText(find.byKey(const ValueKey('note_search_field')), '');
    await tester.pumpAndSettle();
    expect(find.text('购物'), findsOneWidget);
    expect(find.text('烘焙'), findsOneWidget);
  });
}
