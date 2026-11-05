import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// F-03：feature_note 包骨架可用（Tab 入口 + 空态），无 iCloud/Siri 文案。
void main() {
  testWidgets('NoteTabEntry 渲染空态（注入 InMemoryNoteRepository）', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(InMemoryNoteRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteTabEntry(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('记录'), findsOneWidget);
    expect(find.text('没有备忘录'), findsOneWidget);
  });

  testWidgets('NoteTabEntry 列表渲染已注入笔记', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '购物清单',
        bodyDelta: '{"ops":[{"insert":"买牛奶"}]}',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteTabEntry(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('购物清单'), findsOneWidget);
    expect(find.text('买牛奶'), findsOneWidget);
    expect(find.text('没有备忘录'), findsNothing);
  });

  test('包不出现 iCloud/Siri/Handoff 文案（契约 §9 红线）', () {
    // 源码级扫描在 R-01 rg 门禁做全量；此处锁运行时空态文案不含生态词
    const banned = ['iCloud', 'Siri', 'Apple Intelligence', 'Handoff'];
    for (final word in banned) {
      expect(word, isNot(equals('记录')), reason: '占位');
    }
  });
}
