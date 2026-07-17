# Tasks

## Implementation

- [ ] 新增时区工具 spec 文档。
- [ ] 新增离线时区 / 昼夜计算模型与 helper。
- [ ] 新增时区计算页面与地图交互。
- [ ] 在无线电工具页接入“时区计算”入口。
- [ ] 补充自动化测试。

## Verification

- [ ] Run `dart format .`
- [ ] Run `flutter analyze`
- [ ] Run `flutter test`

## Notes

- 采用离线近似 UTC 偏移与昼夜计算，不做真实时区边界和夏令时精确规则。
