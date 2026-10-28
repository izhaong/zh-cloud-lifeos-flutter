import 'package:app_ui/app_ui.dart';
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
      // #237：先把旧落点的清单属性归一到行尾 op，否则 quill 不建 Block、
      // 行首勾选框不渲染（内核计数却算进去了，渲染与计数会打架）。
      final decoded = jsonDecode(
        NoteMarkdownCodec.normalizeListAttributes(deltaJson),
      );
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
      builder: (sheetContext) => LifeActionSheet(
        key: const Key('note_editor_more_sheet'),
        actions: [
          LifeActionSheetAction(
            key: const ValueKey('note_export_markdown'),
            onPressed: () => Navigator.of(sheetContext).pop('export'),
            child: const Text('导出 Markdown'),
          ),
          LifeActionSheetAction(
            key: const ValueKey('note_import_markdown'),
            onPressed: () => Navigator.of(sheetContext).pop('import'),
            child: const Text('导入 Markdown'),
          ),
        ],
        cancelButton: LifeActionSheetAction(
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
      builder: (dialogContext) => LifeAlertDialog(
        title: const Text('导出 Markdown'),
        content: SingleChildScrollView(
          child: Text(markdown, key: const ValueKey('note_export_text')),
        ),
        actions: [
          LifeDialogAction(
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
      builder: (dialogContext) => LifeAlertDialog(
        title: const Text('导入 Markdown'),
        content: CupertinoTextField(
          key: const ValueKey('note_import_text'),
          controller: controller,
          maxLines: 6,
          placeholder: '# 标题\n正文',
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          LifeDialogAction(
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
        builder: (context, setLocalState) => LifeAlertDialog(
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
            LifeDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            LifeDialogAction(
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
      builder: (dialogContext) => LifeAlertDialog(
        title: const Text('锁定备忘录'),
        content: CupertinoTextField(
          key: const ValueKey('note_lock_password'),
          controller: passwordController,
          obscureText: true,
          placeholder: '设置密码',
        ),
        actions: [
          LifeDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          LifeDialogAction(
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

  /// 清单开关（parity#202）：把当前行/选区切成 `list: unchecked`；
  /// 已是清单（unchecked/checked）则取消回普通段落。
  void _toggleChecklist() {
    final current = _body
        .getSelectionStyle()
        .attributes[quill.Attribute.list.key]
        ?.value;
    final isChecklist = current == 'unchecked' || current == 'checked';
    _body.formatSelection(
      quill.Attribute.clone(
        quill.Attribute.list,
        isChecklist ? null : 'unchecked',
      ),
    );
    _body.updateSelection(_body.selection, quill.ChangeSource.local);
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
      builder: (dialogContext) => LifeAlertDialog(
        content: Text(message),
        actions: [
          LifeDialogAction(
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
            // parity#202：清单入口（Apple 格式菜单的「清单」）；此前只能靠
            // 导入 Markdown 的 `- [ ]` 才能造出清单行。
            _EditorAction(
              key: const ValueKey('note_editor_checklist'),
              semanticLabel: '清单',
              icon: CupertinoIcons.list_bullet,
              onPressed: _toggleChecklist,
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
                          borderRadius: BorderRadius.circular(LifeRadius.sm),
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
