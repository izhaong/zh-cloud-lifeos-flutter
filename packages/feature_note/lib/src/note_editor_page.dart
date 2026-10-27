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
  late final TextEditingController _tagInput;
  late final quill.QuillController _body;
  late final List<String> _tags = [...?widget.note?.tagNames];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _tagInput = TextEditingController();
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
    if (existing != null && existing.locked) {
      return; // 锁定笔记不允许用编辑器覆盖密文（解锁归 F-12）
    }
    final delta = jsonEncode({'ops': _body.document.toDelta().toJson()});
    final note = Note(
      id: existing?.id ??
          'note-${DateTime.now().millisecondsSinceEpoch}',
      folderId: existing?.folderId ?? widget.folderId,
      title: _title.text.trim().isEmpty ? '新建备忘录' : _title.text.trim(),
      bodyDelta: delta,
      pinned: existing?.pinned ?? false,
      locked: existing?.locked ?? false,
      tagNames: List<String>.unmodifiable(_tags),
      sortOrder: existing?.sortOrder ?? 0,
      revision: (existing?.revision ?? 0) + 1,
      clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(noteRepositoryProvider).upsertNote(note);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _addTag() {
    final name = _tagInput.text.trim();
    if (name.isEmpty || _tags.contains(name) || _tags.length >= 32) {
      return;
    }
    setState(() {
      _tags.add(name);
      _tagInput.clear();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _tagInput.dispose();
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('note_editor_tag_input'),
                      controller: _tagInput,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '添加标签',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('note_editor_tag_add'),
                    tooltip: '添加标签',
                    icon: const Icon(Icons.add),
                    onPressed: _addTag,
                  ),
                ],
              ),
            ),
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in _tags)
                      InputChip(
                        key: ValueKey('note_editor_tag_$tag'),
                        label: Text(tag),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
            _ChecklistPanel(controller: _body),
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


class _ChecklistItem {
  const _ChecklistItem({
    required this.start,
    required this.length,
    required this.text,
    required this.done,
  });

  final int start;
  final int length;
  final String text;
  final bool done;
}

/// 清单面板（F-06；契约 §1：checklist 由 Delta attributes.list 表达）。
/// 勾选即改写该行 list 属性（unchecked/checked），保存后由仓库清点计数。
class _ChecklistPanel extends StatelessWidget {
  const _ChecklistPanel({required this.controller});

  final quill.QuillController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = _items();
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            for (final item in items)
              CheckboxListTile(
                key: ValueKey('note_checklist_${item.start}'),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.done,
                title: Text(
                  item.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (checked) => controller.formatText(
                  item.start,
                  item.length,
                  quill.Attribute.clone(
                    quill.Attribute.list,
                    checked == true ? 'checked' : 'unchecked',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<_ChecklistItem> _items() {
    final ops = controller.document.toDelta().toJson();
    var offset = 0;
    final items = <_ChecklistItem>[];
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is! String) {
        continue;
      }
      final attrs = op['attributes'];
      final list = attrs is Map ? attrs['list'] : null;
      if (list is String && list.isNotEmpty) {
        items.add(_ChecklistItem(
          start: offset,
          length: insert.length,
          text: insert.trim(),
          done: list == 'checked',
        ));
      }
      offset += insert.length;
    }
    return items;
  }
}
