## 变更摘要

<!-- 一句话说清「修了什么对等缺口 / 补了什么能力」，引 Issue 号 -->

## 关联

- Fixes #

## 合前门禁（必填，贴实际输出）

本仓 **CI 不提供门禁**：Gitea 实例零 runner（`GET /admin/actions/runners` → `total_count: 0`），
Actions 的 run 只会停在 queued / cancelled（见 #322）。因此下面这条命令的输出是**唯一证据**：

```bash
dart run melos run verify
```

<!-- 粘贴末几行（应含 SUCCESS）；只粘「All tests passed」不够，那不含 analyze 与 UI 尺子 -->

```
（粘贴 `dart run melos run verify` 的结尾输出）
```

## 自查

- [ ] 只改了与 Issue 相关的文件（没顺手重构无关代码）
- [ ] 涉及 UI 时：新增/更新了 widget 测试，或在本节写明**手工复验步骤**
- [ ] 界面文案无 iCloud / Siri / Apple Intelligence / Outlook 等剥离词
- [ ] 门禁未放宽（`--max-hex` 只减不增；`violations` 必须为 0）
