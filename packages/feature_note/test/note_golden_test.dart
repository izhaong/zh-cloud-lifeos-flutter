import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// note 的两档 golden（#333）。note 的渲染路径**不读挂钟**（`DateTime.now()` 只用于
/// 新建时的 id/时间戳），所以这里不需要注入时钟就能确定——与 task/calendar 不同。
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '周会纪要',
        bodyDelta: '{"ops":[{"insert":"1. 进度对齐\\n2. 风险清单\\n"}]}',
      ),
    );
    await repo.upsertNote(
      const Note(
        id: 'n2',
        folderId: 'f1',
        title: '读书笔记',
        bodyDelta: '{"ops":[{"insert":"第二章：边界条件\\n"}]}',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: NoteScaffold()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('桌面 1280 暗色（golden 基线；同夹具只改明暗）', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpAt(tester, const Size(1280, 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_1280_note_dark.png'),
    );
  });

  testWidgets('iPhone 375（golden 基线）', (tester) async {
    await pumpAt(tester, const Size(375, 812));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/iphone_375_note.png'),
    );
  });

  testWidgets('桌面 1280（golden 基线）', (tester) async {
    await pumpAt(tester, const Size(1280, 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_1280_note.png'),
    );
  });
}
