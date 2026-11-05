import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';

/// 新文件夹 id（本地唯一即可；与笔记 id 同构，避免引入 uuid 依赖）。
String newNoteFolderId([DateTime? now]) =>
    'folder-${(now ?? DateTime.now()).millisecondsSinceEpoch}';

/// 首启/空库兜底：保证至少有一个可写文件夹（Apple 备忘录首启即带默认
/// 「备忘录」文件夹；否则「新建备忘录 / 快速记录」都会卡在「先新建一个
/// 文件夹」且界面没有建文件夹入口，见 parity#155）。
///
/// 幂等：任一非智能文件夹存在即返回其 id。
Future<String> ensureDefaultNoteFolder(NoteRepository repo) async {
  final folders = await repo.watchFolders().first;
  for (final f in folders) {
    if (!f.smart) return f.id;
  }
  final folder = NoteFolder(id: newNoteFolderId(), name: '备忘录');
  return repo.upsertFolder(folder);
}
