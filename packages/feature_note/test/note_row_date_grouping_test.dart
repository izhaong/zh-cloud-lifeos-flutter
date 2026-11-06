import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #391：备忘录列表行补编辑日期、列表按年分组（矩阵 N12/N25，TC-NOTE-UI-104 相邻面）。
///
/// 每面都带反向对照：只断「有日期的行有日期」是恒真的，必须同时量「无编辑时间的行没有」，
/// 以及「节头关掉时行内日期仍在」。
/// #658 起行内日期改相对文案（TC-NOTE-UI-117），本文件固定 noteClockProvider
/// 到 2026-03-05，免得断言随运行当天漂移；分组面本身不变。
void main() {
  final dateLike = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        RegExp(
          r'^(今天|昨天|星期[一二三四五六日]|\d{1,2}月\d{1,2}日|\d{4}年\d{1,2}月\d{1,2}日)$',
        ).hasMatch(w.data ?? ''),
  );
  final yearHeader = find.byWidgetPredicate(
    (w) => w is Text && RegExp(r'^\d{4} 年$').hasMatch(w.data ?? ''),
  );

  Future<InMemoryNoteRepository> seed(List<Note> notes) async {
    final repo = InMemoryNoteRepository();
    await repo.upsertFolder(const NoteFolder(id: 'f1', name: '工作'));
    for (final note in notes) {
      await repo.upsertNote(note);
    }
    return repo;
  }

  Future<void> pump(
    WidgetTester tester,
    NoteRepository repo, {
    NoteSortMode? sortMode,
  }) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          // #658：行内日期是相对文案，固定时钟否则断言随运行当天漂移。
          noteClockProvider.overrideWithValue(() => DateTime(2026, 3, 5, 12)),
          if (sortMode != null)
            noteSettingsProvider.overrideWith(
              () => _FixedSortNotifier(sortMode),
            ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [GlobalCupertinoLocalizations.delegate],
          home: NoteScaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('行内显示编辑日期；无编辑时间的行不显示日期', (tester) async {
    final repo = await seed([
      Note(
        id: 'n1',
        folderId: 'f1',
        title: '有日期',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        clientUpdatedAt: DateTime(2026, 3, 5).millisecondsSinceEpoch,
      ),
      const Note(
        id: 'n2',
        folderId: 'f1',
        title: '无日期',
        bodyDelta: '{"ops":[{"insert":"b\\n"}]}',
      ),
    ]);
    await pump(tester, repo);

    // #658：固定时钟 2026-03-05 ⇒ 这行写「今天」，不再是 2026/3/5。
    expect(find.text('今天'), findsOneWidget);
    expect(find.byKey(const ValueKey('note_row_date_n1')), findsOneWidget);
    // 反向对照：n2 的行没日期，且整屏只有一条日期文案（不是两条都在、只是文案不同）。
    expect(find.byKey(const ValueKey('note_row_date_n2')), findsNothing);
    expect(dateLike, findsOneWidget);
    // 两行标题都在，证明「n2 无日期」不是整行没渲染。
    expect(find.text('无日期'), findsOneWidget);
  });

  testWidgets('列表按年分组：新桶在前，笔记落在自己的年份下', (tester) async {
    final repo = await seed([
      const Note(
        id: 'n0',
        folderId: 'f1',
        title: '无时间',
        bodyDelta: '{"ops":[{"insert":"c\\n"}]}',
      ),
      Note(
        id: 'n2026',
        folderId: 'f1',
        title: '今年',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        clientUpdatedAt: DateTime(2026, 3, 5).millisecondsSinceEpoch,
      ),
      Note(
        id: 'n2023',
        folderId: 'f1',
        title: '去年',
        bodyDelta: '{"ops":[{"insert":"b\\n"}]}',
        clientUpdatedAt: DateTime(2023, 7, 30).millisecondsSinceEpoch,
      ),
    ]);
    await pump(tester, repo);

    expect(find.byKey(const ValueKey('note_group_2026')), findsOneWidget);
    expect(find.byKey(const ValueKey('note_group_2023')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('2026 年')).dy,
      lessThan(tester.getTopLeft(find.text('2023 年')).dy),
    );
    expect(
      tester.getTopLeft(find.text('2026 年')).dy,
      lessThan(tester.getTopLeft(find.text('今年')).dy),
    );
    expect(
      tester.getTopLeft(find.text('去年')).dy,
      greaterThan(tester.getTopLeft(find.text('2023 年')).dy),
    );
    // 无编辑时间的笔记排在所有年桶之后，且不给自己摆一个「1970 年」假节头。
    expect(
      tester.getTopLeft(find.text('无时间')).dy,
      greaterThan(tester.getTopLeft(find.text('去年')).dy),
    );
    expect(find.byKey(const ValueKey('note_group_1970')), findsNothing);
    expect(yearHeader, findsNWidgets(2));
  });

  testWidgets('按标题排序时不按日期分组，但行内日期仍在', (tester) async {
    final repo = await seed([
      Note(
        id: 'n2026',
        folderId: 'f1',
        title: 'Beta',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        clientUpdatedAt: DateTime(2026, 3, 5).millisecondsSinceEpoch,
      ),
      Note(
        id: 'n2023',
        folderId: 'f1',
        title: 'Alpha',
        bodyDelta: '{"ops":[{"insert":"b\\n"}]}',
        clientUpdatedAt: DateTime(2023, 7, 30).millisecondsSinceEpoch,
      ),
    ]);
    await pump(tester, repo, sortMode: NoteSortMode.title);

    expect(yearHeader, findsNothing);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('2023年7月30日'), findsOneWidget);
    // 标题档确实按标题排（分组关掉不该顺带改掉排序）。
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Beta')).dy),
    );
  });

  testWidgets('笔记都无编辑时间时列表保持平铺（golden 夹具即此形态）', (tester) async {
    final repo = await seed([
      const Note(
        id: 'n1',
        folderId: 'f1',
        title: '周会纪要',
        bodyDelta: '{"ops":[{"insert":"1. 进度对齐\\n"}]}',
      ),
      const Note(
        id: 'n2',
        folderId: 'f1',
        title: '读书笔记',
        bodyDelta: '{"ops":[{"insert":"第二章\\n"}]}',
      ),
    ]);
    await pump(tester, repo);

    expect(dateLike, findsNothing);
    expect(yearHeader, findsNothing);
    expect(find.text('周会纪要'), findsOneWidget);
    expect(find.text('读书笔记'), findsOneWidget);
    // 正向对照：同一条判据在带时间戳的夹具上必须数得到（否则这两条 findsNothing 是恒真）。
    final datedRepo = await seed([
      Note(
        id: 'n1',
        folderId: 'f1',
        title: '周会纪要',
        bodyDelta: '{"ops":[{"insert":"1. 进度对齐\\n"}]}',
        clientUpdatedAt: DateTime(2026, 3, 5).millisecondsSinceEpoch,
      ),
    ]);
    await pump(tester, datedRepo);
    expect(dateLike, findsOneWidget);
    expect(yearHeader, findsOneWidget);
  });
}

class _FixedSortNotifier extends NoteSettingsNotifier {
  _FixedSortNotifier(this._sortMode);

  final NoteSortMode _sortMode;

  @override
  NoteSettings build() => NoteSettings(sortMode: _sortMode);
}
