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
  const NoteEditorPage({
    super.key,
    this.note,
    required this.folderId,
    this.unlockedInitial = false,
  });

  final Note? note;
  final String folderId;

  /// 已通过解锁口令进入（F-12）：允许把 locked 写回 false。
  final bool unlockedInitial;

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

  Future<void> _share() async {
    final existing = widget.note;
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先保存备忘录再共享')),
      );
      return;
    }
    final userIdController = TextEditingController();
    var writable = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('共享备忘录'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('note_share_user_id'),
                controller: userIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '对方用户编号'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    key: const ValueKey('note_share_read'),
                    label: const Text('只读'),
                    selected: !writable,
                    onSelected: (_) => setLocalState(() => writable = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const ValueKey('note_share_write'),
                    label: const Text('可写'),
                    selected: writable,
                    onSelected: (_) => setLocalState(() => writable = true),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const ValueKey('note_share_submit'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('共享'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) {
      return;
    }
    final targetUserId = userIdController.text.trim();
    if (targetUserId.isEmpty) {
      return;
    }
    await ref.read(noteSharePortProvider).share(
          noteId: existing.id,
          targetUserId: targetUserId,
          writable: writable,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已共享')),
      );
    }
  }

  Future<void> _lock() async {
    final existing = widget.note;
    if (existing == null || existing.locked) {
      return;
    }
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('锁定备忘录'),
        content: TextField(
          key: const ValueKey('note_lock_password'),
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: '设置密码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('note_lock_confirm'),
            onPressed: () => Navigator.of(dialogContext)
                .pop(passwordController.text.trim().isNotEmpty),
            child: const Text('锁定'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final delta = jsonEncode({'ops': _body.document.toDelta().toJson()});
    await ref.read(noteRepositoryProvider).upsertNote(Note(
          id: existing.id,
          folderId: existing.folderId,
          title: _title.text.trim().isEmpty ? existing.title : _title.text.trim(),
          bodyDelta: delta,
          pinned: existing.pinned,
          locked: true,
          tagNames: List<String>.unmodifiable(_tags),
          sortOrder: existing.sortOrder,
          revision: existing.revision + 1,
          clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _insertImage() async {
    final path = await ref.read(noteImagePickerProvider)();
    if (path == null) {
      return;
    }
    final index = _body.selection.baseOffset < 0
        ? _body.document.length - 1
        : _body.selection.baseOffset;
    _body.document.insert(index, quill.Embeddable('noteImage', {'path': path}));
    _body.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
  }

  Future<void> _save() async {
    final existing = widget.note;
    if (existing != null && existing.locked && !widget.unlockedInitial) {
      return; // 未解锁不允许覆盖密文（F-12）
    }
    final delta = jsonEncode({'ops': _body.document.toDelta().toJson()});
    final note = Note(
      id: existing?.id ??
          'note-${DateTime.now().millisecondsSinceEpoch}',
      folderId: existing?.folderId ?? widget.folderId,
      title: _title.text.trim().isEmpty ? '新建备忘录' : _title.text.trim(),
      bodyDelta: delta,
      pinned: existing?.pinned ?? false,
      locked: existing != null && existing.locked
          ? !widget.unlockedInitial
          : false,
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
            key: const ValueKey('note_editor_share'),
            tooltip: '共享',
            icon: const Icon(Icons.people_outline),
            onPressed: _share,
          ),
          IconButton(
            key: const ValueKey('note_editor_lock'),
            tooltip: '锁定',
            icon: const Icon(Icons.lock_outline),
            onPressed: _lock,
          ),
          IconButton(
            key: const ValueKey('note_editor_image'),
            tooltip: '插入图片',
            icon: const Icon(Icons.image_outlined),
            onPressed: _insertImage,
          ),
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
                  embedBuilders: [NoteImageEmbedBuilder()],
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


/// 图片 embed（F-09）：Delta 里存 {noteImage: {path}}，开源包只渲染占位与文件名；
/// 上传 infra 换 fileId 在 cloud 包（F-16）。
class NoteImageEmbedBuilder extends quill.EmbedBuilder {
  const NoteImageEmbedBuilder();

  @override
  String get key => 'noteImage';

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    final path = data is Map ? '${data['path'] ?? ''}' : '$data';
    final name = path.split('/').last;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.image_outlined, size: 16),
        const SizedBox(width: 4),
        Text(name, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
