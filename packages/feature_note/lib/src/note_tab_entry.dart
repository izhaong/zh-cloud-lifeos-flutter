import 'note_scaffold.dart';

/// 壳接入点（契约 §5：/note 分支入口）。
class NoteTabEntry extends StatelessWidget {
  const NoteTabEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return const NoteScaffold();
  }
}
