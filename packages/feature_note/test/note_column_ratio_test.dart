import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #687：宽屏列表栏 flex 大于编辑栏。窄屏不出现这两栏。
void main() {
  testWidgets('宽屏列表 flex 大于编辑 flex', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NoteScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    final flexes = tester
        .widgetList<Expanded>(find.byType(Expanded))
        .map((e) => e.flex)
        .toList();
    expect(flexes, containsAll([NoteScaffold.listFlex, NoteScaffold.editorFlex]));
    expect(NoteScaffold.listFlex, greaterThan(NoteScaffold.editorFlex));
  });
}
