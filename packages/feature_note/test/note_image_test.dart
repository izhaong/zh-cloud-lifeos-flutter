import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-107：选图后把本地路径 embed 进 Delta（F-09）。
/// 不引入 flutter_quill_extensions；选图走可注入端口（测试不触盘、不打网络）。
void main() {
  testWidgets('插入图片写入 noteImage embed 并保存', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          noteImagePickerProvider.overrideWithValue(
            () async => '/tmp/lifeos-pic.png',
          ),
        ],
        child: const MaterialApp(
          home: NoteEditorPage(folderId: 'f1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note_editor_image')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note_editor_save')));
    await tester.pumpAndSettle();

    final saved = (await repo.watchNotes().first).single;
    expect(saved.bodyDelta, contains('"noteImage"'));
    expect(saved.bodyDelta, contains('/tmp/lifeos-pic.png'));
  });
}
