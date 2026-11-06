import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// #391 / #659：备忘录列表行补编辑日期、列表按相对日期分节
/// （矩阵 N12/N25，TC-NOTE-UI-104 / TC-NOTE-UI-119）。
///
/// #658 起行内日期改相对文案（TC-NOTE-UI-117），#659 起节头也改
/// 「今天 / 昨天 / 本周 / 更早」。两者会出现同名文案，所以判据一律按 Key 区分：
/// `note_row_date_*` 是行内日期，`note_group_*` 是节头——不再靠文案正则数节头，
/// 否则一条「今天」会同时被两处算进去。
///
/// 每面都带反向对照：只断「有日期的行有日期」是恒真的，必须同时量
/// 「无编辑时间的行没有」以及「节头关掉时行内日期仍在」。
void main() {
  // 注意 `note_group_by_date` 是设置页勾选框的 Key，前缀匹配会误伤，
  // 这里只认四个真实分桶。
  const groupKeys = <String>[
    'note_group_today',
    'note_group_yesterday',
    'note_group_thisWeek',
    'note_group_earlier',
  ];
  final groupHeader = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        groupKeys.contains((w.key as ValueKey<String>).value),
  );
  final dateLike = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('note_row_date_') &&
        RegExp(
          r'^(今天|昨天|星期[一二三四五六日]|\d{1,2}月\d{1,2}日|\d{4}年\d{1,2}月\d{1,2}日)$',
        ).hasMatch(w.data ?? ''),
  );

  Finder header(String group) => find.byKey(ValueKey('note_group_$group'));

  String rowDate(WidgetTester tester, String id) {
    final finder = find.byKey(ValueKey('note_row_date_$id'));
    expect(finder, findsOneWidget, reason: '行 $id 必须真的带日期才能读文案');
    return tester.widget<Text>(finder).data ?? '';
  }

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
    DateTime? now,
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
          // #658/#659：行内日期与分桶都相对此刻，固定时钟否则断言随运行当天漂移。
          noteClockProvider.overrideWithValue(
            () => now ?? DateTime(2026, 3, 5, 12),
          ),
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
    // #659 节头也写「今天」，所以只按行内日期的 Key 读文案。
    expect(rowDate(tester, 'n1'), '今天');
    // 反向对照：n2 的行没日期，且整屏只有一条行内日期（节头不计入）。
    expect(find.byKey(const ValueKey('note_row_date_n2')), findsNothing);
    expect(dateLike, findsOneWidget);
    // 两行标题都在，证明「n2 无日期」不是整行没渲染。
    expect(find.text('无日期'), findsOneWidget);
  });

  testWidgets('TC-NOTE-UI-119 列表按今天/昨天/本周/更早四个相对桶分节', (tester) async {
    final repo = await seed([
      const Note(
        id: 'n0',
        folderId: 'f1',
        title: '无时间',
        bodyDelta: '{"ops":[{"insert":"c\\n"}]}',
      ),
      Note(
        id: 'n_today',
        folderId: 'f1',
        title: '今天笔记',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        clientUpdatedAt: DateTime(2026, 3, 5, 9).millisecondsSinceEpoch,
      ),
      Note(
        id: 'n_yesterday',
        folderId: 'f1',
        title: '昨天笔记',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        clientUpdatedAt: DateTime(2026, 3, 4, 9).millisecondsSinceEpoch,
      ),
      Note(
        id: 'n_week',
        folderId: 'f1',
        title: '本周笔记',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        clientUpdatedAt: DateTime(2026, 3, 2, 9).millisecondsSinceEpoch,
      ),
      Note(
        id: 'n_earlier',
        folderId: 'f1',
        title: '更早笔记',
        bodyDelta: '{"ops":[{"insert":"b\\n"}]}',
        clientUpdatedAt: DateTime(2023, 7, 30, 9).millisecondsSinceEpoch,
      ),
    ]);
    await pump(tester, repo);

    const order = <String>['today', 'yesterday', 'thisWeek', 'earlier'];
    for (final key in order) {
      expect(header(key), findsOneWidget, reason: '缺相对分桶 $key');
    }
    // 反向对照：恰好四个节头，不能还留年份桶或凭空多一个桶。
    expect(groupHeader, findsNWidgets(4), reason: '只应有四个相对分桶');
    // 文案也按桶落位（只按 Key 判会漏掉「节头写错字」）。
    const labels = <String, String>{
      'today': '今天',
      'yesterday': '昨天',
      'thisWeek': '本周',
      'earlier': '更早',
    };
    for (final entry in labels.entries) {
      expect(
        find.descendant(
          of: header(entry.key),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
        reason: '桶 ${entry.key} 的节头应写「${entry.value}」',
      );
    }
    // 桶序：今天 < 昨天 < 本周 < 更早；每条笔记都在自己桶之下。
    final dy = <String, double>{
      for (final key in order) key: tester.getTopLeft(header(key)).dy,
    };
    for (var i = 0; i + 1 < order.length; i++) {
      expect(
        dy[order[i]]!,
        lessThan(dy[order[i + 1]]!),
        reason: '${order[i]} 桶必须排在 ${order[i + 1]} 桶之前',
      );
    }
    expect(
      tester.getTopLeft(find.text('今天笔记')).dy,
      greaterThan(dy['today']!),
    );
    expect(
      tester.getTopLeft(find.text('昨天笔记')).dy,
      greaterThan(dy['yesterday']!),
    );
    expect(
      tester.getTopLeft(find.text('本周笔记')).dy,
      greaterThan(dy['thisWeek']!),
    );
    expect(
      tester.getTopLeft(find.text('更早笔记')).dy,
      greaterThan(dy['earlier']!),
    );
    // 无编辑时间的笔记排在所有桶之后，且不给自己摆一个 1970 假节头。
    expect(
      tester.getTopLeft(find.text('无时间')).dy,
      greaterThan(tester.getTopLeft(find.text('更早笔记')).dy),
    );
    expect(find.byKey(const ValueKey('note_group_1970')), findsNothing);
    // 旧口径彻底退场：不能再有「2026 年」这类按自然年的节头。
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d{4} 年$').hasMatch(w.data ?? ''),
      ),
      findsNothing,
    );
  });

  testWidgets('同一条笔记随时钟前移从「今天」桶挪到「昨天」桶', (tester) async {
    final repo = await seed([
      Note(
        id: 'n1',
        folderId: 'f1',
        title: '跟着时钟走',
        bodyDelta: '{"ops":[{"insert":"a\\n"}]}',
        clientUpdatedAt: DateTime(2026, 3, 5, 9).millisecondsSinceEpoch,
      ),
    ]);
    await pump(tester, repo, now: DateTime(2026, 3, 5, 12));
    expect(header('today'), findsOneWidget);
    expect(header('yesterday'), findsNothing);
    expect(rowDate(tester, 'n1'), '今天');

    await pump(tester, repo, now: DateTime(2026, 3, 6, 12));
    expect(header('yesterday'), findsOneWidget);
    expect(header('today'), findsNothing);
    expect(rowDate(tester, 'n1'), '昨天');
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

    expect(groupHeader, findsNothing);
    expect(rowDate(tester, 'n2026'), '今天');
    expect(rowDate(tester, 'n2023'), '2023年7月30日');
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
    expect(groupHeader, findsNothing);
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
    expect(groupHeader, findsOneWidget);
  });
}

class _FixedSortNotifier extends NoteSettingsNotifier {
  _FixedSortNotifier(this._sortMode);

  final NoteSortMode _sortMode;

  @override
  NoteSettings build() => NoteSettings(sortMode: _sortMode);
}
