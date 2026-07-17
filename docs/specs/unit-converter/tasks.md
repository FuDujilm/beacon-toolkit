# Tasks

## Implementation

- [x] 新增单位换算 spec 文档。
- [x] 新增本地单位换算 service。
- [x] 新增单位换算页面。
- [x] 在无线电工具页接入“单位换算”入口。
- [x] 支持电压 / 功率 / 阻抗联动换算。
- [x] 支持场强 / 通量密度 / 功率联动换算。
- [x] 支持 TeX 单位标签与公式展示。
- [x] 修正联动输入时源输入框光标跳动问题。
- [ ] 依据最新产品方向，补充工具描述文案为新能力范围。

## Verification

- [ ] Run `dart format lib/services/unit_converter_service.dart lib/pages/radio/unit_converter_page.dart test/unit_converter_service_test.dart test/unit_converter_page_test.dart`
- [ ] Run `flutter analyze lib/services/unit_converter_service.dart lib/pages/radio/unit_converter_page.dart test/unit_converter_service_test.dart test/unit_converter_page_test.dart`
- [ ] Run `flutter test test/unit_converter_service_test.dart test/unit_converter_page_test.dart`
