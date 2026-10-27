import 'dart:convert';

import 'package:app_core/app_core.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import 'note_markdown.dart';
import 'providers.dart';

/// 记录编辑器（F-05；契约 §5、§8：flutter_quill 11.6.0）。
///
/// 新建/编辑标题与富文本正文；保存写回 [NoteRepository]，正文序列化为
/// Quill Delta JSON（bodyDelta），纯文本与清单计数由仓库归一。
/// quill 为 Material 内核，整块进 [LifeMaterialIsland]。
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
        return quill.Document.fromJson(
          List<dynamic>.from(decoded['ops'] as List),
        );
      }
    } catch (_) {
      // 锁定密文或损坏内容：不解析，按空文档打开由上层锁定页拦截
    }
    return quill.Document();
  }

  Future<void> _showMoreMenu() async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        key: const Key('note_editor_more_sheet'),
        actions: [
          CupertinoActionSheetAction(
            key: const ValueKey('note_export_markdown'),
            onPressed: () => Navigator.of(sheetContext).pop('export'),
            child: const Text('导出 Markdown'),
          ),
          CupertinoActionSheetAction(
            key: const ValueKey('note_import_markdown'),
            onPressed: () => Navigator.of(sheetContext).pop('import'),
            child: const Text('导入 Markdown'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (action == 'export') {
      await _exportMarkdown();
    } else if (action == 'import') {
      await _importMarkdown();
    }
  }

  Future<void> _exportMarkdown() async {
    final existing = widget.note;
    if (existing == null) {
      await _infoDialog('先保存备忘录再导出');
      return;
    }
    final markdown = NoteMarkdownCodec.toMarkdown(
      _title.text,
      jsonEncode({'ops': _body.document.toDelta().toJson()}),
    );
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出 Markdown'),
        content: SingleChildScrollView(
          child: Text(markdown, key: const ValueKey('note_export_text')),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _importMarkdown() async {
    final controller = TextEditingController();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导入 Markdown'),
        content: CupertinoTextField(
          key: const ValueKey('note_import_text'),
          controller: controller,
          maxLines: 6,
          placeholder: '# 标题\n正文',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            key: const ValueKey('note_import_submit'),
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.trim().isEmpty) {
      return;
    }
    final parsed = NoteMarkdownCodec.fromMarkdown(controller.text);
    await ref
        .read(noteRepositoryProvider)
        .upsertNote(
          Note(
            id: 'note-${DateTime.now().millisecondsSinceEpoch}',
            folderId: widget.note?.folderId ?? widget.folderId,
            title: parsed.title,
            bodyDelta: parsed.deltaJson,
            clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    if (mounted) {
      await _infoDialog('已导入为新备忘录');
    }
  }

  Future<void> _share() async {
    final existing = widget.note;
    if (existing == null) {
      await _infoDialog('先保存备忘录再共享');
      return;
    }
    final userIdController = TextEditingController();
    var writable = false;
    final submitted = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => CupertinoAlertDialog(
          title: const Text('共享备忘录'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                key: const ValueKey('note_share_user_id'),
                controller: userIdController,
                keyboardType: TextInputType.number,
                placeholder: '对方用户编号',
              ),
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<int>(
                key: const Key('note_share_permission'),
                groupValue: writable ? 1 : 0,
                onValueChanged: (value) =>
                    setLocalState(() => writable = value == 1),
                children: const <int, Widget>{
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('只读', key: ValueKey('note_share_read')),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('可写', key: ValueKey('note_share_write')),
                  ),
                },
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              key: const ValueKey('note_share_submit'),
              isDefaultAction: true,
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
    await ref
        .read(noteSharePortProvider)
        .share(
          noteId: existing.id,
          targetUserId: targetUserId,
          writable: writable,
        );
    if (mounted) {
      await _infoDialog('已共享');
    }
  }

  Future<void> _lock() async {
    final existing = widget.note;
    if (existing == null || existing.locked) {
      return;
    }
    final passwordController = TextEditingController();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('锁定备忘录'),
        content: CupertinoTextField(
          key: const ValueKey('note_lock_password'),
          controller: passwordController,
          obscureText: true,
          placeholder: '设置密码',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            key: const ValueKey('note_lock_confirm'),
            isDefaultAction: true,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(passwordController.text.trim().isNotEmpty),
            child: const Text('锁定'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final delta = jsonEncode({'ops': _body.document.toDelta().toJson()});
    await ref
        .read(noteRepositoryProvider)
        .upsertNote(
          Note(
            id: existing.id,
            folderId: existing.folderId,
            title: _title.text.trim().isEmpty
                ? existing.title
                : _title.text.trim(),
            bodyDelta: delta,
            pinned: existing.pinned,
            locked: true,
            tagNames: List<String>.unmodifiable(_tags),
            sortOrder: existing.sortOrder,
            revision: existing.revision + 1,
            clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
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
      id: existing?.id ?? 'note-${DateTime.now().millisecondsSinceEpoch}',
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

  Future<void> _infoDialog(String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
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
    return CupertinoPageScaffold(
      key: const Key('note_editor_page'),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.note == null ? '新建备忘录' : '编辑备忘录'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EditorAction(
              key: const ValueKey('note_editor_more'),
              semanticLabel: '更多',
              icon: CupertinoIcons.ellipsis,
              onPressed: _showMoreMenu,
            ),
            _EditorAction(
              key: const ValueKey('note_editor_share'),
              semanticLabel: '共享',
              icon: CupertinoIcons.person_2,
              onPressed: _share,
            ),
            _EditorAction(
              key: const ValueKey('note_editor_lock'),
              semanticLabel: '锁定',
              icon: CupertinoIcons.lock,
              onPressed: _lock,
            ),
            _EditorAction(
              key: const ValueKey('note_editor_image'),
              semanticLabel: '插入图片',
              icon: CupertinoIcons.photo,
              onPressed: _insertImage,
            ),
            _EditorAction(
              key: const ValueKey('note_editor_bold'),
              semanticLabel: '加粗',
              icon: CupertinoIcons.bold,
              onPressed: () => _body.formatSelection(quill.Attribute.bold),
            ),
            CupertinoButton(
              key: const ValueKey('note_editor_save'),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: _save,
              child: const Text(
                '保存',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            CupertinoTextField(
              key: const ValueKey('note_editor_title'),
              controller: _title,
              placeholder: '标题',
              decoration: null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      key: const ValueKey('note_editor_tag_input'),
                      controller: _tagInput,
                      placeholder: '添加标签',
                      decoration: null,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  CupertinoButton(
                    key: const ValueKey('note_editor_tag_add'),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: _addTag,
                    child: const Icon(
                      CupertinoIcons.add_circled,
                      size: 20,
                      color: CupertinoColors.systemBlue,
                    ),
                  ),
                ],
              ),
            ),
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      DecoratedBox(
                        key: ValueKey('note_editor_tag_$tag'),
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill.resolveFrom(
                            context,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tag, style: const TextStyle(fontSize: 13)),
                              GestureDetector(
                                onTap: () => setState(() => _tags.remove(tag)),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 2),
                                  child: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 14,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const _Separator(),
            _ChecklistPanel(controller: _body),
            Expanded(
              child: LifeMaterialIsland(
                child: quill.QuillEditor.basic(
                  controller: _body,
                  config: const quill.QuillEditorConfig(
                    placeholder: '开始记录…',
                    padding: EdgeInsets.all(16),
                    embedBuilders: [NoteImageEmbedBuilder()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorAction extends StatelessWidget {
  const _EditorAction({
    required Key key,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
  }) : super(key: key);

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onPressed: onPressed,
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: CupertinoColors.separator);
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
              Row(
                key: ValueKey('note_checklist_${item.start}'),
                children: [
                  CupertinoCheckbox(
                    value: item.done,
                    onChanged: (checked) => controller.formatText(
                      item.start,
                      item.length,
                      quill.Attribute.clone(
                        quill.Attribute.list,
                        checked == true ? 'checked' : 'unchecked',
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
        items.add(
          _ChecklistItem(
            start: offset,
            length: insert.length,
            text: insert.trim(),
            done: list == 'checked',
          ),
        );
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
        const Icon(
          CupertinoIcons.photo,
          size: 16,
          color: CupertinoColors.secondaryLabel,
        ),
        const SizedBox(width: 4),
        Text(
          name,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}
