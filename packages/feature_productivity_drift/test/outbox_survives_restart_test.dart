// #372 面②（可自动化的一半）：杀进程恢复——关库重开后发件箱不丢。
//
// 现有用例覆盖了「离线新建入队」「推送失败不丢载荷」「幂等键不换」，
// 但都跑在**同一个进程内**的同一个 DB 实例上。真实的「杀进程」是：
// DB 被关掉、文件还在、下次冷启动重新打开。这条路径没有任何用例走过。
//
// 判据：离线写一条 → 关库（模拟被杀）→ 重新打开同一个文件 →
// 队列里那条还在，且用新的推送端口能把它推出去。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:feature_productivity_drift/feature_productivity_drift.dart';
import 'package:feature_productivity_kernel/feature_productivity_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('#372 杀进程恢复：关库重开后离线变更仍待推', () async {
    final dir = Directory.systemTemp.createTempSync('outbox_restart');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dbFile = File('${dir.path}/lifeos.sqlite');

    // ── 第一次启动：离线改一条，让它进发件箱
    final db1 = LifeProductivityDb(NativeDatabase(dbFile));
    final repo1 = DriftReminderRepository(db1);
    await repo1.upsertList(const ReminderList(id: 'l1', title: '离线列表'));
    await repo1.upsertItem(
      const ReminderItem(id: 'i1', listId: 'l1', title: '离线写的'),
    );

    final outbox1 = DriftSyncOutbox(db1);
    final pending1 = await outbox1.pending();
    expect(pending1, isNotEmpty, reason: '离线写必须入队');
    final beforeKill = pending1.length;

    // ── 模拟被杀：直接关库（不清理队列）
    await db1.close();

    // ── 第二次启动：同一个文件、新实例
    final db2 = LifeProductivityDb(NativeDatabase(dbFile));
    addTearDown(db2.close);
    final repo2 = DriftReminderRepository(db2);
    final outbox2 = DriftSyncOutbox(db2);

    final pending2 = await outbox2.pending();
    expect(
      pending2.length,
      beforeKill,
      reason: '杀进程后发件箱不能丢——丢了等于用户离线写的改动永远不上云',
    );
    expect(
      pending2.map((p) => p.entityId),
      contains('i1'),
      reason: '具体那条也要在',
    );

    // 数据本身也没丢
    final items = await repo2.watchItems(listId: 'l1').first;
    expect(items.map((e) => e.id), contains('i1'));

    // ── 恢复后能真的推出去（回执清队 + 回填 remoteId）
    await outbox2.acknowledge(
      entityType: 'task',
      entityId: 'i1',
      serverId: '9001',
    );
    // 只认 task 那条：离线新建列表也会入队（entityType=list），不该被这条回执清掉
    final remaining = await outbox2.pending();
    expect(
      remaining.where((e) => e.entityId == 'i1'),
      isEmpty,
      reason: '回执后 task 那条应清队',
    );
    expect(
      remaining.map((e) => e.entityType),
      contains('list'),
      reason: '奖回执不该误清其它实体的队列项',
    );
    final after = await repo2.watchItems(listId: 'l1').first;
    expect(
      after.firstWhere((e) => e.id == 'i1').remoteId,
      '9001',
      reason: '服务端 id 要回填到本地行',
    );
  });
}
