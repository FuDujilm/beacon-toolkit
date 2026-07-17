# Requirements

## Overview

为无线电工具箱新增“时区计算”工具。用户可以通过地图点击或手动输入经纬度选择两个地点，查看两地当前本地时间、UTC 偏移、时差和日期进位，同时在世界地图上查看近似时区分区以及白天/黑夜区域。

## Scope

### In Scope

- 无线电工具页新增“时区计算”入口，分类为“计算”。
- 新增独立时区工具页面，支持双地点时差换算。
- 支持地图点击选择地点 A / B。
- 支持手动输入经纬度。
- 支持当前设备定位填入当前选中地点。
- 地图显示近似 UTC 时区分区。
- 地图显示白天 / 黑夜区域指示。
- 显示必要免责声明。

### Out of Scope

- 不接入 beacon-api、MeowzExam API 或第三方时区查询服务。
- 不做 IANA 时区名精确匹配。
- 不做夏令时精确计算。
- 不新增首页常用工具配置项。
- 不新增本地持久化或 SQLite 数据结构。

## User Stories

- As a user, I want to compare the current local time of two locations, so that I can quickly estimate cross-timezone communication windows.
- As a user, I want to click a world map to select locations, so that I can avoid manually searching for coordinates.
- As a user, I want to see day and night regions on the map, so that I can judge whether a target area is currently in daylight.

## Acceptance Criteria

- [ ] 工具页“计算”分类中出现“时区计算”入口。
- [ ] 用户可在页面中维护地点 A 与地点 B，并看到两地当前本地时间与 UTC 偏移。
- [ ] 用户可看到两地时差和日期进位提示。
- [ ] 用户可通过地图点击设置地点 A 或地点 B。
- [ ] 地图可显示近似 UTC 时区带。
- [ ] 地图可显示白天 / 黑夜区域指示。
- [ ] 页面在小屏和宽屏下均无明显布局溢出。
- [ ] 页面显示“仅供参考，请遵守当地法规和主管部门要求。”

## Impact

- MeowzExam API: 无。
- beacon-api: 无。
- OAuth: 无。
- Local storage / SQLite: 无。
- Platform config: 无。

## Open Questions

- 默认采用近似 UTC 偏移与近似昼夜算法，不处理夏令时精确规则。
