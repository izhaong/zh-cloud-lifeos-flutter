// A5/暗色跟随（#371）：记录侧栏的行名称在暗色档必须仍然可读。
//
// 现象：系统切暗色后，文件夹侧栏两行只剩蓝色图标、名称完全不可见；
// 同屏「新建文件夹」等行正常。
//
// 根因（本测试锁定）：`_folderTile` 手拼了
//   CupertinoDynamicColor.withBrightness(color: label.color, darkColor: label.darkColor)
// 却把这个**未解算**的对象直接放进 `TextStyle(color:)`——TextStyle 不像
// `CupertinoListTile` 的内部默认样式那样自动解算，于是暗色档按亮档黑字绘制，
// 黑底黑字 → 看不见。
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:feature_note/feature_note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements NoteRepository {
  _Repo({required this.folders, required this.notes});

  final List<NoteFolder> folders;
  final List<Note> notes;

  @override
  Stream<List<NoteFolder>> watchFolders() => Stream.value(folders);

  @override
  Stream<List<Note>> watchNotes({String? folderId}) => Stream.value(notes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpSidebar(WidgetTester tester,
    {required Brightness brightness}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final repo = _Repo(
    folders: const [
      // 名字必须唯一：侧栏内置「所有备忘录」智能行是蓝色且不可选，
      // 若重名，find.text 会先命中那一行，测到的就不是文件夹行。
      NoteFolder(id: 'f2', name: '工作'),
    ],
    notes: const [],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repo),
      ],
      // 必须用 CupertinoApp：`CupertinoColors.*.resolveFrom` 读的是
      // CupertinoTheme 的亮度，MaterialApp 的 ThemeData.brightness 不参与。
      child: CupertinoApp(
        theme: CupertinoThemeData(brightness: brightness),
        home: const SizedBox(width: 240, child: NoteSidebar()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('暗色档：侧栏文件夹行名称是浅色（可读）', (tester) async {
    await _pumpSidebar(tester, brightness: Brightness.dark);

    final texts = tester.widgetList<Text>(find.text('工作'));
    expect(texts, isNotEmpty, reason: '侧栏应渲染出文件夹名称');
    final color = texts.first.style?.color;
    expect(color, isNotNull, reason: '名称必须有显式颜色（否则会继承默认色，无法判断）');
    expect(color!.computeLuminance(), greaterThan(0.5),
        reason: '暗色档文字必须是浅色；未解算的 CupertinoDynamicColor 会按亮档黑色绘制，'
            '黑底黑字 → 名称不可见（就是本 Issue 的现象）');
  });

  testWidgets('亮色档：同一行是深色（对照组，防止把亮档改坏）', (tester) async {
    await _pumpSidebar(tester, brightness: Brightness.light);

    final color = tester.widgetList<Text>(find.text('工作')).first.style?.color;
    expect(color, isNotNull);
    expect(color!.computeLuminance(), lessThan(0.5),
        reason: '亮色档文字必须是深色');
  });
}
