# note golden 基线

| 文件 | 尺寸 |
|---|---|
| `iphone_375_note.png` | 375×812 |
| `desktop_1280_note.png` | 1280×800 |

## 为什么不需要注入时钟

note 的**渲染**路径不读挂钟：`DateTime.now()` 只出现在新建/编辑动作里（生成 id、
`clientUpdatedAt` 时间戳），不影响已渲染的列表。所以这两张图天然确定——
连跑两次均 `All tests passed!`。

将来若加了「今天创建的笔记」之类按日期分组的区块，需照 `feature_task` 的做法引入
`clockProvider`，否则 goldens 会随日期漂移。

## 敏感性验证

改动夹具内容（把标题「周会纪要」改成别的）→ 两张**全红**，说明图确实在比对，
不是空壳。

## 重录

```bash
cd packages/feature_note
flutter test test/note_golden_test.dart --update-goldens --no-pub
```

## 平台边界

同 `feature_calendar/test/goldens/README.md`：macOS 基线，接 Linux CI 要按平台分。
