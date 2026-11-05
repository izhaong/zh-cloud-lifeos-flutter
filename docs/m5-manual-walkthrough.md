# M5 多端回归 · 手动走查清单（TC-REG-101/103/104/106/109/110/111）

> 执行环境：macOS 桌面（flutter run -d macos）+ Chrome（flutter run -d chrome）为必跑；
> Android/iPad 真机如具备则加跑，不具备则记录「设备不可用」并在回归报告注明。
> 每项走完在 [ ] 打 x，异常截图归档 `zh-cloud-docs/lifeos/04_测试与质量/m5-regression/`。

## TC-REG-101 平台矩阵 × 核心链路（P0）

每平台按序执行，任何一步崩溃/白屏即 FAIL：

- [ ] **macOS**：新建列表 → 新建提醒 → 详情编辑（备注/优先级/旗标）→ 完成（圆圈划线）→ 搜索命中 → 删除（回收窗可见）
- [ ] **Web(chrome 宽屏)**：同上链路（三栏：侧栏|列表|inspector）
  —— 启动白屏阻塞已于 2026-10-26 解除（Issue #84，Web 接入 drift WASM），
  三栏渲染 + 新建 + 刷新不丢已实测；本行**整条链路**（详情编辑/完成/搜索/删除回收窗）仍未走完，故不打勾。
- [ ] **Web(chrome 窄窗 <600)**：同上链路（栈导航降级）
- [ ] **Android 手机**（如有）：同上链路
- [ ] **iPad 横竖屏**（如有）：横=双栏、竖=底 Tab；同上链路

## TC-REG-103 桌面快捷键（P1；flutter_test 无法模拟修饰键）

- [ ] **macOS**：⌘N → 出现草稿行并聚焦；⌘F → 焦点进工具栏搜索框
- [ ] **Windows**（如有）：Ctrl+N / Ctrl+F 同效
- [ ] **无死键**：在详情面板/设置弹层打开时按上述键不卡死

## TC-REG-104 i18n 抽查（P1）

- [ ] 系统切英文：任务首页/详情/设置弹层无硬编码中文残留（设置弹层首期占位文案允许中文，记 P1 债）
- [ ] 日期显示随 locale 本地化（Today/今天）

## TC-REG-106 golden 关键屏（P1）

对拍 `zh-cloud-docs/lifeos/wireframes/` 金标准截图（人工对照）：

- [ ] 手机首页（智能卡 2×2 + 我的列表）vs `reminders-iphone-lists.png`
- [ ] Pad 双栏 vs `ref-ipad-reminders-sidebar.jpg`
- [ ] 客户端三栏 vs `ref-macos-reminders-main-sidebar.png`
- [ ] 隐藏侧栏铺满 vs `ref-macos-reminders-sidebar-hidden.png`
- [ ] 新建列表模态 vs `ref-macos-reminders-new-list.png`

## TC-REG-109 Web 特有（P1）

> 前置：深链依赖服务端 SPA 回退（未知路径 → `index.html`）。用 `python3 -m http.server`
> 这类静态服务器直链会 404，那是**测试脚手架**的限制，不能据此判产品缺陷。

- [x] 宽屏直接刷新 `/` → 恢复任务首页（2026-10-26 实测）
- [x] 深链 `/list/smart.today` → 直接进「今天」视图（2026-10-26 实测，侧栏「今天」高亮）
- [ ] 窄窗深链同上 → 栈导航形态正确
- [x] 刷新后数据在（本地库不丢）（2026-10-26 实测：新建「web持久化验证」→ reload → 条目与
      智能列表计数（今天 1 / 全部 1 / 紧急 1）均在；drift 选中 `sharedIndexedDb` 后端）

## TC-REG-110 无障碍基线（P2 抽查）

- [ ] 完成圆圈有语义标签（读屏读出「完成 买牛奶」类）
- [ ] 底栏 Tab / 侧栏列表行可聚焦键盘导航

## TC-REG-111 服务端冒烟（P0，脚本）

```bash
# staging（Jenkins 晋升后容器内跑）
# IDEA HTTP Client 顺序执行：
# yudao-module-todo/.../AppTodoLifeosM1Smoke.http（12 步；M1 收口时 9/12 绿口径）
# lifeos-task 装配冒烟：
curl http://<host>:48080/app-api/lifeos/task/ping   # → {"module":"yudao-module-lifeos-task",...}
```

