# 日历 golden 基线（目视走查素材，不是门禁）

三张图由 `../calendar_regression_test.dart` 的「三档断点（R-01 golden）」组产出：

| 文件 | 尺寸 | 视图 |
|---|---|---|
| `iphone_375_day.png` | 375×812 | 日视图 |
| `ipad_834_week.png` | 834×1112 | 周视图 |
| `desktop_1280_month.png` | 1280×800 | 月视图 + 侧栏 |

## 为什么默认 `skip: true`

截图**不是**确定性的：`month_view.dart` 用 `DateTime.now()` 判定「今天」并高亮那一格，
周/日视图同理；测试里的锚点（`anchorDateProvider`）虽然被钉到 `2026-10-26`，
但「今天」那一圈高亮仍取自挂钟。因此这些图会随**执行日期**变化，
当门禁会在无关 PR 上无故变红。

## 怎么用

目视走查（#127 这类）前按当前 tip 重录，再对比 Apple 参考图：

```bash
cd packages/feature_calendar
# 临时去掉三处 `skip: true`
flutter test test/calendar_regression_test.dart --update-goldens --no-pub
git checkout -- test/calendar_regression_test.dart   # 记得还原 skip
```

## 已知待办

要让它变成真门禁，需要**注入时钟**（把 `DateTime.now()` 收进一个可 override 的 provider，
视图改为读它），然后去掉 `skip`。已挂卡跟踪，不在本目录处理。
