import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TC-NOTE-UI-112：共享界面输入对方用户 id，选只读/可写；不出现邮件或 iCloud（F-14）。
void main() {
  testWidgets('共享提交到注入端口，口径为用户 id + 可写', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(const Note(
      id: 'n1',
      folderId: 'f1',
      title: '共享我',
      bodyDelta: '{"ops":[{"insert":"x\\n"}]}',
    ));

    String? sharedNote;
    String? sharedUser;
    bool? sharedWritable;
    final fakePort = _FakeSharePort((noteId, userId, writable) {
      sharedNote = noteId;
      sharedUser = userId;
      sharedWritable = writable;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          noteSharePortProvider.overrideWithValue(fakePort),
        ],
        child: MaterialApp(home: NoteEditorPage(folderId: 'f1', note: _note())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note_editor_share')));
    await tester.pumpAndSettle();
    expect(find.textContaining('邮件'), findsNothing);
    expect(find.textContaining('iCloud'), findsNothing);

    await tester.enterText(
        find.byKey(const ValueKey('note_share_user_id')), '42');
    await tester.tap(find.byKey(const ValueKey('note_share_write')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_share_submit')));
    await tester.pumpAndSettle();

    expect(sharedNote, 'n1');
    expect(sharedUser, '42');
    expect(sharedWritable, isTrue);
    expect(find.text('已共享'), findsOneWidget);
  });
}

Note _note() => const Note(
      id: 'n1',
      folderId: 'f1',
      title: '共享我',
      bodyDelta: '{"ops":[{"insert":"x\\n"}]}',
    );

class _FakeSharePort implements NoteSharePort {
  _FakeSharePort(this._onShare);

  final void Function(String noteId, String userId, bool writable) _onShare;

  @override
  Future<void> share({
    required String noteId,
    required String targetUserId,
    required bool writable,
  }) async {
    _onShare(noteId, targetUserId, writable);
  }
}
