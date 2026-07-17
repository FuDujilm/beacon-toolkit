# Requirements

## Overview

为无线电工具箱新增工程化“单位换算”工具。页面围绕常见射频现场估算场景，提供两组联动换算：

- 电压 / 功率 / 阻抗换算
- 场强 / 通量密度 / 接收功率换算

用户可编辑任意一个输入框，其余相关单位即时联动更新。

## Scope

### In Scope

- 无线电工具页新增“单位换算”入口，分类为“计算”。
- 新增独立单位换算页面。
- 支持“电压功率换算”模式：
  - 电压：`V` / `dBV` / `mV` / `dBmV` / `μV` / `dBμV`
  - 功率：`W` / `dBW` / `mW` / `dBmW` / `μW` / `dBμW`
  - 阻抗参数：默认 `50Ω`
- 支持“场强通量密度换算”模式：
  - 场强：`V/m` / `dBmV/m` / `dBV/m` / `μV/m` / `mV/m` / `dBμV/m`
  - 通量密度：`W/m²` / `dBmW/m²` / `dBW/m²` / `μW/m²` / `mW/m²` / `dBμW/m²`
  - 功率：`W` / `dBW` / `mW` / `dBmW` / `μW` / `dBμW`
  - 频率参数：默认 `50MHz`
  - 阻抗参数：默认 `50Ω`
- 单位标签支持 `μ` 与 LaTeX 形式展示。
- 页面显示必要免责声明。

### Out of Scope

- 不接入 beacon-api、MeowzExam API 或第三方服务。
- 不新增本地持久化或 SQLite 数据结构。
- 不做复杂链路预算、卫星链路、极化损耗、天线方向图或法规判定。
- 不新增首页常用工具配置项。

## User Stories

- As a user, I want to edit any voltage or power field directly, so that I can快速完成 50 欧或自定义阻抗下的工程换算。
- As a user, I want to convert between field strength, power flux density, and received power, so that I can快速估算现场覆盖和接收量级。
- As a user, I want the page to look like a dedicated radio calculator rather than a generic form list, so that repeated use stays efficient on mobile.

## Acceptance Criteria

- [ ] 工具页“计算”分类中出现“单位换算”入口。
- [ ] 页面顶部可切换“电压功率换算”和“场强通量密度换算”两种模式。
- [ ] 任意输入框可作为源值，相关结果即时刷新。
- [ ] 正在编辑的输入框不会因联动刷新导致光标跳到末尾以外的位置。
- [ ] 页面支持自定义阻抗；场强模式支持自定义频率。
- [ ] 非法输入时显示明确提示，不崩溃、不静默失败。
- [ ] 页面在小屏和宽屏下均无明显布局溢出。
- [ ] 页面显示“仅供参考，请遵守当地法规和主管部门要求。”

## Impact

- MeowzExam API: 无。
- beacon-api: 无。
- OAuth: 无。
- Local storage / SQLite: 无。
- Platform config: 无。