- [ ] M1 冒烟 12 步通过（或记录既有 3 缺口=lifeos-task 复制清单项）
- [ ] lifeos-task ping 200

## TC-REG-112 依赖与体积（P0，已自动化于本 PR）

- [x] `grep package:drift|sqlite3|app_core packages/feature_task/lib` 零命中
- [x] kernel 无 drift；feature_* 互不 import UI；feature_task 无 dio/secure_storage
- [x] CI grep 门禁脚本建议随 Jenkins/Gitea Actions 落地（docs/ci-plan.md 已列）

---

## 结论回填

| 用例 | 结果 | 证据 |
|------|------|------|
| TC-REG-102 三档回归 | ✅ 已自动化（tc_reg_regression_test.dart 四宽度断点） | 本 PR |
| TC-REG-107 负向门禁全量 | ✅ 已自动化（同上双档无泄漏断言） | 本 PR |
| TC-REG-108 生命周期 | ✅ 已自动化（重建重订阅+回前台写驱动） | 本 PR |
| TC-REG-105 千级性能 | ✅ 已自动化（1000 条 <10s + 搜索在线；真机 jank 属手动） | 本 PR |
| TC-REG-112 边界 grep | ✅ 已执行（四组 grep 全零命中） | 本 PR |
| TC-REG-101/103/104/106/110/111 | 手动（本清单） | 待设备走查归档 |
| TC-REG-109 Web 特有 | 部分手动（4 项中 3 项已实测） | 2026-10-26 Web 复验记录 |

---

## 实机复验记录（2026-10-24，macOS）

### 批 1–2 修复项（PR 分支 fix/m5-parity-gaps，cursor 图评两轮）

| 项 | 状态 | 证据 |
|----|------|------|
| P0-1 侧栏顶小图标（新建\|隐藏\|设置） | ✅ cursor r3 图评确认 | 无底栏三等分钮 |
| P2 搜索细边白底/侧栏浅灰/空态引导 | ✅ cursor r3 图评确认 | 图评原文「已修复」 |
| P0-2 顶栏＋ | ✅ cursor r3 图评确认 | `toolbar_new_item` 可见 |
| P0-2 空列表大标题 | ✅ 第 3 批重构+回归测试 | `tc_reg_regression_test.dart` descendant 断言 |
| P0-5 空列表+⌘N 草稿行 | ✅ `_showDraft` 守卫+回归测试 | 同上（工具栏＋点击路径全绿） |
| P0-3 0 完成无「清除」 | ✅ 代码 doneCount>0 才渲染 | `_ListHeaderToolbar` |
| P1-2 ⋯ 菜单 | ✅ PopupMenuButton | `list_more_menu` |

### 截图归档
- `docs/m5-regression-evidence/macos-main-after-parity-batch3.png`（第三批后主界面，精确窗口区域截屏）

### 待续（cursor 额度 11/18 重置后补跑）
- ⌘N 系统级快捷键实机走查（辅助访问权限需用户授予 osascript；自动化侧 19 项测试已覆盖行为）
- P2 质感收敛：底栏＋样式、侧栏角标全量、分享钮、设置图1 真身（列于下一批清单）

---

## 实机复验记录（2026-10-26，Web / Chrome）

Issue #84：Web 端此前**启动即纯白屏**，TC-REG-101 与 109 整条无法执行。

### 根因

`apps/life_launcher/lib/main.dart` 在 `runApp` 之前无条件 `await openDefaultDatabase()`，
而该方法对 `kIsWeb` 直接 `throw StateError`。`main()` 中断 → 白屏（不是红屏，因为框架还没起来）。
全仓 `flutter test` 当时**全绿**，这条缺陷在自动化侧完全量不到。

### 修复

Web 分支改走 drift 的 WASM 后端。`drift_flutter 0.3.1` 的 `lib/src/connect.dart`
用条件导出内置了 web 实现，因此不需要手写连接工厂，只需传 `DriftWebOptions`。
新增两份 `apps/life_launcher/web/` 静态资源，来源与 `pubspec.lock` 钉版严格对齐：

