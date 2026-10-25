import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

import '../providers.dart';
import 'event_form_fields.dart';

/// 日程 Inspector（契约 §5.4 event_inspector_pane.dart；F-08）。
///
/// 三档呈现由外壳决定（compact=全屏 push / medium=sheet / expanded=第三栏）——
/// 本组件只做布局无关的编辑面。保存走 `upsertEvent`；空标题禁止保存
/// （TC-CAL-UI-137：不关闭、不写库）。
class EventInspectorPane extends ConsumerStatefulWidget {
  const EventInspectorPane({
    super.key,
    required this.initialEvent,
    required this.onSaved,
    this.onClose,
  });

  final CalendarEvent initialEvent;

  /// 保存成功回调（外壳用于关闭 sheet / 清 selectedOccurrence）。
  final VoidCallback onSaved;

  final VoidCallback? onClose;

  @override
  ConsumerState<EventInspectorPane> createState() => _EventInspectorPaneState();
}

class _EventInspectorPaneState extends ConsumerState<EventInspectorPane> {
  late CalendarEvent _draft;
  bool _saveAttempted = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialEvent;
  }

  @override
  void didUpdateWidget(covariant EventInspectorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEvent.id != widget.initialEvent.id) {
      _draft = widget.initialEvent;
      _saveAttempted = false;
    }
  }

  bool get _titleEmpty => _draft.title.trim().isEmpty;

  Future<void> _save() async {
    if (_titleEmpty) {
      setState(() => _saveAttempted = true); // TC-CAL-UI-137：不关闭不写库
      return;
    }
    final repo = ref.read(calendarRepositoryProvider);
    await repo.upsertEvent(_draft);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('event_inspector_pane'),
      child: Column(
        children: [
          AppBar(
            title: Text(_draft.title.trim().isEmpty ? '新建日程' : _draft.title),
            actions: [
              TextButton(
                key: const Key('event_inspector_save'),
                onPressed: _save,
                child: const Text('保存'),
              ),
              if (widget.onClose != null)
                IconButton(
                  key: const Key('event_inspector_close'),
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          Expanded(
            child: EventFormFields(
              event: _draft,
              onChanged: (next) => setState(() => _draft = next),
            ),
          ),
          if (_saveAttempted && _titleEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('请填写标题后再保存',
                  style: TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// 三档呈现封装（外壳按宽度择一；契约 §8.5）。
///
/// compact <600 → 全屏 route；medium → bottom sheet；expanded ≥1200 → 第三栏 widget。
class EventInspectorHost extends StatelessWidget {
  const EventInspectorHost({super.key, required this.event, required this.onSaved});

  final CalendarEvent event;
  final VoidCallback onSaved;

  /// compact 全屏（push 新路由）。
  static Future<void> openFullScreen(BuildContext context, CalendarEvent event,
      VoidCallback onSaved) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(body: EventInspectorPane(initialEvent: event, onSaved: onSaved)),
    ));
  }

  /// medium bottom sheet。
  static Future<void> openSheet(BuildContext context, CalendarEvent event,
      VoidCallback onSaved) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: EventInspectorPane(
          initialEvent: event,
          onSaved: onSaved,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // expanded 第三栏形态：外壳直接放进 Row 尾部。
    return EventInspectorPane(
      initialEvent: event,
      onSaved: onSaved,
      onClose: () {},
    );
  }
}
