# Ham Calculator Hub Design

## 页面结构

### 1. 工具页分类调整

- `RadioToolsPage` 的分类数组新增 `快速计算`。
- `RadioToolsPage` 的工具列表新增：
  - `计算目录`
  - `快速计算`

### 2. 计算目录页

新增 `CalculatorHubPage`：

- 顶部为目录说明。
- 中间按九大类输出分组卡片。
- 每个分类卡片包含：
  - 中文分类名
  - 英文原名
  - 计算器数量
  - 条目列表
- 条目支持两种状态：
  - 已接入：点击进入现有页面
  - 目录项：点击进入占位页，说明当前作为目录保留

### 3. 快速计算页

新增 `QuickCalculatorsPage`：

- 使用 `TabBar` 切换三个快算模块：
  - 欧姆定律
  - 功率 dB
  - SWR / 回损
- 每个模块保持紧凑单屏可用。
- 使用局部状态实时计算，不依赖后端。

### 4. 传输线计算页

新增 `TransmissionLineCalculatorPage`：

- 使用 `TabBar` 切换四个模块：
  - 同轴损耗
  - SWR / 回损
  - 电气长度
  - λ/4 变换
- 同轴损耗内置常见线缆预设，按频率插值估算每 100 m 损耗。
- SWR / 回损模块复用统一公式。
- 电气长度模块提供 `物理→电气` 与 `电气→物理` 两种模式。
- λ/4 模块计算所需特性阻抗和物理长度。

## 数据组织

在 `calculator_hub_page.dart` 内定义轻量配置对象：

- 分类：标题、英文标题、图标、颜色、条目列表
- 条目：标题、说明、是否已实现、点击行为

这样避免为纯展示目录引入额外模型层。

## 计算逻辑

新增 `QuickRadioCalculatorService` 提供：

- 欧姆定律：由任意两个量求另外两个量
- 功率换算：W ↔ dBm ↔ dBW
- SWR / Return Loss 互算

新增 `TransmissionLineCalculatorService` 提供：

- 同轴损耗估算
- SWR / 回损 / 反射系数互算
- 物理长度与电气长度互算
- 四分之一波阻抗变换

计算逻辑保持纯函数，便于单测。

## 测试

- `quick_radio_calculator_service_test.dart`
- `calculator_hub_page_test.dart`
- `quick_calculators_page_test.dart`
- `radio_tools_page_test.dart`
- `transmission_line_calculator_service_test.dart`
- `transmission_line_calculator_page_test.dart`

## 风险与约束

- 目录页仅承载导航与信息架构，不应误导为“全部已实现”。
- 未实现条目统一走占位页，并在副文案中标明“目录保留”。
- 所有页面保留无线电免责声明。
