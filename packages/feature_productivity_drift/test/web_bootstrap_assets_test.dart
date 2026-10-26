import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Web 启动资源门禁（Issue #84）。
///
/// 缺任一份资源时，`WasmDatabase.open` 在浏览器里解析不到模块，组合根开库失败，
/// 表现正是「纯白屏 + 一条 Uncaught Error」——本 Issue 的原始缺陷形态。
/// 因此这里量的是文件系统的独立事实，而不是源码里有没有某句注释。
Directory? _resolveLauncherWebDir() {
  var dir = Directory.current.absolute;
  for (var depth = 0; depth < 8; depth++) {
    final candidate = Directory(
      '${dir.path}${Platform.pathSeparator}apps'
      '${Platform.pathSeparator}life_launcher'
      '${Platform.pathSeparator}web',
    );
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

void main() {
  group('Web 启动资源', () {
    final webDir = _resolveLauncherWebDir();

    test('life_launcher/web 目录可从测试工作目录定位', () {
      expect(
        webDir,
        isNotNull,
        reason: '未找到 apps/life_launcher/web（cwd=${Directory.current.path}）',
      );
    });

    test('sqlite3.wasm 存在且是合法 wasm 模块', () {
      final file = File('${webDir!.path}/sqlite3.wasm');
      expect(file.existsSync(), isTrue, reason: '缺少 ${file.path}');

      final bytes = file.readAsBytesSync();
      // wasm 二进制魔数：\0asm，其后 4 字节为版本号。
      expect(bytes.length, greaterThan(100000), reason: 'wasm 体积异常，疑似占位文件');
      expect(bytes.sublist(0, 4), <int>[0, 0x61, 0x73, 0x6d]);
      expect(bytes.sublist(4, 8), <int>[1, 0, 0, 0]);
    });

    test('drift_worker.js 存在且是 dart2js 构建产物', () {
      final file = File('${webDir!.path}/drift_worker.js');
      expect(file.existsSync(), isTrue, reason: '缺少 ${file.path}');

      final text = file.readAsStringSync();
      expect(text.length, greaterThan(50000), reason: 'worker 体积异常，疑似占位文件');
      expect(
        text.startsWith('(function dartProgram'),
        isTrue,
        reason: 'drift_worker.js 不是 dart2js 预构建产物，无法作为 worker 加载',
      );
    });
  });
}
