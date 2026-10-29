// #390：编辑器边写边存——Apple 备忘录没有「保存」按钮。
//
// 复现口径：**不点任何按钮**，只输入标题与正文，等过去抖窗口后仓库里必须能读回，
// 且控件树里**不存在** `note_editor_save`。
import 'package:feature_note/feature_note.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements NoteRepository {
  final List<Note> notes = [];

  @override
  Stream<List<Note>> watchNotes({String? folderId, String? query}) =>
      Stream.value(List<Note>.unmodifiable(notes));

  @override
  Future<String> upsertNote(Note note) async {
    final i = notes.indexWhere((n) => n.id == note.id);
    if (i >= 0) {
      notes[i] = note;
    } else {
      notes.add(note);
    }
    return note.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<_Repo> _pump(WidgetTester tester, {Note? note}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = _Repo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [noteRepositoryProvider.overrideWithValue(repo)],
      child: CupertinoApp(
        home: NoteEditorPage(note: note, folderId: 'f1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('#390 只输入、不点按钮 → 自动落库（且没有保存按钮）', (tester) async {
    final repo = await _pump(tester);

    expect(find.byKey(const ValueKey('note_editor_save')), findsNothing,
        reason: 'Apple 备忘录没有「保存」按钮，控件必须不存在而不是隐藏');

    await tester.enterText(
      find.byKey(const ValueKey('note_editor_title')),
      '自动保存',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(repo.notes, hasLength(1), reason: '没有中间态：输入即落库');
    expect(repo.notes.single.title, '自动保存');
  });

  testWidgets('#390 二次编辑走同一条记录（不产生重复行）', (tester) async {
    final repo = await _pump(tester);

    await tester.enterText(
      find.byKey(const ValueKey('note_editor_title')),
      '第一次',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(repo.notes, hasLength(1));

    await tester.enterText(
      find.byKey(const ValueKey('note_editor_title')),
      '第二次',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(repo.notes, hasLength(1), reason: '同一编辑器内复用首次拿到的 id');
    expect(repo.notes.single.title, '第二次');
  });

  testWidgets('#390 离开编辑面时 flush 未落库的改动', (tester) async {
    final repo = await _pump(tester);

    await tester.enterText(
      find.byKey(const ValueKey('note_editor_title')),
      '来不及去抖',
    );
    // 不等去抖窗口，立刻卸载编辑面
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repo)],
        child: const CupertinoApp(home: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.notes, hasLength(1), reason: 'dispose 必须 flush，否则静默丢内容');
    expect(repo.notes.single.title, '来不及去抖');
  });
}