| 资源 | 来源 | 体积 |
|------|------|------|
| `sqlite3.wasm` | `simolus3/sqlite3.dart` release tag `sqlite3-3.5.2` | 748,686 B |
| `drift_worker.js` | pub 包 `drift-2.35.2` 根目录预构建产物 | 360,104 B |

原生开库路径**字节未变**：macOS 沙盒里的实际文件名是
`~/Library/Containers/com.zhcloud.lifeos.lifeLauncher/Data/Documents/life_productivity.sqlite.sqlite`
（双 `.sqlite` 后缀，因为把绝对路径当 `name` 传给了 `driftDatabase`，后者又拼了一次目录与后缀）。
本批故意不改——改 `name` 会让原生端去开一个新文件、把既有数据孤儿化。双后缀另立存量问题。

### 实测结论（`flutter build web` + 本地 SPA 回退服务 + Chrome）

| 项 | 结果 | 证据 |
|----|------|------|
| 启动不再白屏 | ✅ | 页面标题由 `life_launcher` 变为 `LifeOS 生活台`，三栏任务界面渲染 |
| drift 选中持久化后端 | ✅ | 控制台 `Using WasmStorageImplementation.sharedIndexedDb due to missing browser features: {...}` |
| 库真的建出来了 | ✅ | `indexedDB.databases()` 返回 `["life_productivity\|1"]` |
| 新建提醒 | ✅ | 底栏「新提醒事项」→ 草稿行输入 → 回车 → 行出现，侧栏计数 今天 1 / 计划 1 / 全部 1 / 紧急 1 |
| 刷新不丢（TC-REG-109） | ✅ | reload 后条目「web持久化验证」与上述计数仍在 |
| 深链（TC-REG-109） | ✅ | `/list/smart.today` 直达「今天」视图 |

### 脚手架坑（复跑必读）

- 深链要服务端 SPA 回退。`python3 -m http.server` 对 `/list/smart.today` 返回 404，
  是脚手架缺回退，不是产品缺陷。
- 回退判据不能写成「路径里没有 `.` 才回退」——路由名 `smart.today` 自带点，会被误判成静态文件。
  要按扩展名白名单判。
- Flutter Web 语义树默认不构建，`take_snapshot` 只拿到空壳；先点 `FLT-SEMANTICS-PLACEHOLDER`
  （无障碍占位符）才有可交互 uid。每次导航后 uid 重编。
- IndexedDB 按 origin 隔离，**换端口等于换库**。8931 建的数据在 8933 上必然看不到，别当成丢数据。

### 仍未做（另立）

- Web 开库失败仍是静默白屏，没有用户可见的错误提示 → 需要启动失败兜底屏。
- Web 窄窗（<600）栈导航形态、TC-REG-101 完整链路（详情编辑/完成/搜索/删除回收窗）未走查。
- 多标签页并发写同一 IndexedDB（当前用 dedicated worker + sharedIndexedDb，未压测）。

---

## 实机复验记录（2026-10-29，#372 余项逐面量测）

> 基线：`zh-cloud-lifeos-flutter` `origin/develop@2108831`（含 #369 合并）。
> worktree `~/code/zh/worktrees/lifeos-parity-372-flutter`，分支 `feat/372-m5-regression`。
> 本轮**不改业务代码**（#372 正文即「不在本卡里改业务代码」），只量每条面的可测性并落证据；
> 发现的缺陷按「一问题一卡」另立。

### 面① 多端回归报告（TC-REG-101 Android / iPad / Windows）—— ADR：阻塞

设备不是缺口，**取不到 sqlite3 的原生资产**才是缺口：

| 档 | 结果 | 证据 |
|----|------|------|
| Android 模拟器 | AVD 起得来，构建过不去 | `emulator -avd zhcloud36` 18.0 s 完成开机，`adb devices` → `emulator-5554  device`；`flutter build apk --debug`（JAVA_HOME=ms-21.0.12.1）131.3 s 失败：`Target build_hooks failed: Error: Building native assets failed` → `Execution failed for task ':app:compileFlutterBuildDebug'` |
| iPad 模拟器 | 设备齐，构建过不去 | `xcrun simctl list runtimes` → `iOS 27.0`；iPad Pro 13/11、iPad Air、iPad mini 均在；`flutter build ios --simulator --debug` 失败：`Building assets for package:sqlite3 failed` + `build.dart returned with exit code: 255`，日志点名下载 `https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/libsqlite3.arm64.ios_sim.dylib` |
| Windows 桌面 | 结构性不可测 | 本机 macOS（`darwin/arm64`），无 Windows 主机、无跨架构 Windows 工具链 |

