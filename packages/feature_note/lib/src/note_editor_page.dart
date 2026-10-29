import 'dart:async';
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
    this.unlockPassphrase,
    this.embedded = false,
  });

  /// 内嵌宿主（#421）：宽屏三栏里就地编辑，不画导航栏、不提供返回箭头。
  ///
  /// 保存模型不变（仍是显式「保存」，自动保存由 #390 单独收口），
  /// 两张卡因此不会互相踩。
  final bool embedded;

  final Note? note;
  final String folderId;

  /// 已通过解锁口令进入（F-12）：允许把 locked 写回 false。
  final bool unlockedInitial;

  /// 解锁时用的口令（#395）：已解锁的备忘录保存时要**重新加密**，
  /// 否则一次保存就把密文换回明文，锁定等于白做。
  final String? unlockPassphrase;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _tagInput;
  late final quill.QuillController _body;
  late final List<String> _tags = [...?widget.note?.tagNames];


  /// 开头格式（#392）要能把光标放到标题或正文，所以两个焦点节点自己持有
  /// （不依赖控件内部自建的节点，否则测不到、也没法 dispose）。
  final FocusNode _titleFocus = FocusNode(debugLabel: 'note_editor_title');
  final FocusNode _bodyFocus = FocusNode(debugLabel: 'note_editor_body');

  /// 自动保存（#390）：Apple 备忘录没有「保存」按钮，边写边存。
  ///
  /// 用 `Timer` 字段而**不是**裸 `Future.delayed`：`flutter_test` 的假时钟会因为
  /// 未决定时器直接报 `A timer is still pending`（本仓已踩过，见 AGENTS.md）。
  static const Duration autosaveDebounce = Duration(milliseconds: 600);
  Timer? _autosave;
  bool _dirty = false;

  /// 当前这条备忘录的 id（新建时首个 flush 才拿到）。
  String? _noteId;

  /// 上一次落库的正文序列化结果，用来判断「文档真的变了」。
  String _lastSavedDelta = '';

  /// 仓储引用（initState 捕获）。
  ///
  /// **不能**在 `dispose()` 里 `ref.read`：Riverpod 会在 State 即将卸载时抛
  /// `Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe`，
  /// 而 dispose 里恰恰要 flush 未落库的改动（#390 的核心判据之一）。
  late final NoteRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(noteRepositoryProvider);
    _noteId = widget.note?.id;
    _title = TextEditingController(text: widget.note?.title ?? '');
    _tagInput = TextEditingController();
    _body = quill.QuillController(
      document: _loadDocument(widget.note?.bodyDelta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    // 只对新建生效：编辑既有备忘录时按「开头格式」重排内容会把用户数据改掉。
    if (widget.note == null) {
      _applyBeginWith(ref.read(noteSettingsProvider).beginWith);
    }
    _lastSavedDelta = _deltaJson();
    _title.addListener(_markDirty);
    _body.addListener(_onBodyChanged);
  }

  /// 「新备忘录开头格式」的消费端（矩阵 N25 / TC-NOTE-UI-111）。
  ///
  /// 四档都要有可观察后果，否则又是个死控件：`nothing` 保持空白；
  /// `title`/`body` 决定光标落在哪；`checklist` 往正文种一个未勾选清单项
  /// （和「格式 → 待办」用同一个 `list` 属性，渲染与内核计数同口径）。
  void _applyBeginWith(NoteBeginWithMode mode) {
    switch (mode) {
      case NoteBeginWithMode.nothing:
        break;
      case NoteBeginWithMode.title:
        _focusAfterFirstFrame(_titleFocus);
      case NoteBeginWithMode.body:
        _focusAfterFirstFrame(_bodyFocus);
      case NoteBeginWithMode.checklist:
        _body.formatText(
          0,
          _body.document.length,
          quill.Attribute.clone(quill.Attribute.list, 'unchecked'),
        );
        _focusAfterFirstFrame(_bodyFocus);
    }
  }

  /// 焦点只能在首帧之后要：initState 里节点还没挂到焦点树上。
  void _focusAfterFirstFrame(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node.requestFocus();
    });

    _lastSavedDelta = _deltaJson();
    _title.addListener(_markDirty);
    _body.addListener(_onBodyChanged);
  }

  String _deltaJson() => jsonEncode({'ops': _body.document.toDelta().toJson()});

  void _onBodyChanged() {
    // 选区变化也走这个 listener：只有正文真变了才排保存
    if (_deltaJson() == _lastSavedDelta) return;
    _markDirty();
  }

  void _markDirty() {
    _dirty = true;
    _autosave?.cancel();
    _autosave = Timer(autosaveDebounce, () => unawaited(_flush()));
  }

  /// 落库（不关页）。返回是否真的写了一次。
  Future<bool> _flush() async {
    if (!_dirty) return false;
    final existing = widget.note;
    if (existing != null && existing.locked && !widget.unlockedInitial) {
      return false; // 未解锁不允许覆盖密文（F-12）
    }
    final plainDelta = _deltaJson();
    final keepLocked = existing != null &&
        existing.locked &&
        (widget.unlockedInitial || widget.unlockPassphrase != null);
    final delta = keepLocked
        ? NoteLockCodec.seal(plainDelta, widget.unlockPassphrase ?? '')
        : plainDelta;
    final note = Note(
      id: _noteId ?? 'note-${DateTime.now().millisecondsSinceEpoch}',
      folderId: existing?.folderId ?? widget.folderId,
      title: _title.text.trim().isEmpty ? '新建备忘录' : _title.text.trim(),
      bodyDelta: delta,
      pinned: existing?.pinned ?? false,
      locked: keepLocked,
      tagNames: List<String>.unmodifiable(_tags),
      sortOrder: existing?.sortOrder ?? 0,
      revision: (existing?.revision ?? 0) + 1,
      clientUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _noteId = note.id;
    _lastSavedDelta = plainDelta;
    _dirty = false;
    await _repo.upsertNote(note);
    return true;
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

  /// #420（矩阵 N02/N05）：Apple 备忘录把这些能力收在「格式」菜单里，本仓此前
  /// 是 5 个平铺按钮——窄屏放不下、能力也找不到。菜单只列**已实现**的能力：
  /// 表格/字号/笔在 N02 里尚未裁定为对等范围，摆成占位就是死控件（#444 的教训）。
  Future<void> _showFormatMenu() async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => LifeActionSheet(
        key: const Key('note_editor_format_sheet'),
        title: const Text('格式'),
        actions: [
          LifeActionSheetAction(
            key: const ValueKey('note_format_bold'),
            onPressed: () => Navigator.of(sheetContext).pop('bold'),
            child: const Text('加粗'),
          ),
          LifeActionSheetAction(
            key: const ValueKey('note_format_italic'),
            onPressed: () => Navigator.of(sheetContext).pop('italic'),
            child: const Text('斜体'),
          ),
          LifeActionSheetAction(
            key: const ValueKey('note_format_underline'),
            onPressed: () => Navigator.of(sheetContext).pop('underline'),
            child: const Text('下划线'),
          ),
          LifeActionSheetAction(
            key: const ValueKey('note_format_link'),
            onPressed: () => Navigator.of(sheetContext).pop('link'),
            child: const Text('添加链接'),
          ),
          LifeActionSheetAction(
            key: const ValueKey('note_format_checklist'),
            onPressed: () => Navigator.of(sheetContext).pop('checklist'),
            child: const Text('清单'),
          ),
        ],
        cancelButton: LifeActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    switch (action) {
      case 'bold':
        _body.formatSelection(quill.Attribute.bold);
      case 'italic':
        _body.formatSelection(quill.Attribute.italic);
      case 'underline':
        _body.formatSelection(quill.Attribute.underline);
      case 'link':
        await _addLink();
      case 'checklist':
        _toggleChecklist();
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
    // #390：自动保存后不再有「先保存再共享」这个前置——先把待写内容 flush 掉，
    // 拿到 id 就能共享。仍然拿不到 id 只可能是**完全没输入过**，那才提示。
    if (_dirty) await _flush();
    final existingId = _noteId;
    if (!mounted) return; // 上面 await 过，取 context 前必须复查
    if (existingId == null) {
      await _infoDialog('先写点内容再共享');
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
          noteId: existingId,
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
    // #395：锁定必须是**真加密**——此前只写 `locked: true`，正文仍以明文 JSON
    // 落库，口令也只是「非空即可」，等于没有保护。
    final passphrase = passwordController.text.trim();
    final delta = NoteLockCodec.seal(
      jsonEncode({'ops': _body.document.toDelta().toJson()}),
      passphrase,
    );
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
            // 锁定的正文不参与搜索索引（Apple 同样不索引锁定内容）
            bodyText: '',
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

  /// 链接（#397 矩阵 N05）：先要求有选区，再收 URL，确认后给选区打 `link`。
  ///
  /// 光标没选中文字时当场说明，不弹输入框——避免「填完 URL 才发现没作用」；
  /// 与 #396「入口可用或不存在」的口径一致。
  Future<void> _addLink() async {
    if (_body.selection.isCollapsed) {
      await _infoDialog('先选中要加链接的文字');
      if (!mounted) return;
    }
    final input = TextEditingController();
    final url = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('添加链接'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            key: const ValueKey('note_link_url'),
            controller: input,
            placeholder: 'https://example.com',
            autocorrect: false,
            enableSuggestions: false,
          ),
        ),
        actions: [
          CupertinoButton(
            key: const ValueKey('note_link_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoButton(
            key: const ValueKey('note_link_submit'),
            onPressed: () => Navigator.of(dialogContext).pop(input.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    input.dispose();
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty || !mounted) {
      return;
    }
    _body.formatSelection(
      quill.Attribute.clone(quill.Attribute.link, trimmed),
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

  void _addTag() {
    final name = _tagInput.text.trim();
    if (name.isEmpty || _tags.contains(name) || _tags.length >= 32) {
      return;
    }
    setState(() {
      _tags.add(name);
      _tagInput.clear();
    });
    _markDirty(); // 标签也是内容的一部分，改了要落库
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
    // 离开编辑面（推入页 pop / 三栏切换记录）必须把未落库的改动刷掉，
    // 否则就是 #390 报的「漏点保存静默丢内容」。
    _autosave?.cancel();
    if (_dirty) {
      unawaited(_flush());
    }
    _title.dispose();
    _tagInput.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _body.dispose();
    super.dispose();
  }

  /// 编辑器的动作按钮（导航栏与内嵌工具条共用，避免两套漂移）。
  List<Widget> _actions() => [
            _EditorAction(
              key: const ValueKey('note_editor_more'),
              semanticLabel: '更多',
              icon: CupertinoIcons.ellipsis,
              onPressed: _showMoreMenu,
            ),
            // #396：假端口只会 `throw UnsupportedError('共享客户端未接入')`，
            // 入口摆出来就是必崩交互。Apple 口径「入口可用或不存在」，与任务侧
            // 对「分配事项」的负向门禁一致。
            if (ref.watch(noteSharePortProvider).isAvailable)
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
            // #420（矩阵 N02/N05）：Apple 把加粗/斜体/下划线/链接/清单收在
            // 「格式」菜单里；本仓此前是 5 个平铺按钮——窄屏放不下、能力也找不到。
            // 菜单只列已实现的能力（表格/字号/笔未裁定为对等范围，不摆占位）。
            _EditorAction(
              key: const ValueKey('note_editor_format'),
              semanticLabel: '格式',
              icon: CupertinoIcons.textformat,
              onPressed: _showFormatMenu,
            ),
      ];

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
        child: Column(
          children: [
            CupertinoTextField(
              key: const ValueKey('note_editor_title'),
              controller: _title,
              focusNode: _titleFocus,
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
                                onTap: () {
                                  setState(() => _tags.remove(tag));
                                  _markDirty();
                                },
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
                  focusNode: _bodyFocus,
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
      );
    if (widget.embedded) {
      // 内嵌宿主（#421）：无导航栏、无返回箭头；动作按钮压成一行工具条，
      // 外观向 Apple 备忘录第三栏看齐（标题就地编辑）。
      return Column(
        key: const Key('note_editor_embedded'),
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _actions(),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return CupertinoPageScaffold(
      key: const Key('note_editor_page'),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.note == null ? '新建备忘录' : '编辑备忘录'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: _actions()),
      ),
      child: body,
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
