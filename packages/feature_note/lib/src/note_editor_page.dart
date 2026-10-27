import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'providers.dart';

/// 记录编辑器（F-05；契约 §5、§8：flutter_quill 11.6.0）。
///
/// 新建/编辑标题与富文本正文；保存写回 [NoteRepository]，正文序列化为
/// Quill Delta JSON（bodyDelta），纯文本与清单计数由仓库归一。
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.note, required this.folderId});

  final Note? note;
  final String folderId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  late final TextEditingController _title;
  late final quill.QuillController _body;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = quill.QuillController(
      document: _loadDocument(widget.note?.bodyDelta),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  quill.Document _loadDocument(String? deltaJson) {
    if (deltaJson == null || deltaJson.trim().isEmpty) {
      return quill.Document();
    }
    try {
      final decoded = jsonDecode(deltaJson);
      if (decoded is Map && decoded['ops'] is List) {
        return quill.Document.fromJson(List<dynamic>.from(decoded['ops'] as List));
      }
    } catch (_) {
      // 锁定密文或损坏内容：不解析，按空文档打开由上层锁定页拦截
    }
    return quill.Document();
  }

  Future<void> _save() async {
    final existing = widget.note;
    final delta = jsonEncode({'ops': _body.document.toDelta().toJson()});
    final note = Note(
      id: existing?.id ??
          'note-${DateTime.now().millisecondsSinceEpoch}',
      folderId: existing?.folderId ?? widget.folderId,
      title: _title.text.trim().isEmpty ? '新建备忘录' : _title.text.trim(),
      bodyDelta: delta,
      pinned: existing?.pinned ?? false,
      locked: existing?.locked ?? false,
      tagNames: existing?.tagNames ?? const [],
      sortOrder: existing?.sortOrder ?? 0,
      revision: (existing?.revision ?? 0) + 1,
      clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(noteRepositoryProvider).upsertNote(note);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? '新建备忘录' : '编辑备忘录'),
        actions: [
          IconButton(
            key: const ValueKey('note_editor_bold'),
            tooltip: '加粗',
            icon: const Icon(Icons.format_bold),
            onPressed: () => _body.formatSelection(quill.Attribute.bold),
          ),
          TextButton(
            key: const ValueKey('note_editor_save'),
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            TextField(
              key: const ValueKey('note_editor_title'),
              controller: _title,
              decoration: const InputDecoration(
                hintText: '标题',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: quill.QuillEditor.basic(
                controller: _body,
                config: const quill.QuillEditorConfig(
                  placeholder: '开始记录…',
                  padding: EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