两档失败是**同一根因**：`sqlite3` 的 build hook 要从 GitHub Releases 拉预编译二进制，本机此刻拿不到——
`curl -I -L --max-time 45` 该直链 45 s 超时、`http=000`（现测于 2026-10-29 04:5x UTC）。
因此这**不是**产品缺陷，也不是「设备不可用」，而是构建依赖外部资产可达性。
复现命令（可直接粘贴）：

```bash
source ~/development/env-flutter.sh
# 资产可达性（这一步红着，后面两档构建必然红）
curl -sS -o /dev/null -w 'http=%{http_code}\n' -L --max-time 45 \
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/libsqlite3.arm64.ios_sim.dylib
# Android（模拟器已 boot 时）
cd apps/life_launcher && JAVA_HOME=~/Library/Java/JavaVirtualMachines/ms-21.0.12.1/Contents/Home flutter build apk --debug
# iOS 模拟器
cd apps/life_launcher && flutter build ios --simulator --debug
```

> 待办归位：把这两枚 dylib/.so 资产镜像进仓内或内网源，否则任何「Android/iOS 出包」类卡都会在
> native asset 这一步随机红——这条不属于对等缺口，属构建可重复性，见本轮另立的构建卡。

### 面② 桌面快捷键 ⌘N / ⌘F（TC-REG-103）—— 旧口径被否证，改判

清单里写的「flutter_test 无法模拟修饰键」**不准**：

1. 三个键都有 Flutter 侧绑定，不只是原生菜单：
   `packages/feature_task/lib/src/widgets/task_shortcuts.dart:76-81`
   （`SingleActivator(keyN, meta)`→新建提醒、`SingleActivator(keyF, meta)`→聚焦搜索、
   `SingleActivator(keyN, meta, shift)`→新建列表）；macOS 另有
   `apps/life_launcher/lib/shell/life_menu_bar.dart:78` 的 `PlatformMenuBar` 同键位。
2. 实测合成序列 `sendKeyDownEvent(metaLeft)` → `sendKeyDownEvent(keyN)` → 抬起，
   `HardwareKeyboard.instance.isMetaPressed` **为 true**（这条断言通过）——
   修饰键状态确实进了 `HardwareKeyboard`。用的 API 是
   `sendKeyDownEvent(LogicalKeyboardKey key, {String? platform, String? character, PhysicalKeyboardKey? physicalKey})`，
   旧注释说的 `simulateKeyDownEvent` 不带修饰态是另一回事。
3. 但端到端仍没打通：`⌘F` 序列后 `toolbar_search` 的 `EditableText.focusNode.hasFocus` 为 **false**；
   `⌘N` 序列后 `find.byType(CupertinoTextField)` 起手就已命中 1 个——命中的是常驻的
   `CupertinoTextField-[<'toolbar_search'>]`，不是草稿行。
4. 由此暴露一处**判据缺陷**（非产品缺陷）：`packages/feature_task/test/shortcuts_ui_test.dart`
   第 3 条用 `expect(find.byType(CupertinoTextField), findsWidgets)` 当「草稿行出现」的判据，
   而工具栏搜索框本身就是 `CupertinoTextField`——**该断言恒真**，广播链路断了也不会红。
   `cmd_shift_n_new_list_test.dart` 同口径（注释自认「物理按键不稳定」）。
   另立卡处理（判据要收起到草稿行自己的 key/类型上，再补合成键端到端）。

结论：⌘N/⌘F 的**真机真人走查仍然要**（`PlatformMenuBar` 的键等价物由 AppKit 解析，不经 Flutter 按键流），
但「widget 测做不到」这句不能再用——它挡住了本可自动化的那半。

### 面③ i18n 抽查（TC-REG-104）—— ADR：阻塞，且当前口径无法执行

清单要求「系统切英文：任务首页/详情/设置弹层无硬编码中文残留」。这条**现在结构上不可能成立**：

