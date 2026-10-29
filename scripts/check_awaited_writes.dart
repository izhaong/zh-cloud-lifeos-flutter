// 守卫（#433）：测试里的**异步仓储写操作必须 await**。
//
// 由来：`grocery_smart_drift_test` 里 `repo.upsertList(...)` 没 await —— tearDown 随即
// `db.close()`，挂起的 insert 撞上已关闭的 DB，抛 `CouldNotRollBackException`。
// 该异常只在**并行**跑 `melos run verify` 时稳定出现，单包单跑永远绿，所以极难定位。
//
// 同时拦下半同类：`expect(() => asyncFn(), throwsX)` —— 异步抛错不会被这个写法捕获，
// 断言等于「假绿」。应改用 `await expectLater(asyncFn(), throwsA(...))`。
//
// 用法：
//   dart run scripts/check_awaited_writes.dart            # 检查
//   dart run scripts/check_awaited_writes.dart --selftest # 自检
import 'dart:io';

/// 被检查的对象名（仓储变量命名约定）。
const _receiverPattern = r'(?:repo|_repo|repository|_repository|port|_port)';

/// 视为「已正确处理」的前缀。
const _awaitedPrefix = r'(?:await\s+|return\s+|=\s*await\s+)';

/// 只扫测试目录。
final _testDirs = <String>['packages', 'apps'];

int main(List<String> args) {
  if (args.contains('--selftest')) {
    return _selftest();
  }
  final violations = <String>[];
  for (final root in _testDirs) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (!file.path.contains('/test/')) continue;
      violations.addAll(_scan(file));
    }
  }
  if (violations.isEmpty) {
    print('OK  测试里的异步写操作都 await 了（也未见 expect(() => asyncFn(), throwsX) 假绿）');
    return 0;
  }
  print('FAIL  发现 ${violations.length} 处：');
  for (final v in violations) {
    print('  RED   $v');
  }
  return 1;
}

/// 已知**异步**的仓储写方法（同步方法如 debugAgeDeletion / disposeDayRolloverWatch
/// 不在此列——给它们加 await 会编译不过，守卫必须先排除，否则会被当噪音忽略）。
final _asyncWrites =
    RegExp(r'\.(upsert\w*|delete\w*|softDelete|restore|applyAll|setVisibility|move\w*)\(');

final _bareCall = RegExp('^\\s*$_receiverPattern\\.[a-zA-Z]\\w*\\(');
final _okCall = RegExp('^\\s*$_awaitedPrefix$_receiverPattern\\.[a-zA-Z]\\w*\\(');
/// 多行写法：`expect(` 与 `() =>` 与 `repo.xxx(` 分在三行里（负向验证抓到的漏网形态）。
final _falseGreenMultiline = RegExp(
    r'expect\(\s*\n\s*\(\s*\)\s*=>\s*(?:\n\s*)?' + _receiverPattern + r'\.');

final _falseGreen =
    RegExp(r'expect\(\s*\(\s*\)\s*=>\s*' + _receiverPattern + r'\.[a-zA-Z]\w*\(');

List<String> _scan(File file) {
  final out = <String>[];
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNo = i + 1;
    if (_bareCall.hasMatch(line) == false || !_asyncWrites.hasMatch(line)) {
      // 只在 `expect(` 起始行判定，且跳过注释——否则会把 test('…') 或说明性注释也报红。
      if (line.trimLeft().startsWith('//')) continue;
      final window = lines
          .sublist(i, i + 3 > lines.length ? lines.length : i + 3)
          .join('\n');
      final looksLikeExpect = line.trimLeft().startsWith('expect(');
      if (looksLikeExpect &&
          (_falseGreen.hasMatch(line) || _falseGreenMultiline.hasMatch(window))) {
        out.add('${file.path}:$lineNo `expect(() => 异步调用, throwsX)` 抓不到异步抛错'
            '（改用 await expectLater(...)）：${line.trim()}');
      }
      continue;
    }
    if (_okCall.hasMatch(line)) continue;
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('final ') || trimmed.startsWith('var ')) continue;

    // 多行上下文：`await expectLater(` / `Future.wait([` / `=>` 都可能出现在**上一行**，
    // 当前行只是被包裹的调用。取前 3 行拼接判断。
    final context = lines
        .sublist(i - 16 < 0 ? 0 : i - 16, i + 1)
        .map((l) => l.trim())
        .join(' ');
    // 注意：这里**不能**把裸 `=>` 当包裹证据——`expect(() => ...)` 恰好以 `=>` 结尾，
    // 会把它误判成「已处理」，守卫就形同虚设（本条是负向验证抓出来的）。
    final wrapped = RegExp(
      r'await\s+expectLater\(|Future\.wait\(\[|await\s+Future\.wait\(',
    ).hasMatch(context);
    final wrappedByArrow = RegExp(r'async\s*=>\s*' + _receiverPattern + r'\.')
        .hasMatch(context);
    if (wrapped || wrappedByArrow) continue;
    if (context.contains('listen(')) continue;
    // `unawaited(...)` 是**显式**决定不等待（回调里没法 await 的场景）；
    // 与「漏写 await」不同，不报。
    if (context.contains('unawaited(')) continue;

    out.add('${file.path}:$lineNo 未 await 的仓储调用：${line.trim()}');
  }
  return out;
}

/// 自检：用内联样例验证判据（红/绿各一组），确保守卫本身不会「静默通过」。
int _selftest() {
  final tmp = Directory.systemTemp.createTempSync('awd_selftest');
  try {
    final bad = File('${tmp.path}/bad_test.dart')
      ..writeAsStringSync('''
void main() {
  test('x', () {
    repo.upsertList(const ReminderList(id: 'a'));
  });
  test('y', () {
    expect(() => repo.upsertList(const ReminderList(id: 'b')), throwsArgumentError);
  });
}
''');
    final good = File('${tmp.path}/good_test.dart')
      ..writeAsStringSync('''
void main() {
  test('x', () async {
    await repo.upsertList(const ReminderList(id: 'a'));
    await expectLater(
      repo.upsertList(const ReminderList(id: 'b')),
      throwsArgumentError,
    );
  });
}
''');
    final badHits = _scan(bad);
    final goodHits = _scan(good);
    if (badHits.length != 2) {
      print('SELFTEST FAIL：坏样例应报 2 条，实际 ${badHits.length} 条\n$badHits');
      return 1;
    }
    if (goodHits.isNotEmpty) {
      print('SELFTEST FAIL：好样例不应报红，实际 $goodHits');
      return 1;
    }
    print('SELFTEST OK（未 await 与假绿各报一条；await + expectLater 不报）');
    return 0;
  } finally {
    tmp.deleteSync(recursive: true);
  }
}
