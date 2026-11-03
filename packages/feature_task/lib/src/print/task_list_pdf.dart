import 'dart:io';
import 'dart:typed_data';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 尝试加载系统 CJK 字体（macOS 自带）；不可用时回退 PDF 默认西文字体。
pw.Font? loadSystemCjkFont() {
  const candidates = [
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      return pw.Font.ttf(ByteData.sublistView(file.readAsBytesSync()));
    } catch (_) {
      // 字体解析失败不阻断打印，回退默认字体。
    }
  }
  return null;
}

/// #572：把当前列表导出为 PDF（标题 + 未完成条目），供系统打印面板使用。
Future<Uint8List> buildTaskListPdf({
  required String listTitle,
  required List<ReminderItem> items,
  pw.Font? font,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: font == null
          ? null
          : pw.ThemeData.withFont(base: font, bold: font),
      build: (context) => [
        pw.Header(level: 0, text: listTitle),
        pw.SizedBox(height: 8),
        for (final item in items) pw.Bullet(text: _line(item)),
      ],
    ),
  );
  return doc.save();
}

String _line(ReminderItem item) {
  final due = item.dueAt;
  if (due == null) return item.title;
  final ymd = '${due.year}年${due.month}月${due.day}日';
  final hh = due.hour.toString().padLeft(2, '0');
  final mm = due.minute.toString().padLeft(2, '0');
  final time = (due.hour == 0 && due.minute == 0) ? '' : ' $hh:$mm';
  return '${item.title}  ·  $ymd$time';
}
