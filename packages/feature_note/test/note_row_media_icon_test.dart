import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #666：Apple 备忘录列表行会标出媒体类型。LifeOS 的图片以 `noteImage`
/// embed 存在正文 Delta 里——含图的行要有图片指示，不含图的行（反向对照）
/// 与锁定笔记（正文是密文，不探测）都不该有。
void main() {
  testWidgets('含图片 embed 的行显示图片指示；纯文本与锁定行没有', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(const Note(
      id: 'img',
      folderId: 'f1',
      title: '带图',
      bodyDelta:
          '{"ops":[{"insert":"看图\\n"},{"insert":{"noteImage":{"path":"/tmp/a.png"}}},{"insert":"\\n"}]}',
    ));
    await repo.upsertNote(const Note(
      id: 'txt',
      folderId: 'f1',
      title: '纯文字',
      bodyDelta: '{"ops":[{"insert":"noteImage 只是字面文字\\n"}]}',
    ));
    await repo.upsertNote(const Note(
      id: 'lock',
      folderId: 'f1',
      title: '锁定',
      locked: true,
    ));

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
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

    expect(find.text('带图'), findsOneWidget, reason: '先确认行真渲染了');
    expect(find.byKey(const ValueKey('note_row_media_image_img')), findsOneWidget);
    expect(find.byKey(const ValueKey('note_row_media_image_txt')), findsNothing,
        reason: '正文里出现 noteImage 这个词不等于有图');
    expect(find.byKey(const ValueKey('note_row_media_image_lock')), findsNothing);
  });
}
