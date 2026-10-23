# CI 计划（C6 预留 · Phase 0 文档化）

> 状态：**文档化预留**。本仓当前无流水线密钥、无真实 Jenkins Job；
> 按下列计划接入 Gitea Actions（优先）或 Jenkins。密钥永不入库。

## 1. 计划流水线（Gitea Actions）

`.gitea/workflows/ci.yaml`（待接入时创建）：

| 步骤 | 命令 | 门禁 |
|------|------|------|
| 依赖 | `dart pub get`（workspace 根） | 失败即终止 |
| 静态分析 | `dart run melos analyze` | `--fatal-infos` 0 issue |
| 单测 | `dart run melos exec --dir-exists=test -- flutter test` | 全绿 |
| 代码生成一致性（可选） | `dart run melos gen` 后 `git diff --exit-code` | 无漂移 |

触发：PR → develop；路径过滤 `apps/**`、`packages/**`、`pubspec.yaml`。

## 2. 环境要求

- Flutter 3.44.x（stable）；Dart 3.12.2
- `hooks: 2.0.0` override 与 `sqlite3 <3.6` 钉版随 SDK 升级移除（见 README 钉版说明）
- runner 需可跑 macOS 桌面测试（Drift NativeDatabase）；Linux runner 需 `sqlite3` 系统库

## 3. 密钥纪律

- 流水线无需业务密钥（开源仓无真实 sync，F1）
- 如接 Gitea 包发布/缓存：token 只配 runner secret，不进仓库任何文件
- 示例文件一律 `.example` 后缀 + 占位符（对齐父仓 MCP 约定）

## 4. Jenkins 备选

若走父仓 Jenkins：Job 模板对齐 zh-cloud-service 的 Flutter 作业；
构建产物仅冒烟（`flutter build` 不在本阶段门禁内）。

## 5. 当前手工门禁（CI 接入前的等价物）

每次交付前在本地执行：

```bash
dart run melos analyze
dart run melos exec --dir-exists=test -- flutter test
```

两绿才允许 commit（会话内已按此执行）。