- `apps/life_launcher/lib/main.dart:266` 写死 `locale: const Locale('zh', 'CN')`。
  同文件 `supportedLocales` 里虽有 `Locale('en','US')`，但显式 `locale:` 优先于系统语言，
  `en_US` 那档在运行时**永远不可达**——切系统语言不会改变 app 内 locale。
- 全仓无本地化装置：`git grep -c AppLocalizations origin/develop` 零命中，
  `ls-tree` 里没有任何 `.arb` / `l10n.yaml`。也就是说 app 自身文案没走 delegate，
  只有 Cupertino/Material/Widgets 三个 Global delegate。
- 硬编码规模（`origin/develop@2108831` 现读，非注释行）：
  `packages/*/lib` + `apps/*/lib` 的 UI dart 文件 **142/142** 含中文字面量，合计 **652** 行；
  按包：feature_calendar 238、feature_task 159、feature_note 104、life_launcher 56、
  feature_productivity_drift 29、feature_calendar_cloud 27、feature_productivity_kernel 22、
  feature_task_cloud 14、feature_note_cloud 2、app_core 1。

判重：flutter 仓 open+closed Issue 里，正文/标题提到 i18n/本地化/英文/locale 的只有
#372 自己（#368/#375 讲的是 macOS 菜单栏文案，已关）→ 另立新卡，本卡不顺手改。

复算命令（本机 `grep` 是 BSD 版，不支持 `-P`，所以中文计数用 python 现读 `origin/develop`）：

```bash
WT=~/code/zh/worktrees/lifeos-parity-372-flutter   # 换成实际工作树
git -C "$WT" grep -c AppLocalizations origin/develop -- packages apps   # 期望：rc=1，零命中
git -C "$WT" ls-tree -r --name-only origin/develop | grep -c '\.arb$'   # 期望：0
python3 - "$WT" <<'PY'
import re, subprocess, sys
W, REF = sys.argv[1], "origin/develop"
def git(*a):
    r = subprocess.run(["/usr/bin/git", "-C", W, *a], capture_output=True, text=True)
    assert r.returncode == 0 or a[0] == "grep", (a, r.returncode)
    return r.stdout
files = git("ls-tree", "-r", "--name-only", REF, "--", "packages", "apps").splitlines()
ui = [f for f in files if f.endswith(".dart") and "/lib/" in f and "/test/" not in f]
cjk = re.compile("[\u4e00-\u9fff]")
hits = 0
for f in ui:
    for line in git("show", f"{REF}:{f}").splitlines():
        s = line.strip()
        if not s or s.startswith(("//", "///", "*")):
            continue
        if cjk.search(s):
            hits += 1
print("UI dart 文件数 =", len(ui), "非注释中文字面量行 =", hits)   # 本轮得 142 / 652
PY
```

### 面③ 性能基线（TC-REG-105）—— 已自动化，实测数值

`flutter test packages/feature_task/test/tc_reg_perf_test.dart`（1000 条 + 搜索）：**rc=0**，
`00:01 +1: All tests passed!`（用例内测试时钟 1 s 内跑完「渲染 + pumpAndSettle + 搜索输入」，
阈值 10 s / 搜索 2 s 均有余量）；整进程 `real 11.59s`（含 pub get 与编译，不是渲染耗时）。
真机 jank 走查仍属面①（同被 native asset 卡住）。

### 本轮对 #372 的裁定

| 面 | 状态 | 去处 |
|----|------|------|
| ① 多端回归报告（Android/iPad/Windows） | **ADR：阻塞** — Android/iPad 卡在 sqlite3 native asset 取不到（GitHub 直链 45 s 超时），Windows 无主机 | 构建资产镜像另立卡；设备齐备后可复跑 |
| ② 快捷键 ⌘N/⌘F 手动走查 | 部分推进 — 合成修饰键能进 `HardwareKeyboard`，但端到端未通；另暴露恒真判据 | 另立测试判据卡 |
| ② 断网/弱网/杀进程恢复 | 未做（本轮预算） | 留 #372 |
| ③ i18n 抽查（中/英） | **ADR：阻塞** — `locale:` 硬钉 + 无 AppLocalizations，「切英文」不可执行 | 另立 i18n 卡 |
| ③ 性能基线（千级列表） | **有数值** — 1000 条 rc=0、测试时钟 ~1 s，阈值 10 s | 本文件 |
