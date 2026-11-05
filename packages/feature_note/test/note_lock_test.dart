// TC-NOTE-UI-110 / TC-NOTE-KR-107（#395）：锁定备忘录必须**真的加密**。
//
// 旧契约（本测试此前写的样子）是不安全的：锁定只写 `locked: true`，正文仍是明文
// JSON，解锁口令只要非空就算通过。这里按矩阵 N18「降级：客户端 AES-GCM」重写。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _delta = '{"ops":[{"insert":"秘密正文\\n"}]}';
const _pass = '1234';

void main() {
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester tester, InMemoryNoteRepository repo) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(420, 900)
      ..devicePixelRatio = 1.0;
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
  }

  testWidgets('TC-NOTE-KR-107 锁定后库里是密文，列表不显示明文', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(
      const Note(id: 'n1', folderId: 'f1', title: '日记', bodyDelta: _delta),
    );
    await pump(tester, repo);

    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note_editor_lock')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note_lock_password')),
      _pass,
    );
    await tester.tap(find.byKey(const ValueKey('note_lock_confirm')));
    await tester.pumpAndSettle();

    final locked = (await repo.watchNotes().first).single;
    expect(locked.locked, isTrue);
    expect(NoteLockCodec.isSealed(locked.bodyDelta), isTrue,
        reason: '锁定必须落密文；此前这里还是明文 JSON');
    expect(locked.bodyDelta.contains('秘密正文'), isFalse,
        reason: '直接读库不得看到正文（本 Issue 的核心）');
    expect(locked.bodyText, isEmpty, reason: '锁定的内容不参与搜索索引');
    expect(find.text('已锁定'), findsOneWidget);
    expect(find.textContaining('秘密正文'), findsNothing);
  });

  testWidgets('TC-NOTE-KR-107 密码错误打不开（不能只要非空就通过）', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(Note(
      id: 'n1',
      folderId: 'f1',
      title: '日记',
      bodyDelta: NoteLockCodec.seal(_delta, _pass),
      locked: true,
    ));
    await pump(tester, repo);

    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note_unlock_password')),
      'wrong',
    );
    await tester.tap(find.byKey(const ValueKey('note_unlock_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('编辑备忘录'), findsNothing, reason: '密码错误不得进入编辑器');
    final still = (await repo.watchNotes().first).single;
    expect(NoteLockCodec.isSealed(still.bodyDelta), isTrue);
  });

  testWidgets('TC-NOTE-KR-107 正确密码可解锁编辑，保存后仍是密文', (tester) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    await repo.upsertNote(Note(
      id: 'n1',
      folderId: 'f1',
      title: '日记',
      bodyDelta: NoteLockCodec.seal(_delta, _pass),
      locked: true,
    ));
    await pump(tester, repo);
    expect(find.text('已锁定'), findsOneWidget);

    await tester.tap(find.text('日记'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note_unlock_password')),
      _pass,
    );
    await tester.tap(find.byKey(const ValueKey('note_unlock_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('编辑备忘录'), findsOneWidget);
    // 编辑器正文是 Quill（RichText），`find.textContaining` 抓不到；
    // 改用「保存后能解密回原文」来证明解锁确实拿到了明文。

    await tester.enterText(
      find.byKey(const ValueKey('note_editor_title')),
      '已解锁',
    );
    // #390：不再有「保存」按钮——输入后等去抖窗口过去即自动落库
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final saved = (await repo.watchNotes().first).single;
    expect(saved.title, '已解锁');
    expect(saved.locked, isTrue, reason: '保存不应把备忘录解锁');
    expect(NoteLockCodec.isSealed(saved.bodyDelta), isTrue,
        reason: '已解锁状态下保存必须**重新加密**，否则一保存就退回明文');
    expect(saved.bodyDelta.contains('秘密正文'), isFalse);
    expect(NoteLockCodec.open(saved.bodyDelta, _pass), contains('秘密正文'),
        reason: '重新加密的仍是解锁后的正文——说明解锁确实解开了密文');
  });
}
